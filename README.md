# 🚀 Advanced Network Monitor (ANM)

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/sundaresan-dev/advanced-network-monitor/graphs/commit-activity)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)](#)

A comprehensive **network monitoring tool** designed for **Site Reliability Engineers (SREs), DevOps Engineers, and SysAdmins**.  
**ANM** provides deep insights into **network health, service dependencies, security posture, and performance metrics** with a single command.

---

## 📌 Why ANM?

- One command = Full infra health snapshot
- Works on servers, VPS, cloud, and local machines
- Perfect for **DevOps, SRE, Ethical Hackers, Hosting providers**
- Lightweight, fast, and scriptable
- Human-readable + JSON output for automation

---

## ✨ Features

- **🔍 DNS Analysis** – Multi-server DNS resolution with DNSSEC validation  
- **🌐 Network Layer Checks** – Latency, jitter, packet loss, and stability tests  
- **🔌 Port Scanning** – Service detection and banner grabbing  
- **🌍 Web Server Analysis** – HTTP metrics, SSL/TLS expiry, security headers  
- **🛡️ Security Checks** – Basic vulnerability hints, security header analysis  
- **📊 Dependency Analysis** – Health checks for databases, message queues, monitoring tools  
- **📈 Performance Metrics** – Throughput testing, connection pooling analysis  
- **📝 Comprehensive Reporting** – Health scoring, recommendations, JSON output  
- **🔄 Continuous Monitoring** – Run with configurable intervals  
- **📂 Logging Support** – Save reports to file  
- **🤖 Automation Ready** – JSON output for CI/CD, cron jobs, monitoring systems  

---

## 🚀 One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/sundaresan-dev/advanced-network-monitor/main/install.sh | sudo bash

---

## Clone the repository

```bash
git clone https://github.com/sundaresan-dev/advanced-network-monitor.git
cd advanced-network-monitor

## Make the script executable
chmod +x anm.sh

## Run directly
./anm.sh -t example.com

## Or install manually system-wide
sudo cp anm.sh /usr/local/bin/anm
sudo chmod +x /usr/local/bin/anm

---
## Basic monitoring
anm -t google.com

## Continuous monitoring every 30 seconds
anm -t api.example.com -c -i 30

## Custom ports with JSON output
anm -t myserver.com -p "80 443 3306" -j

## Verbose mode with all checks
anm -t example.com -v

## Log output to file
anm -t example.com -l /var/log/anm/monitor.log

