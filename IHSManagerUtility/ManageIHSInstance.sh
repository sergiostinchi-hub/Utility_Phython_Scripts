#!/bin/bash
set -e

############################################
# SCRIPT INFO
############################################
SCRIPT_NAME="ManageIHSInstance.sh"
SCRIPT_VERSION="1.6.0"
BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S')"

# ANSI COLORS
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

# Delay before status check (seconds)
STATUS_DELAY=5

############################################
# HELP FUNCTION
############################################
print_help() {
  echo "============================================================"
  echo " $SCRIPT_NAME - Version $SCRIPT_VERSION"
  echo " Build date: $BUILD_DATE"
  echo "============================================================"
  echo
  echo "Usage:"
  echo "  $SCRIPT_NAME [OPTION]"
  echo
  echo "Options:"
  echo "  --start        Start all apachectl scripts linked to active .conf files"
  echo "  --stop         Stop all apachectl scripts linked to active .conf files"
  echo "  --clean        Move unused or invalid configuration files to conf_unused/"
  echo "  --status       Show the running status of all apachectl instances"
  echo "  -h, --help     Show this help message"
  echo
  exit 0
}

############################################
# PARSE ARGUMENTS
############################################
DO_CLEAN=0
DO_START=0
DO_STOP=0
DO_STATUS=0

case "$1" in
  --clean) DO_CLEAN=1 ;;
  --start) DO_START=1 ;;
  --stop)  DO_STOP=1 ;;
  --status) DO_STATUS=1 ;;
  -h|--help) print_help ;;
esac

############################################
# PRINT HEADER + USAGE SUMMARY
############################################
echo "============================================================"
echo " $SCRIPT_NAME - Version $SCRIPT_VERSION"
echo " Build date: $BUILD_DATE"
echo "============================================================"
echo
echo "Usage summary:"
echo "  --start   Start all apachectl scripts linked to active .conf files"
echo "  --stop    Stop all apachectl scripts linked to active .conf files"
echo "  --clean   Move unused or invalid configuration files to conf_unused/"
echo "  --status  Show the running status of all apachectl instances"
echo "  --help    Show detailed help and documentation"
echo

############################################
# HOME IBM HTTP SERVER
############################################
HTTP_SERVER_HOME="/prod/IBM/HTTPServer"
CONF_DIR="$HTTP_SERVER_HOME/conf"
BIN_DIR="$HTTP_SERVER_HOME/bin"
CONF_UNUSED_DIR="$CONF_DIR/conf_unused"

############################################
# TEMP DIRECTORY
############################################
HOME_TMP="/prod/IBM/backup/tmp"

echo "[INFO] Checking temporary directory: $HOME_TMP"
if [ ! -d "$HOME_TMP" ]; then
  echo "[INFO] Temporary directory not found, creating it..."
  if ! mkdir -p "$HOME_TMP" 2>/dev/null; then
    HOME_TMP="$(pwd)/tmp"
    mkdir -p "$HOME_TMP"
    echo "[WARN] Unable to create default HOME_TMP"
    echo "[WARN] Using fallback directory: $HOME_TMP"
  else
    echo "[INFO] Temporary directory created: $HOME_TMP"
  fi
else
  echo "[INFO] Temporary directory already exists"
fi

############################################
# DEFAULT IHS FILES TO IGNORE
############################################
DEFAULT_IGNORE_FILES=(
  admin.conf.default
  httpd.conf.default
  java.security.append
  magic
  magic.default
  mime.types
  mime.types.default
  postinst.properties
  ldap.prop.sample
  httpd.conf
  workbench.xmi
)

# Sensitive file: MUST NEVER BE MOVED
SENSITIVE_NO_CLEAN_FILES=(
  admin.passwd
)

############################################
# TEMP FILES
############################################
CONF_TO_CHECK="$HOME_TMP/conf_to_check.$$.txt"
INVALID_CONF="$HOME_TMP/invalid_conf.$$.txt"
CONF_NOT_USED="$HOME_TMP/conf_not_used.$$.txt"
CONF_CTL_MAP="$HOME_TMP/conf_ctl_map.$$.txt"
FILES_MOVED="$HOME_TMP/files_moved.$$.txt"

trap 'rm -f "$CONF_TO_CHECK" "$INVALID_CONF" "$CONF_NOT_USED" "$CONF_CTL_MAP" "$FILES_MOVED"' EXIT

############################################
# UTILITY FUNCTIONS
############################################
is_in_list() {
  local item="$1"; shift
  for i in "$@"; do
    [ "$i" = "$item" ] && return 0
  done
  return 1
}

get_ctl_for_conf() {
  local conf="$1"
  awk -v c="$conf" '$1 == c && $2 == "->" {print $3}' "$CONF_CTL_MAP" | sort -u
}

FAILED_CTLS=()

run_ctl_action() {
  local ctl="$1"
  local action="$2"

  if [ ! -x "$BIN_DIR/$ctl" ]; then
    echo "[WARN] ctl not executable: $ctl"
    return
  fi

  echo "[INFO] Executing: $ctl $action"

  if "$BIN_DIR/$ctl" "$action"; then
    echo "[INFO] $ctl $action completed successfully"
  else
    echo "[ERROR] $ctl $action FAILED"
    FAILED_CTLS+=("$ctl")
  fi
}

check_ctl_status() {
  local ctl="$1"

  # If ctl failed during start
  for f in "${FAILED_CTLS[@]}"; do
    if [ "$f" = "$ctl" ]; then
      echo -e "$ctl  ${RED}FAILED TO START${RESET}"
      return
    fi
  done

  # Find the conf associated with this ctl
  local conf=$(awk -v c="$ctl" '$3 == c {print $1}' "$CONF_CTL_MAP" | head -1)

  if [ -z "$conf" ]; then
    echo -e "$ctl  ${RED}NO CONF FOUND${RESET}"
    return
  fi

  # Check if httpd is running with this conf
  if ps -ef | grep -v grep | grep httpd | grep -q "$conf"; then
    echo -e "$ctl  ${GREEN}RUNNING${RESET}"
  else
    echo -e "$ctl  ${RED}NOT RUNNING${RESET}"
  fi
}

############################################
# STEP 1 - SCAN CONF DIRECTORY
############################################
echo "[INFO] STEP 1: Scanning configuration directory: $CONF_DIR"

> "$CONF_TO_CHECK"
> "$INVALID_CONF"

for FILE in "$CONF_DIR"/*; do
  [ -f "$FILE" ] || continue
  BASENAME="$(basename "$FILE")"

  if is_in_list "$BASENAME" "${DEFAULT_IGNORE_FILES[@]}" "${SENSITIVE_NO_CLEAN_FILES[@]}"; then
    continue
  fi

  if [[ "$BASENAME" == *.conf ]]; then
    echo "$BASENAME" >> "$CONF_TO_CHECK"
  else
    echo "$BASENAME" >> "$INVALID_CONF"
  fi
done

echo "[INFO] STEP 1 completed: $(wc -l < "$CONF_TO_CHECK") .conf files to verify"

############################################
# STEP 2 - SCAN CTL FILES
############################################
echo "[INFO] STEP 2: Searching .conf usage inside ctl files"

> "$CONF_NOT_USED"
> "$CONF_CTL_MAP"

for CONF in $(sort -u "$CONF_TO_CHECK"); do
  FOUND=0

  for CTL in "$BIN_DIR"/*; do
    [ -f "$CTL" ] || continue
    CTL_NAME="$(basename "$CTL")"
    [[ "$CTL_NAME" =~ [cC][tT][lL] ]] || continue

    while IFS= read -r LINE; do
      FOUND=1
      CLEAN_LINE="$(echo "$LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      {
        printf "%-30s -> %s\n" "$CONF" "$CTL_NAME"
        printf "    >> [%s] %s\n" "$CTL_NAME" "$CLEAN_LINE"
      } >> "$CONF_CTL_MAP"
    done < <(
      grep -Ei "^[[:space:]]*[^#;]" "$CTL" \
      | grep -Evi "^[[:space:]]*echo[[:space:]]" \
      | grep -Fi "$CONF" || true
    )
  done

  if [ "$FOUND" -eq 0 ]; then
    echo "$CONF" >> "$CONF_NOT_USED"
  fi
done

echo "[INFO] STEP 2 completed"

############################################
# STEP 2B - START/STOP
############################################
if [ "$DO_START" -eq 1 ] || [ "$DO_STOP" -eq 1 ]; then
  ACTION="start"
  [ "$DO_STOP" -eq 1 ] && ACTION="stop"

  echo "[INFO] STEP 2B: Executing $ACTION on all ctl linked to active conf"

  for CONF in $(sort -u "$CONF_TO_CHECK"); do
    echo "[INFO] Processing conf: $CONF"

    CTLS=$(get_ctl_for_conf "$CONF")

    if [ -z "$CTLS" ]; then
      echo "[INFO] No ctl found for $CONF"
      continue
    fi

    for CTL in $CTLS; do
      run_ctl_action "$CTL" "$ACTION"
    done
  done

  ############################################
  # STEP 2C - STATUS CHECK WITH DELAY
  ############################################
  echo
  echo "[INFO] Waiting $STATUS_DELAY seconds before status check..."
  sleep "$STATUS_DELAY"
  echo

  echo "============================================================"
  echo " STATUS CHECK OF ALL CTL SCRIPTS"
  echo "============================================================"

  ALL_CTLS=$(awk '$2 == "->" {print $3}' "$CONF_CTL_MAP" \
    | sort -u \
    | while read -r C; do
        [ -x "$BIN_DIR/$C" ] && echo "$C"
      done)

  if [ -z "$ALL_CTLS" ]; then
    echo "[INFO] No ctl scripts found for status check"
  else
    for CTL in $ALL_CTLS; do
      check_ctl_status "$CTL"
    done
  fi

  echo
  echo "[INFO] Status check completed"
  exit 0
fi

############################################
# STEP 2D - STATUS ONLY
############################################
if [ "$DO_STATUS" -eq 1 ]; then
  echo
  echo "============================================================"
  echo " STATUS CHECK OF ALL CTL SCRIPTS"
  echo "============================================================"

  ALL_CTLS=$(awk '$2 == "->" {print $3}' "$CONF_CTL_MAP" \
    | sort -u \
    | while read -r C; do
        [ -x "$BIN_DIR/$C" ] && echo "$C"
      done)

  if [ -z "$ALL_CTLS" ]; then
    echo "[INFO] No ctl scripts found for status check"
  else
    for CTL in $ALL_CTLS; do
      check_ctl_status "$CTL"
    done
  fi

  echo
  echo "[INFO] Status check completed"
  exit 0
fi

############################################
# STEP 3 - CLEAN UNUSED FILES
############################################
> "$FILES_MOVED"

if [ "$DO_CLEAN" -eq 1 ]; then
  echo "[INFO] STEP 3: Cleaning unused configuration files"

  if [ ! -d "$CONF_UNUSED_DIR" ]; then
    echo "[INFO] Creating directory: $CONF_UNUSED_DIR"
    mkdir -p "$CONF_UNUSED_DIR"
  fi

  if [ -d "$CONF_UNUSED_DIR" ]; then

    # Unused conf files
    while read -r FILE; do
      [ -f "$CONF_DIR/$FILE" ] || continue

      if is_in_list "$FILE" "${DEFAULT_IGNORE_FILES[@]}" "${SENSITIVE_NO_CLEAN_FILES[@]}"; then
        echo "[INFO] Skipping default/sensitive file: $FILE"
        continue
      fi

      mv "$CONF_DIR/$FILE" "$CONF_UNUSED_DIR/"
      echo "$FILE" >> "$FILES_MOVED"
      echo "[INFO] Moved unused conf: $FILE"
    done < "$CONF_NOT_USED"

    # Invalid files
    while read -r FILE; do
      [ -f "$CONF_DIR/$FILE" ] || continue

      if is_in_list "$FILE" "${DEFAULT_IGNORE_FILES[@]}" "${SENSITIVE_NO_CLEAN_FILES[@]}"; then
        echo "[INFO] Skipping default/sensitive file: $FILE"
        continue
      fi

      mv "$CONF_DIR/$FILE" "$CONF_UNUSED_DIR/"
      echo "$FILE" >> "$FILES_MOVED"
      echo "[INFO] Moved invalid file: $FILE"
    done < "$INVALID_CONF"

  fi
fi

############################################
# FINAL REPORT
############################################
echo
echo "============================================================"
echo " VALID CONF FILES AND RELATED CTL"
echo "============================================================"
[ -s "$CONF_CTL_MAP" ] && cat "$CONF_CTL_MAP" || echo "[NONE]"

echo
echo "============================================================"
echo " UNUSED CONF FILES"
echo "============================================================"
[ -s "$CONF_NOT_USED" ] && cat "$CONF_NOT_USED" || echo "[NONE]"

echo
echo "============================================================"
echo " INVALID FILES (NON .conf)"
echo "============================================================"
[ -s "$INVALID_CONF" ] && cat "$INVALID_CONF" || echo "[NONE]"

if [ "$DO_CLEAN" -eq 1 ]; then
  echo
  echo "============================================================"
  echo " FILES MOVED TO $CONF_UNUSED_DIR"
  echo "============================================================"
  [ -s "$FILES_MOVED" ] && sort -u "$FILES_MOVED" || echo "[NONE]"
fi

echo
echo "[INFO] Script completed successfully"

