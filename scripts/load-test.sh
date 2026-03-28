#!/usr/bin/env bash
# ============================================================
# load-test.sh
#
# Generates HTTP traffic against the demo app to trigger
# Prometheus alerts and populate Grafana dashboards.
# Requires: curl (installed by default on macOS and most Linux)
# ============================================================

set -euo pipefail

APP_URL="${APP_URL:-http://localhost:8082}"
DURATION_SECONDS="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-5}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }

ENDPOINTS=(
  "$APP_URL/"
  "$APP_URL/api/v1/data"
  "$APP_URL/api/v1/slow"
  "$APP_URL/api/v1/error"
  "$APP_URL/health/ready"
)

send_requests() {
  local worker_id="$1"
  local end_time=$((SECONDS + DURATION_SECONDS))

  while [[ $SECONDS -lt $end_time ]]; do
    local endpoint="${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}"
    curl -s -o /dev/null -w "" "${endpoint}" || true
    sleep "$(echo "scale=2; $RANDOM / 32767 * 2" | bc)"
  done

  echo "Worker ${worker_id} done."
}

main() {
  echo ""
  echo "============================================================"
  echo "  Observability Stack — Load Generator"
  echo "============================================================"
  echo ""
  log_info "Target:       ${APP_URL}"
  log_info "Duration:     ${DURATION_SECONDS}s"
  log_info "Concurrency:  ${CONCURRENCY} workers"
  echo ""

  # Check app is reachable
  if ! curl -sf "${APP_URL}/health/ready" &>/dev/null; then
    log_info "Demo app not yet available at ${APP_URL}. Waiting..."
    until curl -sf "${APP_URL}/health/ready" &>/dev/null; do
      sleep 2
    done
  fi
  log_success "Demo app is reachable."

  log_info "Starting ${CONCURRENCY} background workers for ${DURATION_SECONDS}s..."

  # Launch workers in background
  for i in $(seq 1 "$CONCURRENCY"); do
    send_requests "$i" &
  done

  # Wait for all workers
  wait

  echo ""
  log_success "Load test complete."
  echo ""
  echo "Open Grafana to see the results:"
  echo "  http://localhost:3000"
  echo "  Login: admin / observability"
  echo "  Dashboard: Application Overview"
  echo ""
}

main "$@"
