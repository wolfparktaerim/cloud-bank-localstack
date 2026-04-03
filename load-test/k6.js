/**
 * Cloud Bank — k6 Load Test
 *
 * Simulates realistic user journeys across all 6 Lambda microservices.
 * Each Virtual User (VU) runs an independent flow so there are no shared
 * account IDs and no race conditions between VUs.
 *
 * Usage:
 *   # Basic run against API Gateway (reads URL from config.js output)
 *   k6 run --env API_BASE=$(terraform output -raw api_base_url) load-test/k6.js
 *
 *   # Run against the ALB instead
 *   k6 run --env API_BASE=$(terraform output -raw alb_base_url) load-test/k6.js
 *
 *   # Crank up the load
 *   k6 run --env API_BASE=$(terraform output -raw api_base_url) \
 *          --vus 20 --duration 2m load-test/k6.js
 *
 *   # Output a JSON summary for further analysis
 *   k6 run --env API_BASE=$(terraform output -raw api_base_url) \
 *          --out json=load-test/results.json load-test/k6.js
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// ── Custom metrics ─────────────────────────────────────────────────────────────
const errorRate      = new Rate('bank_errors');
const authLatency    = new Trend('bank_auth_duration',         true);
const accountLatency = new Trend('bank_accounts_duration',     true);
const txLatency      = new Trend('bank_transactions_duration', true);
const kycLatency     = new Trend('bank_kyc_duration',          true);
const notifLatency   = new Trend('bank_notifications_duration',true);
const dlqLatency     = new Trend('bank_dlq_duration',          true);
const txCount        = new Counter('bank_transactions_total');

// ── Test configuration ─────────────────────────────────────────────────────────
const BASE_URL = __ENV.API_BASE || 'http://localhost:4566/_aws/execute-api/placeholder/prod';

export const options = {
  stages: [
    { duration: '20s', target: 5  },  // ramp up to 5 VUs
    { duration: '1m',  target: 10 },  // hold at 10 VUs
    { duration: '20s', target: 20 },  // spike to 20 VUs
    { duration: '30s', target: 10 },  // settle back
    { duration: '20s', target: 0  },  // ramp down
  ],
  thresholds: {
    // Overall HTTP failure rate must stay below 10%
    http_req_failed:              ['rate<0.10'],
    // 95th percentile response time across all requests
    http_req_duration:            ['p(95)<3000'],
    // Per-service latency thresholds
    bank_auth_duration:           ['p(95)<2000'],
    bank_accounts_duration:       ['p(95)<1500'],
    bank_transactions_duration:   ['p(95)<3000'],
    bank_kyc_duration:            ['p(95)<2000'],
    bank_notifications_duration:  ['p(95)<2000'],
    bank_dlq_duration:            ['p(95)<1500'],
    // Custom error rate (includes application-level errors, not just HTTP errors)
    bank_errors:                  ['rate<0.10'],
  },
};

// ── Helpers ────────────────────────────────────────────────────────────────────
const HEADERS = { 'Content-Type': 'application/json' };

function post(path, body) {
  return http.post(`${BASE_URL}/${path}`, JSON.stringify(body), { headers: HEADERS });
}

function ok(res, label) {
  const passed = res.status >= 200 && res.status < 300;
  if (!passed) errorRate.add(1);
  else         errorRate.add(0);
  check(res, { [`${label} → 2xx`]: r => r.status >= 200 && r.status < 300 });
  return passed;
}

// ── Main scenario ──────────────────────────────────────────────────────────────
export default function () {
  // Unique IDs per VU + iteration so VUs never collide
  const uid       = `vu${__VU}_i${__ITER}`;
  const username  = `user_${uid}`;
  const email     = `${username}@loadtest.com`;
  const password  = 'LoadTest@123!';
  const accountId = `ACC_${uid.toUpperCase()}`;
  const account2  = `ACC2_${uid.toUpperCase()}`;

  // ── 1. Auth ──────────────────────────────────────────────────────────────────
  group('1_auth', () => {
    let res;

    res = post('auth', { action: 'register', username, email, password });
    authLatency.add(res.timings.duration);
    ok(res, 'register');

    res = post('auth', { action: 'login', username, password });
    authLatency.add(res.timings.duration);
authLatency.add(res.timings.duration);
    ok(res, 'login');

    res = post('auth', { action: 'get_user', username });
    authLatency.add(res.timings.duration);
    ok(res, 'get_user');
  });

  sleep(0.5);

  // ── 2. Accounts ──────────────────────────────────────────────────────────────
  group('2_accounts', () => {
    let res;

    res = post('accounts', { action: 'create_account', account_id: accountId,  owner_name: 'Load User A', account_type: 'SAVINGS'  });
    accountLatency.add(res.timings.duration);
    ok(res, 'create_account_1');

    res = post('accounts', { action: 'create_account', account_id: account2, owner_name: 'Load User B', account_type: 'CHECKING' });
    accountLatency.add(res.timings.duration);
    ok(res, 'create_account_2');

    res = post('accounts', { action: 'get_account', account_id: accountId });
    accountLatency.add(res.timings.duration);
    ok(res, 'get_account');

    res = post('accounts', { action: 'list_accounts' });
    accountLatency.add(res.timings.duration);
    ok(res, 'list_accounts');
  });

  sleep(0.5);

  // ── 3. Transactions ───────────────────────────────────────────────────────────
  group('3_transactions', () => {
    let res;

    res = post('transactions', { action: 'deposit', account_id: accountId, amount: 1000 });
    txLatency.add(res.timings.duration);
    txCount.add(1);
    ok(res, 'deposit');

    res = post('transactions', { action: 'balance', account_id: accountId });
    txLatency.add(res.timings.duration);
    ok(res, 'balance_after_deposit');

    res = post('transactions', { action: 'withdraw', account_id: accountId, amount: 200 });
    txLatency.add(res.timings.duration);
    txCount.add(1);
    ok(res, 'withdraw');

    res = post('transactions', { action: 'deposit', account_id: account2, amount: 500 });
    txLatency.add(res.timings.duration);
    txCount.add(1);
    ok(res, 'deposit_account2');

    res = post('transactions', { action: 'transfer', account_id: accountId, amount: 100, to_account_id: account2 });
    txLatency.add(res.timings.duration);
    txCount.add(1);
    ok(res, 'transfer');

    // Intentional failure: overdraft — should return 400, not 5xx
    res = post('transactions', { action: 'withdraw', account_id: accountId, amount: 999999 });
    txLatency.add(res.timings.duration);
    // Don't count as a bank error — 400 is the correct business response
    errorRate.add(res.status >= 500 ? 1 : 0);
    check(res, { 'overdraft handled gracefully': r => r.status === 200 || r.status === 400 });

    res = post('transactions', { action: 'balance', account_id: accountId });
    txLatency.add(res.timings.duration);
    ok(res, 'balance_final');
  });

  sleep(0.5);

  // ── 4. KYC ───────────────────────────────────────────────────────────────────
  group('4_kyc', () => {
    let res;
    let kycId = null;

    res = post('kyc', {
      action:    'submit_kyc',
      user_id:   accountId,
      full_name: 'Load Test User',
      id_type:   'PASSPORT',
      id_number: `P${__VU}${__ITER}`,
    });
    kycLatency.add(res.timings.duration);
    if (ok(res, 'submit_kyc')) {
      try { kycId = JSON.parse(res.body).kyc_id; } catch (_) {}
    }

    res = post('kyc', { action: 'check_status', user_id: accountId });
    kycLatency.add(res.timings.duration);
    ok(res, 'check_status');

    if (kycId) {
      res = post('kyc', { action: 'approve_kyc', kyc_id: kycId });
      kycLatency.add(res.timings.duration);
      ok(res, 'approve_kyc');
    }
  });

  sleep(0.5);

  // ── 5. Notifications ──────────────────────────────────────────────────────────
  group('5_notifications', () => {
    let res;

    res = post('notifications', { action: 'send_alert', subject: `Load test ${uid}`, message: 'Automated load test alert' });
    notifLatency.add(res.timings.duration);
    ok(res, 'send_alert');

    res = post('notifications', { action: 'send_email', to: 'admin@cloudbank.com', subject: `Load test ${uid}`, message: 'Load test email' });
    notifLatency.add(res.timings.duration);
    ok(res, 'send_email');
  });

  sleep(0.5);

  // ── 6. DLQ
  group('6_dlq', () => {
    let res;

    res = post('dlq', { action: 'stats' });
    dlqLatency.add(res.timings.duration);
    ok(res, 'dlq_stats');

    res = post('dlq', { action: 'peek' });
    dlqLatency.add(res.timings.duration);
    ok(res, 'dlq_peek');
  });

  sleep(1);
}

// ── Summary handler ────────────────────────────────────────────────────────────
export function handleSummary(data) {
  const p95 = ms => {
    const v = data.metrics[ms];
    return v ? `${v.values['p(95)'].toFixed(0)}ms` : 'n/a';
  };
  const rate = m => {
    const v = data.metrics[m];
    return v ? `${(v.values.rate * 100).toFixed(1)}%` : 'n/a';
  };
  const count = m => {
    const v = data.metrics[m];
    return v ? v.values.count : 'n/a';
  };

  const report = `
╔══════════════════════════════════════════════════════════════╗
║              CLOUD BANK LOAD TEST — SUMMARY                  ║
╠══════════════════════════════════════════════════════════════╣
║  Target URL : ${BASE_URL.padEnd(46)}║
╠══════════════════════════════════════════════════════════════╣
║  LATENCY (p95)                                               ║
║  auth          ${p95('bank_auth_duration').padEnd(46)}║
║  accounts      ${p95('bank_accounts_duration').padEnd(46)}║
║  transactions  ${p95('bank_transactions_duration').padEnd(46)}║
║  kyc           ${p95('bank_kyc_duration').padEnd(46)}║
║  notifications ${p95('bank_notifications_duration').padEnd(46)}║
║  dlq           ${p95('bank_dlq_duration').padEnd(46)}║
║  overall p95   ${p95('http_req_duration').padEnd(46)}║
╠══════════════════════════════════════════════════════════════╣
║  ERROR RATES                                                 ║
║  HTTP failures    ${rate('http_req_failed').padEnd(43)}║
║  Bank errors      ${rate('bank_errors').padEnd(43)}║
╠══════════════════════════════════════════════════════════════╣
║  THROUGHPUT                                                  ║
║  Transactions processed  ${String(count('bank_transactions_total')).padEnd(36)}║
╚══════════════════════════════════════════════════════════════╝
`;

  console.log(report);

  return {
    'load-test/summary.txt': report,
    stdout: report,
  };
}