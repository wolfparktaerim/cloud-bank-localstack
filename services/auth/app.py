"""
services/auth/app.py
Mock Cognito authentication service.
Owner: Member 5

Replaces AWS Cognito (not available in LocalStack free tier).
Provides: register, login, token refresh, verify token endpoints.
"""

import os
import uuid
import hashlib
import datetime
from flask import Flask, request, jsonify
import jwt

app = Flask(__name__)

JWT_SECRET = os.getenv("JWT_SECRET", "local-dev-secret-change-in-prod")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRY_MINUTES = 60
REFRESH_TOKEN_EXPIRY_DAYS = 30

# In-memory user store (replace with DynamoDB call in integration tests)
_users: dict = {}
_refresh_tokens: dict = {}


def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def _generate_access_token(user_id: str, email: str) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "iat": datetime.datetime.utcnow(),
        "exp": datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRY_MINUTES),
        "token_use": "access",
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _generate_refresh_token(user_id: str) -> str:
    token = str(uuid.uuid4())
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=REFRESH_TOKEN_EXPIRY_DAYS)
    _refresh_tokens[token] = {"user_id": user_id, "expires_at": expiry}
    return token


# ── POST /register ────────────────────────────
@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    email = data.get("email", "").lower().strip()
    password = data.get("password", "")
    full_name = data.get("full_name", "")

    if not email or not password:
        return jsonify({"error": "email and password are required"}), 400

    if email in _users:
        return jsonify({"error": "User already exists"}), 409

    user_id = str(uuid.uuid4())
    _users[email] = {
        "user_id": user_id,
        "email": email,
        "full_name": full_name,
        "password_hash": _hash_password(password),
        "created_at": datetime.datetime.utcnow().isoformat(),
        "is_verified": False,   # Simulate email verification
    }

    return jsonify({"user_id": user_id, "message": "Registration successful. Please verify your email."}), 201


# ── POST /login ───────────────────────────────
@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    email = data.get("email", "").lower().strip()
    password = data.get("password", "")

    user = _users.get(email)
    if not user or user["password_hash"] != _hash_password(password):
        return jsonify({"error": "Invalid credentials"}), 401

    access_token = _generate_access_token(user["user_id"], email)
    refresh_token = _generate_refresh_token(user["user_id"])

    return jsonify({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer",
        "expires_in": ACCESS_TOKEN_EXPIRY_MINUTES * 60,
        "user_id": user["user_id"],
    }), 200


# ── POST /refresh ─────────────────────────────
@app.route("/refresh", methods=["POST"])
def refresh():
    data = request.get_json()
    refresh_token = data.get("refresh_token", "")

    token_data = _refresh_tokens.get(refresh_token)
    if not token_data:
        return jsonify({"error": "Invalid refresh token"}), 401

    if datetime.datetime.utcnow() > token_data["expires_at"]:
        del _refresh_tokens[refresh_token]
        return jsonify({"error": "Refresh token expired"}), 401

    user_id = token_data["user_id"]
    # Find user by id
    user = next((u for u in _users.values() if u["user_id"] == user_id), None)
    if not user:
        return jsonify({"error": "User not found"}), 404

    new_access_token = _generate_access_token(user_id, user["email"])
    return jsonify({
        "access_token": new_access_token,
        "token_type": "Bearer",
        "expires_in": ACCESS_TOKEN_EXPIRY_MINUTES * 60,
    }), 200


# ── POST /verify-token ────────────────────────
@app.route("/verify-token", methods=["POST"])
def verify_token():
    """Used by other Lambda functions to validate a JWT."""
    data = request.get_json()
    token = data.get("token", "")

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return jsonify({"valid": True, "user_id": payload["sub"], "email": payload["email"]}), 200
    except jwt.ExpiredSignatureError:
        return jsonify({"valid": False, "error": "Token expired"}), 401
    except jwt.InvalidTokenError:
        return jsonify({"valid": False, "error": "Invalid token"}), 401


# ── GET /health ───────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "mock-auth", "users_count": len(_users)}), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5001))
    print(f"[mock-auth] Starting on port {port}")
    app.run(host="0.0.0.0", port=port, debug=True)
