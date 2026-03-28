# Production Observability Stack

A fully automated, production-grade observability platform built entirely from open-source tools.
One command starts Prometheus, Grafana, Loki, Alertmanager, Promtail, Node Exporter, cAdvisor,
and a demo application with pre-built dashboards and alerting rules — no manual UI setup required.

---

## Senior Skills Demonstrated

| Skill | Evidence |
|---|---|
| SRE observability design | Three pillars: metrics (Prometheus), logs (Loki), and alerting (Alertmanager) |
| Prometheus alert rule authoring | Multi-severity rules: CPU, memory, disk (predictive fill), I/O, latency, error rate |
| SLO-based alerting | P95 and P99 latency alerts, error rate as a percentage of total traffic |
| Recording rules | Pre-aggregated request rate, error ratio, and latency percentile rules |
| Grafana dashboard-as-code | 4 dashboards provisioned automatically from JSON — zero manual setup |
| Log aggregation pipeline | Promtail Docker SD, JSON pipeline stages, label relabeling, timestamp parsing |
| Alert routing design | Severity-based routing tree, inhibition rules, group deduplication |
| Prometheus configuration | File-based SD, metric relabeling, per-job scrape intervals, retention config |
| Container metrics | cAdvisor integration for per-container CPU, memory, network |
| Operational tooling | Makefile with health checks, config reload, rule validation, load testing |

---

## Architecture

```
┌────────────┐     scrape     ┌─────────────┐    dashboards    ┌─────────┐
│  demo-app  │ ─────────────► │ Prometheus  │ ◄─────────────── │ Grafana │
│ :8080      │                │ :9090       │                  │ :3000   │
└────────────┘                └─────────────┘                  └─────────┘
                                     │                               │
┌─────────────┐   scrape             │ alert rules                   │ query
│ node-exporter│ ────────────►       │                               │
│  :9100       │              ┌──────▼──────┐              ┌─────────┘
└─────────────┘              │ Alertmanager│              │
                              │  :9093      │         ┌────▼──────┐
┌─────────────┐   scrape      └─────────────┘         │   Loki    │
│  cAdvisor   │ ─────────────►  Slack / PD            │  :3100    │
│  :8081      │                                        └─────┬─────┘
└─────────────┘                                             ▲ push
                                                      ┌─────┴──────┐
                                                      │  Promtail  │
                                                      │ (all conts)│
                                                      └────────────┘
```

---

## Project Structure

```
production-observability-stack/
  docker-compose.yml                        # Full 8-service stack definition
  prometheus/
    prometheus.yml                          # Scrape config, retention, alertmanager target
    rules/
      node-alerts.yml                       # 10+ host alerts: CPU, memory, disk, I/O, network
      app-alerts.yml                        # HTTP error rate, P95/P99 latency, container OOM
                                            # Plus recording rules for dashboard performance
    targets/
      extra-targets.yml                     # File-based service discovery example
  alertmanager/
    alertmanager.yml                        # Routing tree, inhibition, Slack/PD receivers
  loki/
    loki.yml                                # Single-process Loki: TSDB schema, retention, compactor
  promtail/
    promtail.yml                            # Docker SD, JSON pipeline, label relabeling
  grafana/
    provisioning/
      datasources/datasources.yml           # Prometheus + Loki + Alertmanager auto-provisioned
      dashboards/dashboards.yml             # Dashboard folder provisioning config
    dashboards/
      node-overview.json                    # CPU gauge, memory breakdown, disk bar, network I/O
      app-overview.json                     # Request rate, error rate, P95/P99 latency stats
      container-metrics.json               # CPU/memory/network per container (cAdvisor)
      logs-explorer.json                    # Loki log viewer with service and text search filters
  scripts/
    demo_app.py                             # Flask app with background traffic generator
    load-test.sh                            # Concurrent HTTP load generator
  Makefile                                  # All operations: up, health, alerts, reload, test
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker | 24+ | https://docs.docker.com/engine/install/ |
| Docker Compose | v2 (built-in) | bundled with Docker Desktop |
| Python | 3.11+ (optional, for local demo app) | https://python.org |

---

## Quick Start

### Step 1 — Start the full stack

```bash
make up
```

All 8 services start in parallel. Allow 30 seconds for health checks to pass.

### Step 2 — Verify all services are healthy

```bash
make health
```

Expected output: All four services reporting OK.

### Step 3 — Open Grafana

Navigate to http://localhost:3000 in your browser.

Login credentials:
- Username: `admin`
- Password: `observability`

Four dashboards are pre-loaded under the "Observability Stack" folder:
- Node Overview
- Application Overview
- Container Metrics
- Logs Explorer

No manual datasource or dashboard configuration is required.

### Step 4 — Check Prometheus targets

Open http://localhost:9090/targets

All targets should show state = UP.

### Step 5 — Generate load to populate dashboards

```bash
make load-test
```

This runs 5 concurrent workers for 120 seconds hitting all demo app endpoints,
including the slow and error endpoints that will trigger alert conditions.

### Step 6 — View active alerts

```bash
make alerts
```

Or open http://localhost:9090/alerts to see the Prometheus alert state.
Open http://localhost:9093 to see Alertmanager's routing and grouping.

### Step 7 — Validate alert rules

```bash
make check-rules
make check-config
```

### Step 8 — Hot-reload Prometheus config

Edit `prometheus/prometheus.yml` or any rules file, then:

```bash
make reload-prometheus
```

No container restart required.

---

## Alert Rules Summary

### Node Alerts (`prometheus/rules/node-alerts.yml`)

| Alert | Threshold | Severity |
|---|---|---|
| NodeHighCPULoad | CPU > 80% for 5m | warning |
| NodeCriticalCPULoad | CPU > 95% for 2m | critical |
| NodeHighMemoryUsage | Memory > 85% for 5m | warning |
| NodeCriticalMemoryUsage | Memory > 95% for 2m | critical |
| NodeDiskUsageWarning | Disk > 75% for 10m | warning |
| NodeDiskUsageCritical | Disk > 90% for 5m | critical |
| NodeDiskWillFillIn4Hours | predict_linear < 0 | warning |
| NodeHighDiskIOUtilization | I/O > 90% for 10m | warning |
| NodeDown | up == 0 for 1m | critical |

### Application Alerts (`prometheus/rules/app-alerts.yml`)

| Alert | Threshold | Severity |
|---|---|---|
| ServiceDown | up == 0 for 1m | critical |
| HighHTTPErrorRate | 5xx > 5% for 2m | warning |
| CriticalHTTPErrorRate | 5xx > 25% for 1m | critical |
| HighP95Latency | P95 > 500ms for 5m | warning |
| CriticalP99Latency | P99 > 2s for 3m | critical |
| ContainerHighCPUUsage | Container CPU > 80% for 5m | warning |
| ContainerHighMemoryUsage | Memory > 85% of limit | warning |

---

## Alertmanager Routing

```
All alerts
  └── Watchdog -> null (suppressed)
  └── severity: critical -> pagerduty-critical (1m repeat) + slack-critical
  └── severity: warning  -> slack-warning (6h repeat)
  └── default            -> slack-info
```

Inhibition rules suppress warning alerts when a matching critical alert is already firing.

---

## Teardown

```bash
make down       # Stop containers, keep data
make destroy    # Stop containers, delete all volumes
```

---

## Service URLs

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | admin / observability |
| Prometheus | http://localhost:9090 | none |
| Alertmanager | http://localhost:9093 | none |
| Loki | http://localhost:3100 | none |
| Node Exporter | http://localhost:9100/metrics | none |
| cAdvisor | http://localhost:8081 | none |
| Demo App | http://localhost:8082 | none |

---

## Screenshots to Capture for GitHub README

1. Grafana Node Overview dashboard — CPU gauge, memory breakdown, disk bar chart
   (http://localhost:3000/d/node-overview — after 5 minutes of uptime)

2. Grafana Application Overview dashboard — showing request rate stat, error rate stat, P95/P99 gauges, and latency timeseries
   (run `make load-test` first, then screenshot http://localhost:3000/d/app-overview)

3. Grafana Container Metrics dashboard — multi-container CPU lines all visible
   (http://localhost:3000/d/container-metrics)

4. Prometheus Alerts page — showing multiple alert rules in green/pending/firing state
   (http://localhost:9090/alerts)

5. Prometheus Targets page — all 6 targets in UP state
   (http://localhost:9090/targets)

6. Grafana Logs Explorer dashboard — showing structured JSON log entries with labels visible
   (http://localhost:3000/d/logs-explorer — filter to "demo-app")

7. Alertmanager routing UI — http://localhost:9093 showing the routing tree

---

## GitHub Repo Name

`production-observability-stack`
