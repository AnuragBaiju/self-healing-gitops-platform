from flask import Flask, jsonify, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import time
import random
import os

app = Flask(__name__)

START_TIME = time.time()

# A counter that tracks every request, labeled by status code.
# This is exactly what our AnalysisTemplate's PromQL query will read.
REQUEST_COUNT = Counter(
    "flask_http_request_total",
    "Total HTTP requests",
    ["status"]
)

# Controls how often the app intentionally fails - lets us SIMULATE
# a bad deployment to prove the self-healing rollback actually works.
# Default 0 = never fail. We'll flip this via an environment variable later.
FAILURE_RATE = float(os.environ.get("FAILURE_RATE", "0"))

@app.route("/healthz")
def healthz():
    return jsonify(status="ok"), 200

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route("/")
def index():
    # Randomly simulate a failure based on FAILURE_RATE
    if random.random() < FAILURE_RATE:
        REQUEST_COUNT.labels(status="500").inc()
        return jsonify(error="simulated failure"), 500

    REQUEST_COUNT.labels(status="200").inc()
    return jsonify(message="Hello from demo-service", uptime=time.time() - START_TIME)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050)# CI pipeline test
