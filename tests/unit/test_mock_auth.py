"""
tests/unit/test_mock_auth.py
Unit tests for the mock authentication service.
Owner: Member 5

Run: pytest tests/unit/ -v
Does NOT require LocalStack running.
"""

import sys
import os
import pytest

# Add services/auth to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../services/auth"))

from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as c:
        yield c


class TestRegister:
    def test_register_success(self, client):
        r = client.post("/register", json={
            "email": "newuser@example.com",
            "password": "SecurePass123!",
            "full_name": "New User",
        })
        assert r.status_code == 201
        data = r.get_json()
        assert "user_id" in data

    def test_register_missing_fields(self, client):
        r = client.post("/register", json={"email": "nopass@example.com"})
        assert r.status_code == 400

    def test_register_duplicate_email(self, client):
        payload = {"email": "dup@example.com", "password": "Pass123!", "full_name": "Dup"}
        client.post("/register", json=payload)
        r = client.post("/register", json=payload)
        assert r.status_code == 409


class TestLogin:
    def setup_method(self):
        """Register a user before each login test."""
        self._email = "logintest@example.com"
        self._password = "LoginTest123!"

    def test_login_success(self, client):
        client.post("/register", json={
            "email": self._email, "password": self._password, "full_name": "Login Test"
        })
        r = client.post("/login", json={"email": self._email, "password": self._password})
        assert r.status_code == 200
        data = r.get_json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "Bearer"

    def test_login_wrong_password(self, client):
        client.post("/register", json={
            "email": self._email, "password": self._password, "full_name": "Login Test"
        })
        r = client.post("/login", json={"email": self._email, "password": "wrongpassword"})
        assert r.status_code == 401

    def test_login_nonexistent_user(self, client):
        r = client.post("/login", json={"email": "ghost@example.com", "password": "whatever"})
        assert r.status_code == 401


class TestVerifyToken:
    def test_verify_valid_token(self, client):
        client.post("/register", json={
            "email": "verify@example.com", "password": "Pass123!", "full_name": "Verify"
        })
        login_r = client.post("/login", json={"email": "verify@example.com", "password": "Pass123!"})
        token = login_r.get_json()["access_token"]

        r = client.post("/verify-token", json={"token": token})
        assert r.status_code == 200
        data = r.get_json()
        assert data["valid"] is True
        assert data["email"] == "verify@example.com"

    def test_verify_invalid_token(self, client):
        r = client.post("/verify-token", json={"token": "this.is.invalid"})
        assert r.status_code == 401
        assert r.get_json()["valid"] is False


class TestHealth:
    def test_health_endpoint(self, client):
        r = client.get("/health")
        assert r.status_code == 200
        assert r.get_json()["status"] == "ok"
