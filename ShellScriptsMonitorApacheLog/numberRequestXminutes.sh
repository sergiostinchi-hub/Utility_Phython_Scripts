#!/bin/bash

# ============================
#   OUTPUT FILE (must be first!)
# ============================

suffix=$(date +%F_%H-%M-%S)
outfile="/home/$(whoami)/scripts/logs/numReqXMin_$suffix.log"

# ============================
#   SHELL CHECK
# ============================

if [ -z "$BASH_VERSION" ]; then
    echo
    echo "=============================================================="
    echo "   ERROR: This script must be executed with BASH"
    echo "=============================================================="
    echo
    echo "You probably executed the script with 'sh script.sh'"
    echo "Instead you must run it like this:"
    echo
    echo "    bash script.sh"
    echo "or"
    echo "    chmod +x script.sh && ./script.sh"
    echo
    exit 1
fi

# ============================
#   SAVE START TIME
# ============================

SCRIPT_START=$(date +%s)
SCRIPT_START_HUMAN=$(date "+%Y-%m-%d %H:%M:%S")

# ============================
#   END REPORT FUNCTION
# ============================

print_end_report() {
    local end_ts=$(date +%s)
    local end_human=$(date "+%Y-%m-%d %H:%M:%S")
    local duration=$(( end_ts - SCRIPT_START ))

    local h=$(( duration / 3600 ))
    local m=$(( (duration % 3600) / 60 ))
    local s=$(( duration % 60 ))

    echo "==============================================================" | tee -a "$outfile"
    echo "                         END SCRIPT" | tee -a "$outfile"
    echo "==============================================================" | tee -a "$outfile"
    echo "Start:   $SCRIPT_START_HUMAN" | tee -a "$outfile"
    echo "End:     $end_human" | tee -a "$outfile"
    echo "Duration:  ${h}h ${m}m ${s}s" | tee -a "$outfile"
    echo "=============================================================="
}

trap print_end_report EXIT

# ============================
#   HELP FUNCTION
# ============================

usage() {
    echo
    echo "=============================================================="
    echo "                numReqLastXMin.sh - USAGE"
    echo "=============================================================="
    echo
    echo "PARAMETERS:"
    echo "  -f <log_file>          Log file to analyze (REQUIRED)"
    echo "  -u <url>               URL to monitor (REQUIRED, repeatable)"
    echo "  -i <minutes>           Loop interval in minutes (optional)"
    echo "                         If omitted or 0 → ONE-SHOT mode"
    echo "  -c <http_code>         Filter by HTTP status code"
    echo "  -s <HH:MM>             Start time"
    echo "  -e <HH:MM>             End time"
    echo "  -m <minutes>           Analyze last X minutes"
    echo "  -t <threshold>         Alert threshold (requests/minute)"
    echo "  -r <lines>             Number of log lines to read (default: 10000)"
    echo "  -g                     Ask whether to show ASCII graph"
    echo "  -h                     Show this help"
    echo
    exit 1
}

# ============================
#   PARAMETERS
# ============================

urls=()
loop_interval=""
accesslog=""
http_code=""
start_time=""
end_time=""
minutes_range=""
ask_graph=""
alert_threshold=""
tail_lines=10000
force_last_minute=""

while getopts "f:i:u:c:s:e:m:t:r:g:hx" opt; do
    case "$opt" in
        f) accesslog="$OPTARG" ;;
        i) loop_interval="$OPTARG" ;;
        u) urls+=("$OPTARG") ;;
        c) http_code="$OPTARG" ;;
        s) start_time="$OPTARG" ;;
        e) end_time="$OPTARG" ;;
        m) minutes_range="$OPTARG" ;;
        t) alert_threshold="$OPTARG" ;;
        r) tail_lines="$OPTARG" ;;
        g) ask_graph="yes" ;;
        h) usage ;;
        x) force_last_minute="yes" ;;
        *) usage ;;
    esac
done

# ============================
#   PARAMETER VALIDATION
# ============================

if [[ -z "$accesslog" ]]; then
    echo
    echo "=============================================================="
    echo "ERROR: Missing required parameter -f <log_file>"
    echo "=============================================================="
    echo
    usage
fi

if [[ ${#urls[@]} -eq 0 ]]; then
    echo
    echo "=============================================================="
    echo "ERROR: At least one -u <url> must be provided"
    echo "=============================================================="
    echo
    usage
fi

# ONE-SHOT MODE IF -i IS MISSING OR ZERO
if [[ -z "$loop_interval" || "$loop_interval" -eq 0 ]]; then
    loop_interval=0
    echo "WARNING: -i not provided or set to 0 → ONE-SHOT mode (single execution)"
else
    echo "Loop interval set to $loop_interval minutes"
fi

sleep_seconds=$(( loop_interval * 60 ))

# ============================
#   INITIAL PRINT
# ============================

echo "==============================================================" | tee "$outfile"
echo "                 START SCRIPT numRequestLastXMin.sh" | tee -a "$outfile"
echo "==============================================================" | tee -a "$outfile"
echo "Execution start:        $SCRIPT_START_HUMAN" | tee -a "$outfile"
echo "Log file:               $accesslog" | tee -a "$outfile"
echo "Loop interval:          $loop_interval minutes" | tee -a "$outfile"
echo "Log lines read:         $tail_lines" | tee -a "$outfile"

echo "Monitored URLs:" | tee -a "$outfile"
for u in "${urls[@]}"; do
    echo "  - $u" | tee -a "$outfile"
done

[[ -n "$http_code" ]] && echo "HTTP code filter:        $http_code" | tee -a "$outfile" || echo "HTTP code filter:        (none)" | tee -a "$outfile"

# ============================================
#   FORCE LAST MINUTE OVERRIDE (-x)
# ============================================

if [[ "$force_last_minute" == "yes" ]]; then
    last_line=$(tail -1 "$accesslog")
    last_h=$(echo "$last_line" | awk '{match($0, /:([0-9]{2}):/, t); print t[1]}')
    last_m=$(echo "$last_line" | awk '{match($0, /:([0-9]{2}):([0-9]{2})/, t); print t[2]}')
    last_min=$((10#$last_h * 60 + 10#$last_m))

    range_start=$last_min
    range_end=$last_min

    echo "FORCE-LAST-MINUTE active: analyzing ONLY minute $last_h:$last_m" | tee -a "$outfile"
else
    if [[ -n "$minutes_range" ]]; then
        echo "Time filter:             last $minutes_range minutes (PRIORITY)" | tee -a "$outfile"
    else
        if [[ -n "$start_time" && -n "$end_time" ]]; then
            echo "Time filter:             from $start_time to $end_time" | tee -a "$outfile"
        elif [[ -n "$start_time" ]]; then
            echo "Time filter:             from $start_time to end of file" | tee -a "$outfile"
        else
            echo "Time filter:             fallback last 5 minutes" | tee -a "$outfile"
        fi
    fi
fi

[[ -n "$alert_threshold" ]] && echo "Alert threshold:         $alert_threshold requests/minute" | tee -a "$outfile" || echo "Alert threshold:         (none)" | tee -a "$outfile"

[[ "$ask_graph" == "yes" ]] && echo "ASCII graph:             interactive request enabled" | tee -a "$outfile" || echo "ASCII graph:             disabled" | tee -a "$outfile"

echo "==============================================================" | tee -a "$outfile"
echo | tee -a "$outfile"

# ============================
#   FUNCTIONS
# ============================

to_minutes() {
    local hh=${1%:*}
    local mm=${1#*:}
    echo $((10#$hh * 60 + 10#$mm))
}

sparkline() {
    local values=("$@")
    local max=0

    for v in "${values[@]}"; do
        (( v > max )) && max=$v
    done

    (( max == 0 )) && max=1

    local line=""
    for v in "${values[@]}"; do
        level=$(( v * 7 / max ))
        case $level in
            0) char="▁" ;;
            1) char="▂" ;;
            2) char="▃" ;;
            3) char="▄" ;;
            4) char="▅" ;;
            5) char="▆" ;;
            6) char="▇" ;;
            7) char="█" ;;
        esac

        if [[ -n "$alert_threshold" && $v -gt $alert_threshold ]]; then
            line+="\033[31m$char\033[0m"
        else
            line+="$char"
        fi
    done

    echo -e "$line"
}

ascii_graph() {
    local minute="$1"
    local count="$2"
    local threshold="$3"

    local blocks=""
    for ((i=0; i<count; i++)); do blocks+="█"; done

    if [[ -n "$threshold" && $count -gt $threshold ]]; then
        printf "%s | \033[31m%s\033[0m (%d)  !!! ALERT !!!\n" "$minute" "$blocks" "$count"
    else
        printf "%s | %s (%d)\n" "$minute" "$blocks" "$count"
    fi
}

count_requests() {
    local filter="$1"
    local code_filter="$2"
    local file="$3"
    local start_range="$4"
    local end_range="$5"

    awk -v f="$filter" -v cf="$code_filter" -v rs="$start_range" -v re="$end_range" '
        {
            match($0, /

\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):([0-9]{2}):([0-9]{2})/, t)
            if (!t[1]) next

            hh = t[2] + 0
            mm = t[3] + 0
            ts = hh * 60 + mm

            if (ts < rs || ts > re) next
            if ($0 !~ f) next

            match($0, /" ([0-9]{3}) /, c)
            if (cf != "" && c[1] != cf) next

            key = sprintf("%02d:%02d", hh, mm)
            count[key]++
        }
        END {
            n = asorti(count, sorted)
            for (i=1; i<=n; i++) {
                k = sorted[i]
                printf "%s %d\n", k, count[k]
            }
        }
    ' "$file"
}

count_status_codes_by_server() {
    local filter="$1"
    local file="$2"
    local start_range="$3"
    local end_range="$4"

    awk -v f="$filter" -v rs="$start_range" -v re="$end_range" '
        {
            match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):([0-9]{2}):([0-9]{2})/, t)
            if (!t[1]) next

            hh = t[2] + 0
            mm = t[3] + 0
            ts = hh * 60 + mm

            if (ts < rs || ts > re) next
            if ($0 !~ f) next

            match($0, /\[([A-Za-z0-9._-]+\.srv\.[A-Za-z0-9._-]+:[0-9]{4})\]/, s)
            server = s[1]
            if (server == "") next

            match($0, /" ([0-9]{3}) /, c)
            code = c[1]

            if (code == 200) count[server,"200"]++
            if (code == 403) count[server,"403"]++
            if (code == 500) count[server,"500"]++

            servers[server] = 1
        }
        END {
            ns = asorti(servers, s_sorted)

            for (i=1; i<=ns; i++) {
                srv = s_sorted[i]
                printf "SERVER: %s\n", srv

                if (count[srv,"200"] > 0) printf "   200 → %d\n", count[srv,"200"]
                if (count[srv,"403"] > 0) printf "   403 → %d\n", count[srv,"403"]
                if (count[srv,"500"] > 0) printf "   500 → %d\n", count[srv,"500"]

                print ""
            }
        }
    ' "$file"
}

count_status_codes() {
    local filter="$1"
    local file="$2"
    local start_range="$3"
    local end_range="$4"

    awk -v f="$filter" -v rs="$start_range" -v re="$end_range" '
        {
            match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):([0-9]{2}):([0-9]{2})/, t)
            if (!t[1]) next

            hh = t[2] + 0
            mm = t[3] + 0
            ts = hh * 60 + mm

            if (ts < rs || ts > re) next
            if ($0 !~ f) next

            match($0, /" ([0-9]{3}) /, c)
            code = c[1]

            if (code == 200) c200++
            if (code == 500) c500++
            if (code == 403) c403++
        }
        END {
            if (c200 > 0) printf "200 %d\n", c200
            if (c500 > 0) printf "500 %d\n", c500
            if (c403 > 0) printf "403 %d\n", c403
        }
    ' "$file"
}

# ============================
#   MAIN LOOP
# ============================

while true; do

    cycle_start_ts=$(date +%s)
    cycle_start_human=$(date "+%Y-%m-%d %H:%M:%S")

    echo "--------------------------------------------------------------" | tee -a "$outfile"
    echo "Cycle start: $cycle_start_human" | tee -a "$outfile"
    echo "--------------------------------------------------------------" | tee -a "$outfile"

    now=$(date)
    echo "===== $now =====" | tee -a "$outfile"

    if [[ -n "$minutes_range" ]]; then
        last_line=$(tail -1 "$accesslog")
        last_h=$(echo "$last_line" | awk '{match($0, /:([0-9]{2}):/, t); print t[1]}')
        last_m=$(echo "$last_line" | awk '{match($0, /:([0-9]{2}):([0-9]{2})/, t); print t[2]}')
        last_min=$((10#$last_h * 60 + 10#$last_m))
        range_start=$((last_min - minutes_range))
        (( range_start < 0 )) && range_start=0
        range_end=$last_min
    else
        if [[ -n "$start_time" ]]; then start_min=$(to_minutes "$start_time"); fi
        if [[ -n "$end_time" ]]; then end_min=$(to_minutes "$end_time"); fi

        if [[ -n "$start_min" && -n "$end_min" ]]; then
            range_start=$start_min
            range_end=$end_min
        elif [[ -n "$start_min" ]]; then
            range_start=$start_min
            range_end=9999
        else
            last_line=$(tail -1 "$accesslog")
            last_h=$(echo "$last_line" | awk '{match($0, /:([0-9]{2}):/, t); print t[1]}')
            last_m=$(echo "$last_line" | awk '{match($0, /:([0-9]{2}):([0-9]{2})/, t); print t[2]}')
            last_min=$((10#$last_h * 60 + 10#$last_m))
            range_start=$((last_min - 5))
            (( range_start < 0 )) && range_start=0
            range_end=$last_min
        fi
    fi

    segment=$(tail -"$tail_lines" "$accesslog")

    for url in "${urls[@]}"; do
        echo "--------------------------------------------------------------" | tee -a "$outfile"
        echo "   STATISTICS FOR URL: $url" | tee -a "$outfile"
        echo "   Range: $range_start → $range_end" | tee -a "$outfile"
        echo "--------------------------------------------------------------" | tee -a "$outfile"

        results=$(echo "$segment" | count_requests "$url" "$http_code" /dev/stdin "$range_start" "$range_end")

        if [[ -z "$results" ]]; then
            echo "No requests found for URL: $url in the selected time range" | tee -a "$outfile"
            echo | tee -a "$outfile"
            continue
        fi

        while read -r minute count; do
            if [[ -n "$alert_threshold" && $count -gt $alert_threshold ]]; then
                printf "%-10s %-10