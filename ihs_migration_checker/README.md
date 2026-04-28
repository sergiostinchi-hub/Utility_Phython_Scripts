IHS Migration Checker
=====================

A command-line tool for analyzing IBM HTTP Server (IHS) 8.5.5 configuration files and identifying compatibility issues when migrating to IHS 9 (Apache 2.4).

This script parses an IHS configuration file, validates directives against a whitelist, applies migration rules, and generates a detailed report highlighting deprecated, changed, unknown, OK, and problematic directives.

------------------------------------------------------------
FEATURES
------------------------------------------------------------

- Directive extraction with line numbers
- Automatic normalization (UPPERCASE, whitespace cleanup)
- Whitelist validation (Apache 2.4 + IBM IHS 9 directives)
- Migration rules engine:
  * Deprecated directives
  * Changed directives
  * IBM-specific SSL and tracing directives
- Categorized output:
  * Deprecated
  * Changed
  * Not in whitelist
  * OK (valid, no action required)
  * Unknown (valid but not mapped in rules.json)
- Deep debug mode (--debug) with full trace logging
- Clean, readable migration report

------------------------------------------------------------
PROJECT STRUCTURE
------------------------------------------------------------

ihs_migration_checker.py     - Main script
rules.json                   - Migration rules (deprecated/changed)
whitelist.json               - Valid directives for IHS 9

------------------------------------------------------------
USAGE
------------------------------------------------------------

Basic usage:

python ihs_migration_checker.py <config.conf> <rules.json> <whitelist.json> <output_report.txt>

Example:

python ihs_migration_checker.py httpd.conf rules.json whitelist.json report.txt

------------------------------------------------------------
DEEP DEBUG MODE
------------------------------------------------------------

Enable deep debug logging:

python ihs_migration_checker.py httpd.conf rules.json whitelist.json report.txt --debug

This generates:
- Console debug output
- A debug.log file with detailed parsing and matching information

Useful for troubleshooting unexpected directive classifications.

------------------------------------------------------------
OUTPUT REPORT
------------------------------------------------------------

The generated report includes:

- Deprecated directives
- Changed directives
- Directives not in whitelist
- OK directives (valid, no action required)
- Unknown directives (valid but not mapped in rules.json)
- Problematic lines summary (only lines requiring attention)

This makes it easy to identify what must be updated before migrating to IHS 9.

------------------------------------------------------------
HOW IT WORKS
------------------------------------------------------------

1. The script parses the configuration file and extracts directives.
2. Each directive is normalized (uppercase, trimmed, cleaned).
3. The directive is checked against:
   - rules.json (deprecated/changed)
   - whitelist.json (valid directives)
4. The directive is categorized accordingly.
5. A structured migration report is generated.

------------------------------------------------------------
REQUIREMENTS
------------------------------------------------------------

- Python 3.x
- No external dependencies
- Compatible with Jython (for WebSphere environments)

------------------------------------------------------------
CUSTOMIZATION
------------------------------------------------------------

You can extend:

whitelist.json
  Add custom IBM directives or internal company directives.

rules.json
  Add migration rules, deprecations, or custom mapping logic.

------------------------------------------------------------
CONTRIBUTING
------------------------------------------------------------

Contributions are welcome!

You can:
- Add new migration rules
- Improve directive coverage
- Enhance reporting
- Submit bug fixes

Open a pull request or create an issue in the repository.

------------------------------------------------------------
LICENSE
------------------------------------------------------------

This project is released under the MIT License.
See LICENSE for details.

------------------------------------------------------------
CONTACT
------------------------------------------------------------

For questions or improvements, feel free to open an issue or submit a pull request.
