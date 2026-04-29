    IBM HTTP Server Configuration Usage Checker
    ==========================================

    OVERVIEW
    --------
    This Bash script analyzes an IBM HTTP Server (IHS) installation to determine
    which configuration files (.conf) are actually used by control scripts (*ctl*)
    located in the bin directory.

    The main goal is to identify unused or obsolete configuration files in a
    SAFE, READ-ONLY, and DETERMINISTIC way, suitable for audit, cleanup,
    and pre-upgrade activities.

    The script DOES NOT modify any file and DOES NOT start or stop any service.


    FEATURES
    --------
    - Identifies .conf files actively referenced by *ctl* scripts
    - Maps each .conf file to the ctl file(s) that reference it
    - Displays the exact non-commented line where the .conf was found
    - Excludes commented lines and informational messages (echo)
    - Ignores standard/default IHS installation files
    - Lists:
      * Valid configuration files
      * Configuration files present but NOT used
      * Non-.conf files (invalid a priori)
    - POSIX-safe and portable
    - Production-safe (read-only)


    DIRECTORY STRUCTURE ANALYZED
    ----------------------------
    IBM_HTTP_SERVER_HOME/
    |
    |-- bin/      -> control scripts (*ctl*)
    |
    `-- conf/     -> configuration files


    REQUIREMENTS
    ------------
    - Bash (version 4 or higher recommended)
    - Unix/Linux system
    - Read permissions on:
      - IBM_HTTP_SERVER_HOME/bin
      - IBM_HTTP_SERVER_HOME/conf


    CONFIGURATION
    -------------
    At the beginning of the script, the following variables can be customized:

    HTTP_SERVER_HOME="/prod/IBM/HTTPServer"
    HOME_TMP="/prod/IBM/backup/tmp"

    HTTP_SERVER_HOME:
      Root directory of IBM HTTP Server.

    HOME_TMP:
      Temporary working directory used by the script.
      Behavior:
      - If it exists, it is used.
      - If it does not exist, the script tries to create it.
      - If creation fails (permissions, filesystem, etc.),
        the script automatically falls back to a local ./tmp directory.


    DEFAULT FILES IGNORED
    ---------------------
    The following files are STANDARD IBM HTTP Server installation files and are
    explicitly ignored by the script. They do NOT appear in any output section.

    - admin.conf.default
    - admin.passwd
    - httpd.conf.default
    - java.security.append
    - magic
    - magic.default
    - mime.types
    - mime.types.default
    - postinst.properties
    - ldap.prop.sample


    USAGE
    -----
    Make the script executable and run it:

      chmod +x check_unused_conf.sh
      ./check_unused_conf.sh

    or explicitly:

      bash check_unused_conf.sh


    DETECTION RULES
    ---------------
    A .conf file is considered USED if:

    1) Its filename appears textually inside at least one *ctl* file
    2) The line where it appears:
       - does NOT start with '#'
       - does NOT start with ';'
       - does NOT start with 'echo'
    3) The match is purely textual (no variable resolution, no runtime execution)

    This conservative approach avoids false positives and ensures deterministic
    results.


    OUTPUT SECTIONS
    ---------------

    1) CONF VALIDI E RELATIVI CTL
       --------------------------
       Lists all .conf files that are actually used.
       For each file, the output shows:
       - the ctl file(s) that reference it
       - the exact matching line (non-commented)

       Example:

         httpd_EQUSA0010.conf -> apachectl_EQUSA0010
             >> [apachectl_EQUSA0010] IHS_CONFIGURATION_FILE=/prod/IBM/HTTPServer/conf/httpd_EQUSA0010.conf


    2) CONF PRESENTI MA NON UTILIZZATI
       --------------------------------
       Lists .conf files found inside the conf directory that are NOT referenced
       by any ctl file.

       These files are strong candidates for cleanup or further review.


    3) FILE NON .conf (INVALIDI A PRIORI)
       ----------------------------------
       Lists files located in the conf directory which do NOT have a .conf
       extension and are not part of the default ignore list.

       Examples:
       - backups
       - renamed files
       - legacy snapshots


    SAFETY AND SECURITY
    -------------------
    - The script is read-only
    - No configuration file is modified
    - No service is started or stopped
    - No external commands with side effects are used
    - Safe for execution on production systems


    TYPICAL USE CASES
    -----------------
    - IBM HTTP Server pre-upgrade validation
    - Configuration cleanup
    - Security and compliance audits
    - Change advisory board (CAB) documentation
    - Hardening of long-running environments


    DESIGN PHILOSOPHY
    -----------------
    - Deterministic behavior
    - No parsing of runtime logic
    - No assumptions about variable values
    - Prefer conservative results over risky automation


    LICENSE
    -------
    Internal or enterprise use.
    Adjust licensing according to your organization’s policies.


    END OF FILE
    -----------
