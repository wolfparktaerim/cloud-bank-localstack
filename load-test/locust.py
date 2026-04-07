"""
Cloud Bank — Locust Load Test
Python alternative to the k6 scripts.

Install:
    pip install locust

Run (API Gateway):
    API_BASE=$(terraform output -raw api_base_url) \
    locust -f load-test/locust.py --headless \
           --users 10 --spawn-rate 2 --run-time 2m \
           --host $API_BASE

Run with the web UI (open http://localhost:8089):
    locust -f load-test/locust.py --host $(terraform output -raw api_base_url)

Run against the ALB:
    locust -f load-test/locust.py --host $(terraform output -raw alb_base_url)
"""

import json
import random
import string
import time
from locust import HttpUser, task, between, events


# ── Helper ─────────────────────────────────────────────────────────────────────

def uid():
    """Generate a short random suffix so VUs don't share account IDs."""
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))


def post(client, path, body, label=None):
    return client.post(
        f'/{path}',
        data=json.dumps(body),
        headers={'Content-Type': 'application/json'},
        name=label or f'/{path}',
        catch_response=True,
    )


# ── Users ──────────────────────────────────────────────────────────────────────

class BankUser(HttpUser):
    """
    Simulates a full user journey:
      register → login → create accounts → transact → kyc → notify → dlq stats
    Each simulated user runs these tasks in a weighted random order after
    completing their initial setup.
    """

    wait_time = between(0.5, 2)

    def on_start(self):
        """Called once per VU when it starts — register and create accounts."""
        suffix        = uid()
        self.username = f'user_{suffix}'
        self.email    = f'{self.username}@loadtest.com'
        self.password = 'LoadTest@123!'
        self.acct1    = f'ACC_{suffix.upper()}_A'
        self.acct2    = f'ACC_{suffix.upper()}_B'
        self.kyc_id   = None

        self._register()
        self._login()
        self._create_accounts()
        self._seed_balance()

    # ── Setup steps (not tasks — run once on_start) ────────────────────────────

    def _register(self):
        with post(self.client, 'auth',
                  {'action': 'register', 'username': self.username,
                   'email': self.email, 'password': self.password},
                  '/auth [register]') as res:
            if res.status_code != 200:
                res.failure(f'Register failed: {res.status_code} {res.text}')
            else:
                res.success()

    def _login(self):
        with post(self.client, 'auth',
                  {'action': 'login', 'username': self.username,
                   'password': self.password},
                  '/auth [login]') as res:
            if res.status_code != 200:
                res.failure(f'Login failed: {res.status_code}')
            else:
                res.success()

    def _create_accounts(self):
        for acct, name, kind in [
            (self.acct1, 'User A', 'SAVINGS'),
            (self.acct2, 'User B', 'CHECKING'),
        ]:
            with post(self.client, 'accounts',
                      {'action': 'create_account', 'account_id': acct,
                       'owner_name': name, 'account_type': kind},
                      '/accounts [create]') as res:
                if res.status_code != 200:
                    res.failure(f'Create account failed: {res.status_code}')
                else:
                    res.success()

    def _seed_balance(self):
        """Deposit initial funds so withdrawals and transfers can succeed."""
        for acct in (self.acct1, self.acct2):
            with post(self.client, 'transactions',
                      {'action': 'deposit', 'account_id': acct, 'amount': 10000},
                      '/transactions [seed_deposit]') as res:
                if res.status_code != 200:
                    res.failure(f'Seed deposit failed: {res.status_code}')
                else:
                    res.success()

    # ── Tasks (run repeatedly, weighted) ──────────────────────────────────────

    @task(3)
    def deposit(self):
        amount = random.randint(10, 500)
        with post(self.client, 'transactions',
                  {'action': 'deposit', 'account_id': self.acct1, 'amount': amount},
                  '/transactions [deposit]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'Deposit failed: {res.status_code}')

    @task(3)
    def check_balance(self):
        with post(self.client, 'transactions',
                  {'action': 'balance', 'account_id': self.acct1},
                  '/transactions [balance]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'Balance check failed: {res.status_code}')

    @task(2)
    def withdraw(self):
        amount = random.randint(1, 50)
        with post(self.client, 'transactions',
                  {'action': 'withdraw', 'account_id': self.acct1, 'amount': amount},
                  '/transactions [withdraw]') as res:
            # Insufficient funds (400 or body error) is an expected application
            # response, not an infrastructure failure — mark success either way
            if res.status_code in (200, 400):
                res.success()
            else:
                res.failure(f'Withdraw failed: {res.status_code}')

    @task(2)
    def transfer(self):
        amount = random.randint(1, 50)
        with post(self.client, 'transactions',
                  {'action': 'transfer', 'account_id': self.acct1,
                   'amount': amount, 'transfer_to': self.acct2},
                  '/transactions [transfer]') as res:
            if res.status_code in (200, 400):
                res.success()
            else:
                res.failure(f'Transfer failed: {res.status_code}')

    @task(1)
    def get_account(self):
        with post(self.client, 'accounts',
                  {'action': 'get_account', 'account_id': self.acct1},
                  '/accounts [get]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'Get account failed: {res.status_code}')

    @task(1)
    def list_accounts(self):
        with post(self.client, 'accounts',
                  {'action': 'list_accounts'},
                  '/accounts [list]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'List accounts failed: {res.status_code}')

    @task(1)
    def submit_kyc(self):
        with post(self.client, 'kyc',
                  {'action': 'submit_kyc', 'user_id': self.acct1,
                   'full_name': 'Load User', 'id_type': 'PASSPORT',
                   'id_number': f'P{uid()}'},
                  '/kyc [submit]') as res:
            if res.status_code == 200:
                try:
                    self.kyc_id = res.json().get('kyc_id')
                except Exception:
                    pass
                res.success()
            else:
                res.failure(f'KYC submit failed: {res.status_code}')

    @task(1)
    def check_kyc_status(self):
        with post(self.client, 'kyc',
                  {'action': 'check_status', 'user_id': self.acct1},
                  '/kyc [status]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'KYC status failed: {res.status_code}')

    @task(1)
    def send_alert(self):
        with post(self.client, 'notifications',
                  {'action': 'send_alert', 'subject': 'Load test',
                   'message': f'Alert from VU at {time.time():.0f}'},
                  '/notifications [alert]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'Alert failed: {res.status_code}')

    @task(1)
    def dlq_stats(self):
        with post(self.client, 'dlq',
                  {'action': 'stats'},
                  '/dlq [stats]') as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure(f'DLQ stats failed: {res.status_code}')


# ── Event hooks ────────────────────────────────────────────────────────────────

@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    print(f'\n  Target: {environment.host}')
    print('  Cloud Bank load test starting…\n')

@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    stats = environment.stats.total
    print(f'\n  Requests : {stats.num_requests}')
    print(f'  Failures : {stats.num_failures}')
    print(f'  Fail rate: {stats.fail_ratio * 100:.1f}%')
    print(f'  p50      : {stats.get_response_time_percentile(0.5):.0f}ms')
    print(f'  p95      : {stats.get_response_time_percentile(0.95):.0f}ms')
    print(f'  p99      : {stats.get_response_time_percentile(0.99):.0f}ms\n')
