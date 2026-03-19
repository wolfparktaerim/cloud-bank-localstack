"""
services/kyc/app.py
Mock KYC (Know Your Customer) verification service.
Owner: Member 5

Replaces AWS Rekognition + custom KYC flow (not in LocalStack free tier).
Simulates: document upload, face match, identity verification.
"""

import os
import uuid
import datetime
import random
from flask import Flask, request, jsonify

app = Flask(__name__)

# In-memory KYC application store
_kyc_applications: dict = {}

KYC_STATUSES = ["pending", "under_review", "approved", "rejected"]


# ── POST /kyc/submit ──────────────────────────
@app.route("/submit", methods=["POST"])
def submit_kyc():
    """
    Accepts KYC submission.
    In real flow: document is uploaded to S3, Rekognition does face match.
    Here: we simulate async processing with random approval.
    """
    data = request.get_json()
    required = ["user_id", "full_name", "nric_number", "date_of_birth"]
    if not all(k in data for k in required):
        return jsonify({"error": f"Required fields: {required}"}), 400

    application_id = str(uuid.uuid4())
    _kyc_applications[application_id] = {
        "application_id": application_id,
        "user_id": data["user_id"],
        "full_name": data["full_name"],
        "nric_number": data["nric_number"],  # Singapore NRIC
        "date_of_birth": data["date_of_birth"],
        "status": "pending",
        "submitted_at": datetime.datetime.utcnow().isoformat(),
        "reviewed_at": None,
        "rejection_reason": None,
    }

    print(f"[mock-kyc] New application {application_id} for user {data['user_id']}")
    return jsonify({"application_id": application_id, "status": "pending"}), 202


# ── GET /kyc/status/<application_id> ─────────
@app.route("/status/<application_id>", methods=["GET"])
def get_kyc_status(application_id: str):
    application = _kyc_applications.get(application_id)
    if not application:
        return jsonify({"error": "Application not found"}), 404

    # Simulate async processing: auto-approve after first status check
    if application["status"] == "pending":
        application["status"] = "under_review"
    elif application["status"] == "under_review":
        # 90% approval rate in local dev
        application["status"] = "approved" if random.random() < 0.9 else "rejected"
        application["reviewed_at"] = datetime.datetime.utcnow().isoformat()
        if application["status"] == "rejected":
            application["rejection_reason"] = "Document quality insufficient"

    return jsonify(application), 200


# ── POST /kyc/verify-document ─────────────────
@app.route("/verify-document", methods=["POST"])
def verify_document():
    """
    Simulates Rekognition document verification.
    In prod: uploads to S3 → triggers Rekognition → returns match score.
    """
    data = request.get_json()
    if "application_id" not in data:
        return jsonify({"error": "application_id is required"}), 400

    # Simulate a face match score
    match_score = round(random.uniform(85.0, 99.9), 2)
    passed = match_score >= 90.0

    return jsonify({
        "application_id": data["application_id"],
        "document_verified": True,
        "face_match_score": match_score,
        "face_match_passed": passed,
        "liveness_check_passed": True,
    }), 200


# ── GET /health ───────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "service": "mock-kyc",
        "total_applications": len(_kyc_applications),
        "approved": sum(1 for a in _kyc_applications.values() if a["status"] == "approved"),
    }), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5003))
    print(f"[mock-kyc] Starting on port {port}")
    app.run(host="0.0.0.0", port=port, debug=True)
