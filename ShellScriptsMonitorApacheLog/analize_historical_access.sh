#!/bin/bash

# ============================================================
# analyze_access_enterprise.sh
# Analisi avanzata access log Apache / IBM HTTP Server
# con parsing robusto per mod_was / WebSphere Plugin
# ============================================================

show_help() {
    echo ""
    echo "USO:"
    echo "  $0 -f <access.log> -c <context-root>"
    echo ""
    exit 1
}

# ============================================================
# PARSING PARAMETRI
# ============================================================

LOGFILE=""
CONTEXT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f) LOGFILE="$2"; shift 2 ;;
        -c) CONTEXT="$2"; shift 2 ;;
        -h|--help) show_help ;;
        *) echo "Parametro sconosciuto: $1"; show_help ;;
    esac
done

if [[ -z "$LOGFILE" || -z "$CONTEXT" ]]; then
    echo "ERRORE: parametri mancanti."
    show_help
fi

if [[ ! -f "$LOGFILE" ]]; then
    echo "ERRORE: file non trovato: $LOGFILE"
    exit 1
fi

# ============================================================
# CONTROLLO FILE IN SCRITTURA
# ============================================================

check_file_in_use() {
    local file="$1"

    echo "Verifica stato file: $file"

    if command -v lsof >/dev/null 2>&1; then
        if lsof "$file" 2>/dev/null | grep -q "$file"; then
            echo "ATTENZIONE: file in scrittura."
            exit 1
        fi
    fi

    local size1 size2
    size1=$(stat -c%s "$file")
    sleep 1
    size2=$(stat -c%s "$file")

    if [[ "$size1" != "$size2" ]]; then
        echo "ATTENZIONE: file in crescita."
        exit 1
    fi

    echo "OK: file stabile."
}

check_file_in_use "$LOGFILE"

# ============================================================
# HEADER
# ============================================================

echo ""
echo "============================================================"
echo " ANALISI ACCESS LOG (VERSIONE ENTERPRISE)"
echo " File:        $LOGFILE"
echo " Context-root: $CONTEXT"
echo "============================================================"
echo ""

# ============================================================
# AWK ENTERPRISE
# ============================================================

awk -v ctx="$CONTEXT" '

# ------------------------------------------------------------
# Funzione: parse_date
# ------------------------------------------------------------
function parse_date(ts,   a,b) {
    split(ts, a, ":")
    split(a[1], b, "/")
    return b[3] "-" b[2] "-" b[1] " " a[2]
}

# ------------------------------------------------------------
# Funzione: extract_status
# Estrae il return code con regex infallibile
# ------------------------------------------------------------
function extract_status(line,   m) {
    # "GET ... HTTP/1.1" 200 ...
    if (match(line, /"[^"]+" ([0-9]{3}) /, m))
        return m[1]
    return ""
}

# ------------------------------------------------------------
# Funzione: extract_time
# Estrae il tempo di risposta (microsecondi)
# ------------------------------------------------------------
function extract_time(line,   m) {
    # "GET ... HTTP/1.1" 200 12445 1944795
    if (match(line, /"[^"]+" [0-9]{3} [0-9]+ ([0-9]+)/, m))
        return m[1]
    return ""
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
BEGIN {
    print "1) RETURN CODE PER CONTEXT-ROOT"
}

{
    # Timestamp
    match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, ts)
    timestamp = ts[1]

    # Metodo + URL
    match($0, /"([A-Z]+) ([^ ]+) HTTP/, req)
    method = req[1]
    url = req[2]

    # Filtra per context-root
    if (index(url, ctx) != 1)
        next

    # IP
    ip = $1

    # Return code (robusto)
    code = extract_status($0)

    # Tempo (robusto)
    t_micro = extract_time($0)

    # Statistiche
    retcode[code]++
    hour_key = parse_date(timestamp)
    hits[hour_key]++

    if (t_micro ~ /^[0-9]+$/) {
        t_ms = t_micro / 1000.0
        sum_time[hour_key] += t_ms
        count_time[hour_key]++
        times[++n] = t_ms
    }

    ip_count[ip]++
}

END {
    # RETURN CODE
    for (c in retcode)
        printf "  %s: %d\n", c, retcode[c]

    print ""
    print "2) HITS PER ORA"
    for (h in hits)
        printf "  %s: %d\n", h, hits[h]

    print ""
    print "3) TEMPO MEDIO DI RISPOSTA (ms) PER ORA"
    for (h in sum_time)
        printf "  %s: %.2f ms\n", h, sum_time[h] / count_time[h]

    print ""
    print "4) TOP IP (prime 10 voci)"
    PROCINFO["sorted_in"] = "@val_num_desc"
    count = 0
    for (ip in ip_count) {
        printf "  %s: %d\n", ip, ip_count[ip]
        if (++count == 10) break
    }

    print ""
    print "5) PERCENTILI TEMPI DI RISPOSTA (ms)"

    if (n > 0) {
        asort(times)
        p50 = times[int(n*0.50)]
        p90 = times[int(n*0.90)]
        p95 = times[int(n*0.95)]
        p99 = times[int(n*0.99)]

        printf "  p50: %.2f ms\n", p50
        printf "  p90: %.2f ms\n", p90
        printf "  p95: %.2f ms\n", p95
        printf "  p99: %.2f ms\n", p99
    } else {
        print "  Nessun tempo disponibile"
    }
}
' "$LOGFILE"

echo ""
echo "==> COMPLETATO."
echo ""

