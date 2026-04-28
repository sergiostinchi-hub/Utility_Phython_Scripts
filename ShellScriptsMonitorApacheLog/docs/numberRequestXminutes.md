# numberRequestXminutes.sh  
Advanced Real‑Time Request Monitoring for Apache / IBM HTTP Server Logs

---

## 📌 Overview

`numberRequestXminutes.sh` is an enterprise‑grade Bash script designed to monitor request volumes in Apache and IBM HTTP Server (IHS) access logs.  
It supports real‑time looping mode, one‑shot analysis, URL filtering, HTTP code filtering, time‑range selection, ASCII graph visualization, alert thresholds, and per‑application‑server status breakdowns.

This tool is ideal for:

- Production troubleshooting  
- Performance monitoring  
- Detecting traffic spikes  
- Identifying slow or failing backend servers  
- Real‑time operational dashboards  

---

## 🚀 Features

- **Real‑time monitoring** with configurable loop interval  
- **One‑shot mode** for single execution  
- **URL filtering** (multiple `-u` parameters supported)  
- **HTTP status code filtering**  
- **Time‑range selection**:
  - Last X minutes  
  - Custom start/end time  
  - Forced last minute (`-x`)  
- **Sparkline visualization** (Unicode mini‑graph)  
- **Optional ASCII bar graph**  
- **Alert threshold** for requests/minute  
- **Per‑application‑server HTTP status breakdown**  
- **Automatic log‑file stability check**  
- **Full execution log saved to timestamped file**  

---

## 📁 Requirements

- Bash (required)
- GNU `awk`
- Standard Apache/IHS access log format
- UTF‑8 compatible terminal for sparkline output

---

## 📥 Usage

```bash
./numReqLastXMin.sh -f <log_file> -u <url> [options]
