# Mock for Association of Banks Singapore interbank gateway
# Simulates FAST (instant transfer) and GIRO (batch) payment rails
import uuid
from flask import Flask, request, jsonify
import uuid
import random

app = Flask(__name__)
@app.route("/fast/transfer", methods=["POST"])
def fast_transfer():
    # FAST = near real-time interbank transfer (< 30 seconds)
    data = request.get_json()
    # Simulate 95% success, 5% failure (insufficient funds, invalid account)
    if random.random() < 0.95:
        return jsonify({
            "reference_id": str(uuid.uuid4()),
            "status": "ACCEPTED",
            "estimated_completion": "immediate",
            "rails": "FAST"
        }), 202
    return jsonify({"status": "REJECTED", "reason": "INVALID_ACCOUNT"}), 400

@app.route("/fast/status/<reference_id>", methods=["GET"])
def fast_status(reference_id):
    return jsonify({"reference_id": reference_id, "status": "COMPLETED"}), 200

@app.route("/giro/submit", methods=["POST"])
def giro_submit():
    # GIRO = batch processing, settled next business day
    data = request.get_json()
    return jsonify({
        "batch_id": str(uuid.uuid4()),
        "status": "QUEUED",
        "settlement_date": "next_business_day"
    }), 202