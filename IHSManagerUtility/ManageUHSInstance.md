```markdown
# ManageIHSInstance.sh

A robust and production‑ready management script for **IBM HTTP Server (IHS)** instances.  
It automatically analyzes configuration files, maps them to their corresponding `apachectl` scripts, and provides safe operations such as **start**, **stop**, **status**, and **cleanup**.

Designed for environments with multiple IHS instances and complex configuration layouts.

---

## 🚀 Features

- 🔍 **Automatic discovery** of valid `.conf` files  
- 🔗 **Mapping** between `.conf` files and their corresponding `apachectl` scripts  
- 🧹 **Cleanup mode** to move unused or invalid configuration files  
- ▶️ **Start** all IHS instances linked to active `.conf` files  
- ⏹️ **Stop** all IHS instances linked to active `.conf` files  
- 📊 **Status check** with color‑coded output:
  - **RUNNING** (green)
  - **NOT RUNNING** (red)
  - **FAILED TO START** (red, bold)
- ⏱️ **Configurable delay** before status check to allow httpd startup to settle  
- 🔒 Safe handling of sensitive files (never moved)  
- 🧾 Clean and readable output, suitable for automation and monitoring  

---

## 📦 Requirements

- Linux/Unix environment  
- IBM HTTP Server installed  
- Bash 4+  
- Permissions to execute `apachectl` and read IHS configuration directories  

---

## 📁 Directory Structure Assumptions

The script assumes:

```
/prod/IBM/HTTPServer/
 ├── bin/               # Contains apachectl scripts
 ├── conf/              # Contains .conf files
 │    └── conf_unused/  # Created automatically if needed
 └── backup/tmp/        # Temporary working directory
```

Paths can be modified inside the script if needed.

---

## 🔧 Installation

Clone the repository or copy the script into your environment:

```bash
chmod +x ManageIHSInstance.sh
```

---

## 🧭 Usage

### Show help
```bash
./ManageIHSInstance.sh --help
```

### Start all IHS instances
```bash
./ManageIHSInstance.sh --start
```

### Stop all IHS instances
```bash
./ManageIHSInstance.sh --stop
```

### Show status of all instances
```bash
./ManageIHSInstance.sh --status
```

### Clean unused or invalid configuration files
```bash
./ManageIHSInstance.sh --clean
```

---

## 📊 Status Output Example

```
============================================================
 STATUS CHECK OF ALL CTL SCRIPTS
============================================================
adminctl                         FAILED TO START
apachectl_gudval_ocp             RUNNING
apachectl_spdval_trawlplv04-01   RUNNING
apachectl_trawlplv01-bridge      RUNNING
apachectl_trawlplv04_wsarcipelago RUNNING
```

---

## ⚙️ Internal Configuration

Inside the script you can customize:

```bash
STATUS_DELAY=5
```

This defines how many seconds to wait before performing the status check after a start/stop operation.

---

## 🧠 How It Works (Technical Overview)

1. Scans the IHS `conf/` directory  
2. Identifies valid `.conf` files  
3. Maps each `.conf` to its corresponding `apachectl` script  
4. Executes requested operations (start/stop/clean/status)  
5. Performs a **process‑level check** by matching:
   - the `httpd` process  
   - the `-f <conf>` argument  
6. Produces a color‑coded status report  

This ensures **accurate detection**, even when ctl names differ from process names.

---

## 🗺️ Roadmap

- [ ] Add `--restart` (stop + start)
- [ ] Add optional logging to file
- [ ] Add JSON output mode for monitoring tools
- [ ] Add verbose/debug mode

---

## 📄 License

This project can be released under any license you prefer (MIT recommended).  
Add your license text here.
```

---



