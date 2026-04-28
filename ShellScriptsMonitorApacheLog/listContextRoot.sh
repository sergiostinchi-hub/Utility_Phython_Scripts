#!/bin/bash

# ============================
#   CONTROLLO SHELL CORRETTA
# ============================

if [ -z "$BASH_VERSION" ]; then
    echo
    echo "=============================================================="
    echo "   ERRORE: Questo script deve essere eseguito con BASH"
    echo "=============================================================="
    echo
    echo "Lancialo così:"
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
    echo "      SCRIPT ESTRAZIONE CONTEXT ROOT DAL LOG (ULTIME N RIGHE)"
    echo "=============================================================="
    echo
    echo "USO:"
    echo "  $0 -f <file_log> [-n <righe_tail>] [-m <metodo>] [-m <metodo2>]"
    echo
    echo "OPZIONI:"
    echo "  -f <file_log>     File di log da analizzare (OBBLIGATORIO)"
    echo "  -n <righe>        Numero di righe da leggere (default: 1000)"
    echo "  -m <metodo>       Filtra per metodo HTTP (GET, POST, PUT, DELETE, ...)"
    echo "                    Può essere ripetuto più volte"
    echo "  -h                Mostra questo help"
    echo
    echo "ESEMPI:"
    echo "  $0 -f access.log"
    echo "  $0 -f access.log -n 5000 -m GET"
    echo "  $0 -f access.log -m GET -m POST"
    echo
    exit 1
}

# ============================
#   PARSING PARAMETRI
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
#   PREPARAZIONE FILTRO METODI
# ============================

method_filter=""

if (( ${#methods[@]} > 0 )); then
    # Costruisce una regex tipo:  "GET |"POST |"PUT 
    method_filter="("
    for m in "${methods[@]}"; do
        method_filter+="\"$m |"
    done
    method_filter="${method_filter%|})"
fi

# ============================
#   STAMPA INIZIALE
# ============================

echo "=============================================================="
echo "      ANALISI CONTEXT ROOT DALLE ULTIME $tail_lines RIGHE"
echo "=============================================================="
echo "File log:   $logfile"
echo "Righe lette: $tail_lines"

if [[ -n "$method_filter" ]]; then
    echo "Metodi filtrati: ${methods[*]}"
else
    echo "Metodi filtrati: (nessuno, tutti)"
fi

echo "=============================================================="
echo

# ============================
#   ESTRAZIONE CONTEXT ROOT
# ============================

tail -"$tail_lines" "$logfile" \
| awk -v mf="$method_filter" '
{
    # Se è stato richiesto un filtro metodo, applicalo
    if (mf != "" && $0 !~ mf) next

    # Estrae la prima parte dell’URL dopo il metodo HTTP
    # Esempio: "GET /serviceA/api/login → /serviceA
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
