# IBM HTTP Server Configuration Usage Checker

## OVERVIEW

This Bash script analyzes an IBM HTTP Server (IHS) installation to determine
which configuration files (\*.conf) are actually used by control scripts (*ctl*)
located in the bin directory.

The script is designed to be safe, deterministic, audit-friendly, and suitable
for production environments.

It also supports an optional controlled cleanup step using the --clean option.

## FEATURES

*   Detects .conf files referenced by *ctl* scripts
*   Maps each .conf file to the ctl file(s) that reference it
*   Displays the exact non-commented line where the .conf was found
*   Ignores commented lines (#, ;)
*   Ignores informational lines starting with "echo"
*   Identifies .conf files present but not used
*   Identifies non-.conf files (invalid a priori)
*   Optional safe cleanup (--clean)
*   No file is deleted (files are only moved)
*   POSIX-safe, portable, no external dependencies

## DIRECTORY STRUCTURE

IBM\_HTTP\_SERVER\_HOME/
|
\|-- bin/        -> ctl scripts
|
\`-- conf/       -> configuration files

## REQUIREMENTS

*   Bash (recommended version 4.x or higher)
*   Unix / Linux system
*   Read access to:
    *   IBM\_HTTP\_SERVER\_HOME/bin
    *   IBM\_HTTP\_SERVER\_HOME/conf
*   Write access required only when using --clean

## CONFIGURATION

Main variables defined at the beginning of the script:

HTTP\_SERVER\_HOME="/prod/IBM/HTTPServer"
HOME\_TMP="/prod/IBM/backup/tmp"

HTTP\_SERVER\_HOME
Root directory of IBM HTTP Server.

HOME\_TMP
Temporary working directory used by the script.

Behavior:

*   If it exists, it is used
*   If it does not exist, the script tries to create it
*   If creation fails, a local ./tmp directory is used as fallback

## IGNORED DEFAULT FILES

The following standard IBM HTTP Server files are ignored during analysis
and do not appear in any report section:

admin.conf.default
httpd.conf.default
java.security.append
magic
magic.default
mime.types
mime.types.default
postinst.properties
ldap.prop.sample

## Sensitive file exception

The following file is NEVER moved, even when --clean is used:

admin.passwd

This is intentional to avoid handling sensitive credentials.

## DETECTION RULES

A .conf file is considered USED if:

1.  Its filename appears textually in at least one *ctl* file
2.  The matching line:
    *   does NOT start with #
    *   does NOT start with ;
    *   does NOT start with echo
3.  The match is static (no variable expansion, no runtime evaluation)

This conservative approach avoids false positives.

## USAGE

Analysis only (default, safe):

./check\_unused\_conf.sh

Analysis + safe cleanup:

./check\_unused\_conf.sh --clean

## CLEAN MODE (--clean)

When --clean is specified:

*   The following directory is created if possible:

IBM\_HTTP\_SERVER\_HOME/conf/conf\_unused

*   The following files are MOVED (not deleted):
    *   .conf files present but not used
    *   non-.conf files (invalid a priori)
    *   default ignored files (except admin.passwd)

If the directory cannot be created, the clean step is skipped and the following
warning is shown:

\[WARN] Impossible to complete cleaning step

Analysis and reporting still complete normally.

## OUTPUT SECTIONS

CONF VALIDI E RELATIVI CTL
Shows .conf files that are actually used, including:

*   the ctl file(s) referencing them
*   the exact non-commented line where they were found

Example:

httpd\_EQUSA0010.conf -> apachectl\_EQUSA0010
\>> \[apachectl\_EQUSA0010] IHS\_CONFIGURATION\_FILE=/prod/IBM/HTTPServer/conf/httpd\_EQUSA0010.conf

CONF PRESENTI MA NON UTILIZZATI
Lists .conf files found in conf/ that are never referenced by any ctl script.
These are strong candidates for cleanup.

FILE NON .conf (INVALIDI A PRIORI)
Lists files located in conf/ that do not have a .conf extension and are not part
of the default ignore list (e.g. backups, renamed files, snapshots).

## FILES MOVED TO conf\_unused (only with --clean)

When --clean is used, a final section lists all files that were actually moved.

Example:

## FILES MOVED TO /prod/IBM/HTTPServer/conf/conf\_unused

httpd\_old.conf
mime.types
magic
httpd.conf.20220103

## SAFETY GUARANTEES

*   No file is modified unless --clean is explicitly specified
*   No file is deleted
*   No service is started or stopped
*   Suitable for production systems
*   Designed for audit and compliance use cases

## TYPICAL USE CASES

*   IBM HTTP Server upgrade preparation
*   Configuration cleanup
*   Environment hardening
*   Compliance and audit reporting
*   Change Advisory Board (CAB) documentation

## DESIGN PRINCIPLES

*   Deterministic behavior
*   No runtime interpretation
*   No guessing or implicit assumptions
*   Conservative results preferred over risky automation

## LICENSE

Internal or enterprise use.
Adapt licensing according to your organization’s policies.

## END OF FILE

