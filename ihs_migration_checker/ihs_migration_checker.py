#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
IHS Migration Checker con DEEP DEBUG + Categoria OK
Controlla un file .conf di IBM IHS 8.5.5 (Apache 2.2)
e identifica differenze rispetto a IHS 9 (Apache 2.4)
usando un file di regole esterno (JSON) e una whitelist di direttive valide.
"""

import json
import re
import sys
from pathlib import Path

# ============================================================
# DEBUG MODE (attivabile con --debug)
# ============================================================
DEBUG_DEEP = False
DEBUG_LOG_FILE = "debug.log"


def debug(msg):
    """Stampa e registra messaggi di debug solo se DEBUG_DEEP è attivo."""
    if DEBUG_DEEP:
        print("[DEBUG] " + msg)
        with open(DEBUG_LOG_FILE, "a", encoding="utf-8") as df:
            df.write("[DEBUG] " + msg + "\n")


# ============================================================
# LOADING WHITELIST
# ============================================================
def load_whitelist(whitelist_file):
    debug(f"Caricamento whitelist da: {whitelist_file}")

    with open(whitelist_file, "r", encoding="utf-8") as f:
        data = json.load(f)

        cleaned = set()
        for d in data.get("valid_directives", []):
            if not d:
                continue

            original = d
            d = (
                d.strip()
                 .upper()
                 .replace("\uFEFF", "")
                 .replace("\u00A0", "")
                 .replace("\t", "")
            )

            debug(f"Whitelist: '{original}' → '{d}'")
            cleaned.add(d)

        debug(f"Totale direttive whitelist pulite: {len(cleaned)}")
        return cleaned


# ============================================================
# LOADING RULES
# ============================================================
def load_rules(rule_file):
    debug(f"Caricamento rules da: {rule_file}")

    with open(rule_file, "r", encoding="utf-8") as f:
        rules = json.load(f)

        rules["deprecated"] = {k.upper(): v for k, v in rules.get("deprecated", {}).items()}
        rules["changed"] = {k.upper(): v for k, v in rules.get("changed", {}).items()}

        debug(f"Regole deprecated: {len(rules['deprecated'])}")
        debug(f"Regole changed: {len(rules['changed'])}")

        return rules


# ============================================================
# PARSING CONF
# ============================================================
def parse_conf(conf_file):
    debug(f"Parsing file conf: {conf_file}")

    directives = []
    pattern = re.compile(r"^\s*([A-Za-z][A-Za-z0-9]+)")

    with open(conf_file, "r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            match = pattern.match(line)
            if match:
                directive = match.group(1).upper()
                debug(f"Riga {lineno}: trovata direttiva '{directive}' → '{line.strip()}'")
                directives.append((directive, line.strip(), lineno))

    debug(f"Totale direttive trovate: {len(directives)}")
    return directives


# ============================================================
# ANALYSIS
# ============================================================
def analyze(directives, rules, whitelist):
    debug("Inizio analisi direttive")

    deprecated = rules.get("deprecated", {})
    changed = rules.get("changed", {})

    results = {
        "deprecated": [],
        "changed": [],
        "unknown": [],
        "not_in_whitelist": [],
        "ok": []
    }

    for directive, full_line, lineno in directives:

        if directive in deprecated:
            debug(f"[DEPRECATED] {directive} (riga {lineno})")
            results["deprecated"].append((directive, full_line, lineno, deprecated[directive]))

        elif directive in changed:
            debug(f"[CHANGED] {directive} (riga {lineno})")
            results["changed"].append((directive, full_line, lineno, changed[directive]))

        elif directive not in whitelist:
            debug(f"[NOT IN WHITELIST] {directive} (riga {lineno})")
            results["not_in_whitelist"].append((directive, full_line, lineno))

        else:
            # Direttiva valida in whitelist → OK
            debug(f"[OK] {directive} (riga {lineno})")
            results["ok"].append((directive, full_line, lineno))

    return results


# ============================================================
# REPORT
# ============================================================
def write_report(results, output_file):
    debug(f"Scrittura report su: {output_file}")

    with open(output_file, "w", encoding="utf-8") as f:

        f.write("=== IHS 8.5.5 → IHS 9 Migration Report ===\n\n")

        f.write("== Direttive deprecate ==\n")
        for d, line, lineno, msg in results["deprecated"]:
            f.write(f"- {d} (riga {lineno}): {line}\n  → {msg}\n")
        f.write("\n")

        f.write("== Direttive modificate ==\n")
        for d, line, lineno, msg in results["changed"]:
            f.write(f"- {d} (riga {lineno}): {line}\n  → {msg}\n")
        f.write("\n")

        f.write("== Direttive non presenti in whitelist ==\n")
        for d, line, lineno in results["not_in_whitelist"]:
            f.write(f"- {d} (riga {lineno}): {line}\n")
        f.write("\n")

        f.write("== Direttive OK (valide e senza azioni richieste) ==\n")
        for d, line, lineno in results["ok"]:
            f.write(f"- {d} (riga {lineno}): {line}\n")
        f.write("\n")

        f.write("== Direttive valide ma non mappate (unknown) ==\n")
        for d, line, lineno in results["unknown"]:
            f.write(f"- {d} (riga {lineno}): {line}\n")
        f.write("\n")

        f.write("=== SEZIONE SPECIALE: RIGHE PROBLEMATICHE ===\n")
        f.write("Questa sezione elenca SOLO le righe del conf che richiedono intervento.\n\n")

        for d, line, lineno, msg in results["deprecated"]:
            f.write(f"[DEPRECATED] riga {lineno}: {line}\n")

        for d, line, lineno, msg in results["changed"]:
            f.write(f"[CHANGED] riga {lineno}: {line}\n")

        for d, line, lineno in results["not_in_whitelist"]:
            f.write(f"[NOT IN WHITELIST] riga {lineno}: {line}\n")

        f.write("\n=== Fine report ===\n")


# ============================================================
# MAIN
# ============================================================
def main():
    global DEBUG_DEEP

    if len(sys.argv) < 5:
        print("Uso: python ihs_migration_checker.py <file.conf> <rules.json> <whitelist.json> <output_report.txt> [--debug]")
        sys.exit(1)

    if "--debug" in sys.argv:
        DEBUG_DEEP = True
        open(DEBUG_LOG_FILE, "w").close()
        debug("DEEP DEBUG MODE ATTIVATO")

    conf_file = Path(sys.argv[1])
    rule_file = Path(sys.argv[2])
    whitelist_file = Path(sys.argv[3])
    output_file = Path(sys.argv[4])

    rules = load_rules(rule_file)
    whitelist = load_whitelist(whitelist_file)
    directives = parse_conf(conf_file)

    results = analyze(directives, rules, whitelist)
    write_report(results, output_file)

    print(f"Report generato: {output_file}")
    if DEBUG_DEEP:
        print(f"Debug log generato: {DEBUG_LOG_FILE}")


if __name__ == "__main__":
    main()

