#!/bin/bash

# ============================
#   SHELL CHECK
# ============================

if [ -z "$BASH_VERSION" ]; then
    echo
    echo "=============================================================="
    echo "   ERROR: This script must be executed using BASH"
    echo "=============================================================="
    echo
    echo "Run it like this:"
    echo "    bash $0 ..."
    echo
    exit 1
fi

# ============================
#   HELP
# ============================

usage() {
    echo
    echo "=============================================================="
    echo "      CONTEXT ROOT EXTRACTION FROM LOG (LAST N LINES)"
    echo "=============================================================="
    echo
    echo "USAGE:"
    echo "  $0 -f <log_file> [-n <tail_lines>] [-m <method>] [-m <method2>]"
    echo
    echo "OPTIONS:"
    echo "  -f <log_file>     Log file to analyze (REQUIRED)"
    echo "  -n <lines>        Number of lines to read (default: 1000)"
    echo "  -m <method>       Filter by HTTP method (GET, POST, PUT, DELETE, ...)"
    echo "                    Can be repeated multiple times"
    echo "  -h                Show this help"
    echo
    echo "EXAMPLES:"
    echo "  $0 -f access.log"
    echo "  $0 -f access.log -n 5000 -m GET"
    echo "  $0 -f access.log -m GET -m POST"
    echo
    exit 1
}

# ============================
#   PARAMETER PARSING
# ============================

tail_lines=1000
methods=()

while getopts "f:n:m:h" opt; do
    case "$opt" in
        f) logfile="$OPTARG" ;;
        n) tail_lines="$OPTARG" ;;
        m) methods+=("$OPTARG") ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$logfile" ]]; then
    usage
fi

# ============================
#   METHOD FILTER PREPARATION
# ============================

method_filter=""

if (( ${#methods[@]} > 0 )); then
    # Builds a regex like:  "GET |"POST |"PUT 
    method_filter="("
    for m in "${methods[@]}"; do
        method_filter+="\"$m |"
    done
    method_filter="${method_filter%|})"
fi

# ============================
#   INITIAL HEADER
# ============================

echo "=============================================================="
echo "      CONTEXT ROOT ANALYSIS FROM LAST $tail_lines LINES"
echo "=============================================================="
echo "Log file:    $logfile"
echo "Lines read:  $tail_lines"

if [[ -n "$method_filter" ]]; then
    echo "Filtered methods: ${methods[*]}"
else
    echo "Filtered methods: (none, all)"
fi

echo "=============================================================="
echo

# ============================
#   CONTEXT ROOT EXTRACTION
# ============================

tail -"$tail_lines" "$logfile" \
| awk -v mf="$method_filter" '
{
    # If a method filter is defined, apply it
    if (mf != "" && $0 !~ mf) next

    # Extract the first part of the URL after the HTTP method
    # Example: "GET /serviceA/api/login → /serviceA
    match($0, /"[^ ]+ (\/[^\/ ]+)/, m)
    if (m[1] != "") {
        root = m[1]
        count[root]++
    }
}
END {
    printf "%-30s %-10s\n", "Context Root", "Count"
    printf "%-30s %-10s\n", "------------------------------", "----------"

    PROCINFO["sorted_in"] = "@val_num_desc"

    for (r in count) {
        printf "%-30s %-10d\n", r, count[r]
    }
}
'
