# IBM HTTP Server Configuration Usage Checker

## Overview

This Bash script analyzes an **IBM HTTP Server (IHS)** installation to determine which configuration files (`*.conf`) are **actually used** by control scripts (`*ctl*`) located in the `bin` directory.

The script is designed to be:

- ✅ Safe (read-only by default)
- ✅ Deterministic
- ✅ Audit-friendly
- ✅ Suitable for production environments

It also supports an optional **controlled cleanup** step using the `--clean` option.

---

## Features

- Detects `.conf` files referenced by `*ctl*` scripts
- Maps each `.conf` file to the `ctl` file(s) that reference it
- Displays the **exact non-commented line** where the `.conf` was found
- Ignores:
  - commented lines (`#`, `;`)
  - informational lines starting with `echo`
- Identifies:
  - `.conf` files present but **not used**
  - **non-`.conf` files** (invalid a priori)
- Optional **safe cleanup** (`--clean`)
- No file is deleted (files are only moved)
- POSIX-safe, portable, no external dependencies

---

## Directory Structure

The script assumes the following IBM HTTP Server structure:

```text
IBM_HTTP_SERVER_HOME/
├── bin/        # ctl scripts
└── conf/       # configuration files
