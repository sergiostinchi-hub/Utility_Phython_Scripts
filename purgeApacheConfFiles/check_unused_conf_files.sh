#!/bin/bash
set -e

############################################
# PATH
############################################
CONF_DIR="/prod/IBM/HTTPServer/conf"
BIN_DIR="/prod/IBM/HTTPServer/bin"

############################################
# FILE DI DEFAULT DA IGNORARE
############################################
DEFAULT_IGNORE_FILES=(
  admin.conf.default
  admin.passwd
  httpd.conf.default
  java.security.append
  magic
  magic.default
  mime.types
  mime.types.default
  postinst.properties
)

############################################
# FILE TEMP
############################################
CONF_TO_CHECK="/tmp/conf_to_check.$$.txt"
INVALID_CONF="/tmp/invalid_conf.$$.txt"
CONF_VALID="/tmp/conf_valid.$$.txt"
CONF_NOT_USED="/tmp/conf_not_used.$$.txt"
CONF_CTL_MAP="/tmp/conf_ctl_map.$$.txt"

trap 'rm -f "$CONF_TO_CHECK" "$INVALID_CONF" "$CONF_VALID" "$CONF_NOT_USED" "$CONF_CTL_MAP"' EXIT

############################################
# UTILITY
############################################
is_ignored_default() {
  local f="$1"
  for d in "${DEFAULT_IGNORE_FILES[@]}"; do
    [[ "$f" == "$d" ]] && return 0
  done
  return 1
}

############################################
# STEP 1 - CLASSIFICAZIONE FILE CONF DIR
############################################
> "$CONF_TO_CHECK"
> "$INVALID_CONF"

for FILE in "$CONF_DIR"/*; do
  [ -f "$FILE" ] || continue
  BASENAME=$(basename "$FILE")

  if is_ignored_default "$BASENAME"; then
    continue
  fi

  if [[ "$BASENAME" == *.conf ]]; then
    echo "$BASENAME" >> "$CONF_TO_CHECK"
  else
    echo "$BASENAME" >> "$INVALID_CONF"
  fi
done

############################################
# STEP 2 - CERCA CONF NEI FILE *CTL*
############################################
> "$CONF_VALID"
> "$CONF_NOT_USED"
> "$CONF_CTL_MAP"

for CONF in $(sort -u "$CONF_TO_CHECK"); do
  FOUND=0
  CTL_LIST=()

  for CTL in "$BIN_DIR"/*; do
    [ -f "$CTL" ] || continue
    CTL_NAME=$(basename "$CTL")
    [[ "$CTL_NAME" =~ [cC][tT][lL] ]] || continue

    # Match solo su righe NON commentate
    if grep -Eqi "^[[:space:]]*[^#;].*${CONF}" "$CTL"; then
      FOUND=1
      CTL_LIST+=("$CTL_NAME")
    fi
  done

  if [ "$FOUND" -eq 1 ]; then
    echo "$CONF" >> "$CONF_VALID"
    printf "%-30s -> %s\n" "$CONF" "$(printf "%s, " "${CTL_LIST[@]}" | sed 's/, $//')" >> "$CONF_CTL_MAP"
  else
    echo "$CONF" >> "$CONF_NOT_USED"
  fi
done

############################################
# OUTPUT
############################################
echo
echo "=============================================="
echo " CONF VALIDI E RELATIVI CTL"
echo "=============================================="
if [ -s "$CONF_CTL_MAP" ]; then
  sort -u "$CONF_CTL_MAP"
else
  echo "[NESSUNO]"
fi

echo
echo "=============================================="
echo " CONF PRESENTI MA **NON UTILIZZATI**"
echo "=============================================="
if [ -s "$CONF_NOT_USED" ]; then
  sort -u "$CONF_NOT_USED"
else
  echo "[NESSUNO]"
fi

echo
echo "=============================================="
echo " FILE NON .conf (INVALIDI A PRIORI)"
echo "=============================================="
if [ -s "$INVALID_CONF" ]; then
  sort -u "$INVALID_CONF"
else
  echo "[NESSUNO]"
fi

echo
echo "[INFO] Verifica completata"
