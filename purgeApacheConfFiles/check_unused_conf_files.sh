#!/bin/bash
set -e

############################################
# PARSE ARGOMENTI
############################################
DO_CLEAN=0
if [ "$1" == "--clean" ]; then
  DO_CLEAN=1
  echo "[INFO] Option --clean enabled"
fi

############################################
# HOME IBM HTTP SERVER
############################################
HTTP_SERVER_HOME="/prod/IBM/HTTPServer"
CONF_DIR="$HTTP_SERVER_HOME/conf"
BIN_DIR="$HTTP_SERVER_HOME/bin"
CONF_UNUSED_DIR="$CONF_DIR/conf_unused"

############################################
# DIRECTORY TEMPORANEA
############################################
HOME_TMP="/prod/IBM/backup/tmp"

echo "[INFO] Checking temporary directory: $HOME_TMP"
if [ ! -d "$HOME_TMP" ]; then
  echo "[INFO] Temporary directory not found, trying to create it"
  if ! mkdir -p "$HOME_TMP" 2>/dev/null; then
    HOME_TMP="$(pwd)/tmp"
    mkdir -p "$HOME_TMP"
    echo "[WARN] Impossible to create default HOME_TMP"
    echo "[WARN] Using fallback directory: $HOME_TMP"
  else
    echo "[INFO] Temporary directory created: $HOME_TMP"
  fi
else
  echo "[INFO] Temporary directory already exists"
fi

############################################
# FILE DI DEFAULT IHS
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
)

# File sensibile: NON DEVE MAI ESSERE MOSSO
SENSITIVE_NO_CLEAN_FILES=(
  admin.passwd
)

############################################
# FILE TEMP
############################################
CONF_TO_CHECK="$HOME_TMP/conf_to_check.$$.txt"
INVALID_CONF="$HOME_TMP/invalid_conf.$$.txt"
CONF_NOT_USED="$HOME_TMP/conf_not_used.$$.txt"
CONF_CTL_MAP="$HOME_TMP/conf_ctl_map.$$.txt"
FILES_MOVED="$HOME_TMP/files_moved.$$.txt"

trap 'rm -f "$CONF_TO_CHECK" "$INVALID_CONF" "$CONF_NOT_USED" "$CONF_CTL_MAP" "$FILES_MOVED"' EXIT

############################################
# UTILITY
############################################
is_in_list() {
  local item="$1"; shift
  for i in "$@"; do
    [ "$i" = "$item" ] && return 0
  done
  return 1
}

############################################
# STEP 1 - ANALISI DIRECTORY CONF
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
# STEP 2 - SCANSIONE FILE *CTL*
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
# STEP 3 - CLEAN (OPZIONALE)
############################################
> "$FILES_MOVED"

if [ "$DO_CLEAN" -eq 1 ]; then
  echo "[INFO] STEP 3: Cleaning unused configuration files"

  if [ ! -d "$CONF_UNUSED_DIR" ]; then
    echo "[INFO] Creating directory: $CONF_UNUSED_DIR"
    if ! mkdir -p "$CONF_UNUSED_DIR" 2>/dev/null; then
      echo "[WARN] Impossible to complete cleaning step"
    else
      echo "[INFO] Directory created: $CONF_UNUSED_DIR"
    fi
  fi

  if [ -d "$CONF_UNUSED_DIR" ]; then

    # conf non utilizzati
    while read -r FILE; do
      [ -f "$CONF_DIR/$FILE" ] || continue
      mv "$CONF_DIR/$FILE" "$CONF_UNUSED_DIR/"
      echo "$FILE" >> "$FILES_MOVED"
      echo "[INFO] Moved unused conf: $FILE"
    done < "$CONF_NOT_USED"

    # file non .conf
    while read -r FILE; do
      [ -f "$CONF_DIR/$FILE" ] || continue
      mv "$CONF_DIR/$FILE" "$CONF_UNUSED_DIR/"
      echo "$FILE" >> "$FILES_MOVED"
      echo "[INFO] Moved invalid file: $FILE"
    done < "$INVALID_CONF"

    # file di default (escluso admin.passwd)
    for FILE in "${DEFAULT_IGNORE_FILES[@]}"; do
      [ -f "$CONF_DIR/$FILE" ] || continue
      mv "$CONF_DIR/$FILE" "$CONF_UNUSED_DIR/"
      echo "$FILE" >> "$FILES_MOVED"
      echo "[INFO] Moved default IHS file: $FILE"
    done
  fi
fi

############################################
# REPORT FINALE
############################################
echo
echo "=============================================="
echo " CONF VALIDI E RELATIVI CTL"
echo "=============================================="
[ -s "$CONF_CTL_MAP" ] && cat "$CONF_CTL_MAP" || echo "[NONE]"

echo
echo "=============================================="
echo " CONF PRESENTI MA **NON UTILIZZATI**"
echo "=============================================="
[ -s "$CONF_NOT_USED" ] && cat "$CONF_NOT_USED" || echo "[NONE]"

echo
echo "=============================================="
echo " FILE NON .conf (INVALIDI A PRIORI)"
echo "=============================================="
[ -s "$INVALID_CONF" ] && cat "$INVALID_CONF" || echo "[NONE]"

if [ "$DO_CLEAN" -eq 1 ]; then
  echo
  echo "=============================================="
  echo " FILES MOVED TO $CONF_UNUSED_DIR"
  echo "=============================================="
  [ -s "$FILES_MOVED" ] && sort -u "$FILES_MOVED" || echo "[NONE]"
fi

echo
echo "[INFO] Script completed successfully"
