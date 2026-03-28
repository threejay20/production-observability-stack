# ============================================================
# Production Observability Stack — Makefile
# ============================================================

COMPOSE_FILE ?= docker-compose.yml
GRAFANA_URL  ?= http://localhost:3000
PROM_URL     ?= http://localhost:9090
LOKI_URL     ?= http://localhost:3100

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# ---- Stack lifecycle ----

.PHONY: up
up: ## Start the full observability stack
	docker compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "Starting services... Allow 30s for all health checks to pass."
	@echo "Then run: make status"

.PHONY: down
down: ## Stop the stack (preserves volumes)
	docker compose -f $(COMPOSE_FILE) down

.PHONY: destroy
destroy: ## Stop the stack and delete all data volumes
	docker compose -f $(COMPOSE_FILE) down -v

.PHONY: restart
restart: ## Restart all services
	docker compose -f $(COMPOSE_FILE) restart

.PHONY: status
status: ## Show running container status
	docker compose -f $(COMPOSE_FILE) ps

.PHONY: logs
logs: ## Tail all container logs
	docker compose -f $(COMPOSE_FILE) logs -f

# ---- Per-service logs ----

.PHONY: logs-prometheus
logs-prometheus: ## Tail Prometheus logs
	docker compose -f $(COMPOSE_FILE) logs -f prometheus

.PHONY: logs-grafana
logs-grafana: ## Tail Grafana logs
	docker compose -f $(COMPOSE_FILE) logs -f grafana

.PHONY: logs-loki
logs-loki: ## Tail Loki logs
	docker compose -f $(COMPOSE_FILE) logs -f loki

.PHONY: logs-alertmanager
logs-alertmanager: ## Tail Alertmanager logs
	docker compose -f $(COMPOSE_FILE) logs -f alertmanager

# ---- Health checks ----

.PHONY: health
health: ## Check health of all observability services
	@echo "Prometheus:" && curl -sf $(PROM_URL)/-/healthy && echo " OK" || echo " FAIL"
	@echo "Alertmanager:" && curl -sf http://localhost:9093/-/healthy && echo " OK" || echo " FAIL"
	@echo "Grafana:" && curl -sf $(GRAFANA_URL)/api/health && echo "" || echo " FAIL"
	@echo "Loki:" && curl -sf $(LOKI_URL)/ready && echo " OK" || echo " FAIL"
	@echo "Node Exporter:" && curl -sf http://localhost:9100/metrics | head -3 || echo " FAIL"

# ---- Prometheus operations ----

.PHONY: reload-prometheus
reload-prometheus: ## Hot-reload Prometheus config without restart
	curl -sf -X POST $(PROM_URL)/-/reload && echo "Prometheus config reloaded"

.PHONY: check-rules
check-rules: ## Validate Prometheus rule files with promtool
	docker compose -f $(COMPOSE_FILE) exec prometheus promtool check rules /etc/prometheus/rules/*.yml

.PHONY: check-config
check-config: ## Validate Prometheus main config
	docker compose -f $(COMPOSE_FILE) exec prometheus promtool check config /etc/prometheus/prometheus.yml

.PHONY: alerts
alerts: ## Show active Prometheus alerts
	curl -s $(PROM_URL)/api/v1/alerts | python3 -m json.tool

.PHONY: targets
targets: ## Show Prometheus scrape target status
	curl -s $(PROM_URL)/api/v1/targets | python3 -m json.tool | head -80

# ---- Load testing ----

.PHONY: load-test
load-test: ## Run the load test generator against the demo app
	chmod +x scripts/load-test.sh
	DURATION=120 CONCURRENCY=5 ./scripts/load-test.sh

.PHONY: load-test-heavy
load-test-heavy: ## Run a heavy load test to trigger alerts
	chmod +x scripts/load-test.sh
	DURATION=300 CONCURRENCY=20 ./scripts/load-test.sh

# ---- Grafana ----

.PHONY: open-grafana
open-grafana: ## Open Grafana in browser (macOS)
	open $(GRAFANA_URL) || xdg-open $(GRAFANA_URL) || echo "Open manually: $(GRAFANA_URL)"

.PHONY: grafana-datasources
grafana-datasources: ## List provisioned Grafana datasources
	curl -s -u admin:observability $(GRAFANA_URL)/api/datasources | python3 -m json.tool

.PHONY: grafana-dashboards
grafana-dashboards: ## List provisioned Grafana dashboards
	curl -s -u admin:observability "$(GRAFANA_URL)/api/search?type=dash-db" | python3 -m json.tool
