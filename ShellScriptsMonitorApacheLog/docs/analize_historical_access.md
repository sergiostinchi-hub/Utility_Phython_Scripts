# analize_historical_access.sh  
Advanced Apache / IBM HTTP Server Access Log Analyzer  
Enterprise‑grade parsing for mod_was / WebSphere Plugin environments

---

## 📌 Overview

`analize_historical_access.sh` is a robust Bash script designed to analyze Apache and IBM HTTP Server (IHS) access logs, including environments using the WebSphere Plugin (`mod_was`).  
It provides detailed statistics such as:

- Return codes per context‑root  
- Hits per hour  
- Average response time per hour  
- Top client IPs  
- Response time percentiles (p50, p90, p95, p99)  
- Microsecond‑level timing extraction  
- Safe file‑in‑use detection  

This script is built for enterprise environments where log formats may vary and reliability is critical.

---

## 🚀 Features

- **Enterprise‑grade AWK parser** compatible with Apache and IBM HTTP Server  
- **Safe file‑in‑use detection** using `lsof` and size‑stability checks  
- **Context‑root filtering** for targeted analysis  
- **Robust extraction** of:
  - HTTP method  
  - URL  
  - Return code  
  - Response time (microseconds → milliseconds)  
  - Client IP  
  - Timestamp normalization  
- **Percentile calculation** for response times  
- **Top IP ranking**  
- **Hourly aggregation** of hits and average response times  

---

## 📁 Requirements

- Bash (Linux/Unix environment)
- `awk` (GNU awk recommended)
- `lsof` (optional but recommended)
- Access log in standard Apache/IHS format

---

## 📥 Usage

```bash
./analize_historical_access.sh -f <access.log> -c <context-root>
