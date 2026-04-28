# extract_context_roots.sh  
Advanced Context‑Root Extraction from Apache / IBM HTTP Server Access Logs

---

## 📌 Overview

`extract_context_roots.sh` is a lightweight but powerful Bash script designed to quickly extract and count **context‑roots** from the last N lines of an Apache or IBM HTTP Server (IHS) access log.

It supports optional filtering by HTTP method and is ideal for troubleshooting, traffic analysis, and identifying which applications receive the most hits.

---

## 🚀 Features

- Extracts **context‑roots** from access logs  
- Supports **multiple HTTP method filters** (GET, POST, PUT, DELETE, etc.)  
- Reads only the **last N lines** for fast analysis  
- Compatible with Apache and IBM HTTP Server log formats  
- Clean, readable output sorted by hit count  
- Automatic validation of required parameters  
- Ensures the script is executed with **Bash** (not sh, dash, etc.)

---

## 📁 Requirements

- Bash (required)
- GNU `awk`
- Standard Apache/IHS access log format

---

## 📥 Usage

```bash
./extract_context_roots.sh -f <file_log> [-n <lines>] [-m <method>] [-m <method2>]
