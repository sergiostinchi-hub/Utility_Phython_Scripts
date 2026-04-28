#!/bin/bash

###############################################################################
# RESPONSE TIME MONITOR SCRIPT — VERSIONE DEFINITIVA (MODULARE)
# Modalità:
#   --history        → analisi one-shot con range temporale obbligatorio
#   --incremental    → monitoraggio realtime (default)
#   --summary-only   → mostra solo il riepilogo dei dati raccolti
#   --summary-reset  → cancella i dati raccolti (globale o selettiva)
###############################################################################

TEMP_DIR="$HOME/.rtm_temp"
mkdir -p "$TEMP_DIR"

CONFIG_FILE="$TEMP_DIR/rtm_config_response_time"

usage() {
    echo
    echo "USAGE:"
    echo "  $0 -f <log_file> -u <url> [options]"
    echo
    echo "REQUIRED:"
    echo "  -f <log_file>          Percorso del file di log da analizzare"
    echo "  -u <url>               URL da monitorare (ripetibile)"
    echo
    echo "MODALITÀ DISPONIBILI (mutuamente esclusive):"
    echo "  --history              Analisi one-shot del log in un intervallo temporale"
    echo "                         Richiede: -s <start_time> e -e <end_time>"
    echo
    echo "  --incremental          Monitoraggio realtime (default)"
    echo "                         Legge solo le nuove righe del log"
    echo
    echo "  --summary-only         Mostra il riepilogo dei dati raccolti"
    echo "                         Non legge il log"
    echo
    echo "  --summary-reset        Cancella i dati raccolti nei file temporanei"
    echo "                         Senza URL → cancella TUTTI i dati"
    echo "                         Con URL   → cancella solo quelli indicati"
    echo
    echo "OPZIONI TEMPORALI:"
    echo "  -s <hh:mm:ss>          Orario di inizio (solo in --history)"
    echo "  -e <hh:mm:ss>          Orario di fine   (solo in --history)"
    echo
    echo "OPZIONI DI ESECUZIONE:"
    echo "  -i <seconds>           Intervallo tra i cicli (default: 30)"
    echo "  -l <cycles>            Numero di cicli (default: 100)"
    echo
    echo "OPZIONI DI DEBUG:"
    echo "  --debug                Mostra informazioni dettagliate sul parsing AWK"
    echo
    exit 1
}

urls=()
interval=30
cycles=100
summary_only=0
summary_reset=0
debug=0
history_mode=0
incremental_mode=0
start_time=""
end_time=""

# Pre-getopts
for arg in "$@"; do
    case "$arg" in
        --summary-only) summary_only=1; set -- "${@/--summary-only/}" ;;
        --summary-reset) summary_reset=1; set -- "${@/--summary-reset/}" ;;
        --debug) debug=1; set -- "${@/--debug/}" ;;
        --history) history_mode=1; set -- "${@/--history/}" ;;
        --incremental) incremental_mode=1; set -- "${@/--incremental/}" ;;
    esac
done

while getopts "f:s:e:u:i:l:h" opt; do
    case "$opt" in
        f) logfile="$OPTARG" ;;
        s) start_time="$OPTARG" ;;
        e) end_time="$OPTARG" ;;
        u) urls+=("$OPTARG") ;;
        i) interval="$OPTARG" ;;
        l) cycles="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

shift $((OPTIND-1))

# Validazioni base
if (( summary_reset == 0 && summary_only == 0 )); then
    [[ -z "$logfile" ]] && usage
    [[ ! -f "$logfile" ]] && { echo "ERROR: Log file not found"; exit 1; }
fi

# Mutua esclusione
if (( history_mode == 1 && incremental_mode == 1 )); then
    echo "ERROR: --history e --incremental non possono coesistere."
    exit 1
fi

# Default = incremental
if (( history_mode == 0 && incremental_mode == 0 && summary_only == 0 && summary_reset == 0 )); then
    incremental_mode=1
fi

# Validazione range solo in history
if (( history_mode == 1 )); then
    [[ -z "$start_time" || -z "$end_time" ]] && { echo "ERROR: -s e -e obbligatori in --history"; exit 1; }
fi

# Normalizzazione URL
for i in "${!urls[@]}"; do
    [[ "${urls[$i]}" != /* ]] && urls[$i]="/${urls[$i]}"
done

regex_ts="([0-9]{2}/[A-Za-z]{3}/[0-9]{4}):([0-9]{2}:[0-9]{2}:[0-9]{2}) [+-][0-9]{4}"

###############################################################################
# SUMMARY RESET MODE
###############################################################################
if (( summary_reset == 1 )); then
    echo "=============================================================="
    echo "              SUMMARY RESET MODE"
    echo "=============================================================="
    echo

    if (( ${#urls[@]} == 0 )); then
        echo "Reset totale: rimozione di TUTTI i file temporanei."
        for file in "$TEMP_DIR"/rtm_data__*.tmp; do
            [[ -f "$file" ]] && rm -f "$file"
        done
        exit 0
    fi

    for url in "${urls[@]}"; do
        safe_url=$(echo "$url" | sed 's/[^A-Za-z0-9_-]/_/g')
        tmp="$TEMP_DIR/rtm_data__${safe_url}.tmp"
        [[ -f "$tmp" ]] && rm -f "$tmp"
    done

    exit 0
fi

###############################################################################
# SUMMARY ONLY MODE
###############################################################################
if (( summary_only == 1 )); then
    echo "=============================================================="
    echo "                SUMMARY ONLY MODE"
    echo "=============================================================="
    echo

    for url in "${urls[@]}"; do
        safe_url=$(echo "$url" | sed 's/[^A-Za-z0-9_-]/_/g')
        tmp="$TEMP_DIR/rtm_data__${safe_url}.tmp"

        if [[ ! -f "$tmp" || ! -s "$tmp" ]]; then
            echo "⚠️  Nessun dato disponibile per $url"
            echo
            continue
        fi

        echo "### URL: $url"
        echo

        awk -F',' '
            {
                split($1, t, ":")
                minute = t[1] ":" t[2]
                ms = $2
                count[minute]++
                sum[minute]+=ms
                if (!(minute in min) || ms < min[minute]) min[minute]=ms
                if (ms > max[minute]) max[minute]=ms
            }
            END {
                printf "%-10s %-10s %-10s %-10s %-10s\n",
                       "Minuto","Count","Min","Max","Avg"
                PROCINFO["sorted_in"] = "@ind_str_asc"
                for (m in count) {
                    avg = sum[m] / count[m]
                    printf "%-10s %-10d %-10d %-10d %-10.2f\n",
                           m, count[m], min[m], max[m], avg
                }
            }
        ' "$tmp"

        echo
    done

    exit 0
fi

###############################################################################
# HISTORY MODE
###############################################################################
if (( history_mode == 1 )); then
    echo "=============================================================="
    echo "           HISTORY MODE (one-shot)"
    echo "=============================================================="
    echo

    for url in "${urls[@]}"; do

        safe_url=$(echo "$url" | sed 's/[^A-Za-z0-9_-]/_/g')
        tmp="$TEMP_DIR/rtm_data__${safe_url}.tmp"
        rm -f "$tmp"

        echo "### URL: $url"
        echo

        awk -v url="$url" \
            -v start_time="$start_time" \
            -v end_time="$end_time" \
            -v regex_ts="$regex_ts" \
            -v tmpfile="$tmp" '
    BEGIN {
        split(start_time, a, ":")
        start_sec = a[1]*3600 + a[2]*60 + a[3]
        split(end_time, b, ":")
        end_sec = b[1]*3600 + b[2]*60 + b[3]
    }

    function to_sec(t) {
        split(t, a, ":")
        return a[1]*3600 + a[2]*60 + a[3]
    }

    {
        match($0, regex_ts, t)
        if (t[2] == "") next

        sec = to_sec(t[2])
        if (sec < start_sec || sec > end_sec) next
        if ($0 !~ url) next

        match($0, /([0-9]+)ms/, r)
        if (r[1] != "") { ms = r[1]; write_data(); next }

        raw_last = $NF
        if (raw_last ~ /^[0-9]+$/) { ms = raw_last; write_data(); next }
    }

    function write_data() {
        print t[2] "," ms >> tmpfile
        count[t[2]]++
        sum[t[2]]+=ms
        if (!(t[2] in min) || ms < min[t[2]]) min[t[2]]=ms
        if (ms > max[t[2]]) max[t[2]]=ms
    }

    END {
        printf "%-10s %-10s %-10s %-10s %-10s\n",
               "Second","Count","Min","Max","Avg"
        PROCINFO["sorted_in"] = "@ind_str_asc"
        for (s in count) {
            avg = sum[s] / count[s]
            printf "%-10s %-10d %-10d %-10d %-10.2f\n",
                   s, count[s], min[s], max[s], avg
        }
    }
' "$logfile"

        echo
    done

    exit 0
fi

###############################################################################
# INCREMENTAL MODE (DEFAULT)
###############################################################################
echo "=============================================================="
echo "           INCREMENTAL MODE (default)"
echo "=============================================================="
echo

offset_file="$TEMP_DIR/offset_$(basename "$logfile")"
[[ ! -f "$offset_file" ]] && echo 0 > "$offset_file"

# Soluzione C aggiornata: ultimi 5 minuti
five_minutes_ago=$(date -d "5 minutes ago" +"%d/%b/%Y:%H:%M:%S")

for ((c=1; c<=cycles; c++)); do

    echo "--------------------------------------------------------------"
    echo "Cycle $c of $cycles - Start: $(date)"
    echo "--------------------------------------------------------------"
    echo

    offset=$(cat "$offset_file")
    size=$(stat -c%s "$logfile")

    (( size < offset )) && offset=0

    if [[ "$c" -eq 1 ]]; then
        # Primo ciclo → Soluzione C: leggi solo gli ultimi 5 minuti
        new_lines=$(awk -v limit="$five_minutes_ago" '
            {
                match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, t)
                if (t[1] >= limit) print $0
            }
        ' "$logfile")
    else
        # Cicli successivi → solo nuove righe
        new_lines=$(tail -c +"$((offset+1))" "$logfile")
    fi

    echo "$size" > "$offset_file"

    for url in "${urls[@]}"; do

        safe_url=$(echo "$url" | sed 's/[^A-Za-z0-9_-]/_/g')
        tmp="$TEMP_DIR/rtm_data__${safe_url}.tmp"

        echo "### URL: $url"
        echo

        printf "%s" "$new_lines" \
        | awk -v url="$url" \
              -v regex_ts="$regex_ts" \
              -v tmpfile="$tmp" '
    BEGIN { regex = url }

    {
        match($0, regex_ts, t)
        if (t[2] == "") next
        if ($0 !~ regex) next

        match($0, /([0-9]+)ms/, r)
        if (r[1] != "") { ms = r[1]; write_data(); next }

        raw_last = $NF
        if (raw_last ~ /^[0-9]+$/) { ms = raw_last; write_data(); next }
    }

    function write_data() {
        print t[2] "," ms >> tmpfile
        count[t[2]]++
        sum[t[2]]+=ms
        if (!(t[2] in min) || ms < min[t[2]]) min[t[2]]=ms
        if (ms > max[t[2]]) max[t[2]]=ms
    }

    END {
        printf "%-10s %-10s %-10s %-10s %-10s\n",
               "Second","Count","Min","Max","Avg"
        PROCINFO["sorted_in"] = "@ind_str_asc"
        for (s in count) {
            avg = sum[s] / count[s]
            printf "%-10s %-10d %-10d %-10d %-10.2f\n",
                   s, count[s], min[s], max[s], avg
        }
    }
'

        echo
    done

    (( c < cycles )) && sleep "$interval"
done

echo
echo "=============================================================="
echo "                    FINAL SUMMARY"
echo "=============================================================="
echo

for url in "${urls[@]}"; do

    safe_url=$(echo "$url" | sed 's/[^A-Za-z0-9_-]/_/g')
    tmp="$TEMP_DIR/rtm_data__${safe_url}.tmp"

    if [[ ! -f "$tmp" || ! -s "$tmp" ]]; then
        echo "⚠️  Nessun dato disponibile per $url"
        echo
        continue
    fi

    echo "### URL: $url"
    echo

    awk -F',' '
        {
            split($1, t, ":")
            minute = t[1] ":" t[2]
            ms = $2
            count[minute]++
            sum[minute]+=ms
            if (!(minute in min) || ms < min[minute]) min[minute]=ms
            if (ms > max[minute]) max[minute]=ms
        }
        END {
            printf "%-10s %-10s %-10s %-10s %-10s\n",
                   "Minuto","Count","Min","Max","Avg"
            PROCINFO["sorted_in"] = "@ind_str_asc"
            for (m in count) {
                avg = sum[m] / count[m]
                printf "%-10s %-10d %-10d %-10d %-10.2f\n",
                       m, count[m], min[m], max[m], avg
            }
        }
    ' "$tmp"

    echo
done
