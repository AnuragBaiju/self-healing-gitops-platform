from flask import Flask, jsonify
import time
import random

app = Flask(__name__)

START_TIME = time.time()

# Kubernetes will call this to ask: "are you alive?"
@app.route("/healthz")
def healthz():
    return jsonify(status="ok"), 200

# Prometheus will scrape this to ask: "how are you performing?"
@app.route("/metrics")
def metrics():
    uptime = time.time() - START_TIME
    return f"app_uptime_seconds {uptime}\n", 200

# A "real" endpoint that simulates actual work
@app.route("/")
def index():
    return jsonify(message="Hello from demo-service", uptime=time.time() - START_TIME)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050)