"""
services/notifications/app.py
Mock SES email + SMS notification service.
Owner: Member 5

Replaces AWS SES (limited in LocalStack free tier).
In local dev, emails and SMS are logged to console / stored in memory.
"""

import os
import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

LOG_EMAILS = os.getenv("LOG_EMAILS", "true").lower() == "true"

# In-memory log of sent notifications (useful for integration tests to assert)
_sent_notifications: list = []


def _log_notification(notification: dict) -> None:
    notification["sent_at"] = datetime.datetime.utcnow().isoformat()
    _sent_notifications.append(notification)
    if LOG_EMAILS:
        print(f"\n{'='*60}")
        print(f"[mock-notifications] {notification['type'].upper()}")
        print(f"  To:      {notification.get('to')}")
        print(f"  Subject: {notification.get('subject', 'N/A')}")
        print(f"  Body:    {notification.get('body', '')[:200]}")
        print(f"{'='*60}\n")


# ── POST /send-email ──────────────────────────
@app.route("/send-email", methods=["POST"])
def send_email():
    data = request.get_json()
    required = ["to", "subject", "body"]
    if not all(k in data for k in required):
        return jsonify({"error": f"Required fields: {required}"}), 400

    notification = {
        "type": "email",
        "to": data["to"],
        "subject": data["subject"],
        "body": data["body"],
        "from": data.get("from", "noreply@neobank-sg.local"),
    }
    _log_notification(notification)
    return jsonify({"message_id": f"mock-email-{len(_sent_notifications)}", "status": "sent"}), 200


# ── POST /send-sms ────────────────────────────
@app.route("/send-sms", methods=["POST"])
def send_sms():
    data = request.get_json()
    if "phone_number" not in data or "message" not in data:
        return jsonify({"error": "phone_number and message are required"}), 400

    notification = {
        "type": "sms",
        "to": data["phone_number"],
        "body": data["message"],
    }
    _log_notification(notification)
    return jsonify({"message_id": f"mock-sms-{len(_sent_notifications)}", "status": "sent"}), 200


# ── POST /send-otp ────────────────────────────
@app.route("/send-otp", methods=["POST"])
def send_otp():
    """Generate and send a 6-digit OTP via SMS."""
    import random
    data = request.get_json()
    phone_number = data.get("phone_number")
    if not phone_number:
        return jsonify({"error": "phone_number is required"}), 400

    otp = str(random.randint(100000, 999999))
    notification = {
        "type": "sms",
        "to": phone_number,
        "body": f"Your NeoBank SG OTP is: {otp}. Valid for 5 minutes. Do not share this with anyone.",
        "otp": otp,   # Returned in local dev for easy testing
    }
    _log_notification(notification)

    return jsonify({
        "message_id": f"mock-otp-{len(_sent_notifications)}",
        "status": "sent",
        "otp": otp,   # Only exposed in local/mock mode — never in real SES
    }), 200


# ── GET /notifications ────────────────────────
@app.route("/notifications", methods=["GET"])
def list_notifications():
    """Test helper: see all notifications sent so far."""
    limit = int(request.args.get("limit", 20))
    return jsonify({
        "total": len(_sent_notifications),
        "notifications": _sent_notifications[-limit:]
    }), 200


# ── DELETE /notifications ─────────────────────
@app.route("/notifications", methods=["DELETE"])
def clear_notifications():
    """Test helper: reset notification log between tests."""
    _sent_notifications.clear()
    return jsonify({"message": "Notification log cleared"}), 200


# ── GET /health ───────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "mock-notifications", "sent": len(_sent_notifications)}), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5002))
    print(f"[mock-notifications] Starting on port {port}")
    app.run(host="0.0.0.0", port=port, debug=True)
