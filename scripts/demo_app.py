"""
Demo application — generates realistic HTTP metrics and structured logs
for the observability stack. Runs within Docker Compose.
"""

import os
import time
import random
import json
import logging
import sys
import threading
from datetime import datetime, timezone

from flask import Flask, jsonify, Response, request
from prometheus_client import (
    Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
)

# ---- Structured logging ----
class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname.lower(),
            "message": record.getMessage(),
            "service": "demo-app",
            "version": os.getenv("APP_VERSION", "1.0.0"),
        })

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("demo-app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)

# ---- Metrics ----
REQUEST_COUNT = Counter(
    "http_requests_total", "Total HTTP requests",
    ["method", "endpoint", "status_code"]
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds", "Request latency",
    ["method", "endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)
ACTIVE_REQUESTS = Gauge("http_requests_active", "Active HTTP requests")
ERRORS_TOTAL = Counter("app_errors_total", "Total application errors", ["type"])
APP_INFO = Gauge("app_info", "Application information", ["version", "environment"])

APP_INFO.labels(
    version=os.getenv("APP_VERSION", "1.0.0"),
    environment=os.getenv("ENVIRONMENT", "demo")
).set(1)

# ---- Flask app ----
app = Flask(__name__)

@app.before_request
def before():
    request.start_time = time.time()
    ACTIVE_REQUESTS.inc()

@app.after_request
def after(response):
    ACTIVE_REQUESTS.dec()
    latency = time.time() - getattr(request, "start_time", time.time())
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or "unknown",
        status_code=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=request.endpoint or "unknown"
    ).observe(latency)
    return response

@app.route("/")
def index():
    logger.info("Root endpoint called")
    return jsonify({"service": "demo-app", "status": "ok"})

@app.route("/health/live")
def live():
    return jsonify({"status": "alive"}), 200

@app.route("/health/ready")
def ready():
    return jsonify({"status": "ready"}), 200

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route("/api/v1/data")
def data():
    # Simulate variable latency
    time.sleep(random.uniform(0.01, 0.15))
    logger.info("Data endpoint served")
    return jsonify({"items": [{"id": i, "value": random.random()} for i in range(10)]})

@app.route("/api/v1/slow")
def slow():
    # Simulate occasionally slow endpoint for P99 alerting demo
    delay = random.uniform(0.1, 1.5)
    time.sleep(delay)
    logger.info(f"Slow endpoint served in {delay:.3f}s")
    return jsonify({"latency": delay})

@app.route("/api/v1/error")
def error():
    # Randomly return errors for error rate alerting demo
    if random.random() < 0.3:
        ERRORS_TOTAL.labels(type="server_error").inc()
        logger.error("Simulated server error")
        return jsonify({"error": "internal_server_error"}), 500
    return jsonify({"status": "ok"})

# ---- Background traffic generator ----
def generate_traffic():
    """Continuously generate synthetic traffic for dashboard demonstration."""
    import urllib.request

    endpoints = [
        "http://localhost:8080/",
        "http://localhost:8080/api/v1/data",
        "http://localhost:8080/api/v1/slow",
        "http://localhost:8080/api/v1/error",
        "http://localhost:8080/health/ready",
    ]

    # Wait for app to start
    time.sleep(5)
    logger.info("Background traffic generator started")

    while True:
        try:
            url = random.choice(endpoints)
            urllib.request.urlopen(url, timeout=5)
        except Exception:
            pass
        time.sleep(random.uniform(0.5, 3.0))

if __name__ == "__main__":
    # Start background traffic in a daemon thread
    t = threading.Thread(target=generate_traffic, daemon=True)
    t.start()

    logger.info("Starting demo-app on port 8080")
    app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
