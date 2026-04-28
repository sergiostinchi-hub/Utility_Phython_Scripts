# response_time_monitor.sh  
Advanced Modular Response Time Monitoring for Apache / IBM HTTP Server Logs

---

## 📌 Overview

`response_time_monitor.sh` is an enterprise‑grade, modular Bash script designed to monitor and analyze response times from Apache and IBM HTTP Server (IHS) access logs.

It supports multiple execution modes, persistent data storage, incremental log parsing, historical analysis, summary reporting, and selective data reset.  
This tool is ideal for:

- Real‑time performance monitoring  
- Troubleshooting slow backend responses  
- Tracking response time trends over time  
- WebSphere Plugin / mod_was environments  
- Automated operational dashboards  

---

## 🚀 Features

### **Execution Modes (mutually exclusive)**

| Mode              | Description                                                              |
|-------------------|--------------------------------------------------------------------------|
| `--incremental`   | Default mode. Reads only new log lines and updates metrics in real time. |
| `--history`       | One‑shot analysis of a specific time range (`-s` and `-e` required).     |
| `--summary-only`  | Displays aggregated metrics previously collected. Does not read the log. |
| `--summary-reset` | Clears stored metrics (global or per‑URL).                               |

---

## 📁 Requirements

- Bash  
- GNU `awk`  
- Standard Apache/IHS access log format  
- Persistent storage directory: `$HOME/.rtm_temp` (auto‑created)

---

## 📥 Usage

```bash
./response_time_monitor.sh -f <log_file> -u <url> [options]
