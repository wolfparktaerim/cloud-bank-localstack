/**
 * Cloud Bank — k6 API Gateway vs ALB Comparison
 *
 * Runs identical transaction workloads against both ingress points
 * simultaneously using k6 scenarios, then prints a side-by-side
 * latency comparison in the summary.
 *
 * Usage:
 *   k6 run \
 *     --env API_BASE=$(terraform output -raw api_base_url) \
 *     --env ALB_BASE=$(terraform output -raw alb_base_url) \
 *     load-test/k6-compare.js
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

// ── Endpoints ──────────────────────────────────────────────────────────────────
const API_BASE = __ENV.API_BASE || 'http://localhost:4566/_aws/execute-api/placeholder/prod';
const ALB_BASE = __ENV.ALB_BASE || 'http://bank-alb.elb.localhost.localstack.cloud:4566';

// ── Per-endpoint custom metrics ────────────────────────────────────────────────
const apigwLatency = new Trend('apigw_duration', true);
const albLatency   = new Trend('alb_duration',   true);
const apigwErrors  = new Rate('apigw_errors');
const albErrors    = new Rate('alb_errors');

// ── Scenarios: two executor groups running the same work on different targets ──
export const options = {
  scenarios: {
    api_gateway: {
      executor:         'ramping-vus',
      startVUs:         0,
      stages: [
        { duration: '20s', target: 5  },
        { duration: '1m',  target: 10 },
        { duration: '20s', target: 0  },
      ],
      gracefulRampDown: '10s',
      exec:             'apiGatewayScenario',
      tags:             { ingress: 'api-gateway' },
    },
    alb: {
      executor:         'ramping-vus',
      startVUs:         0,
      stages: [
        { duration: '20s', target: 5  },
        { duration: '1m',  target: 10 },
        { duration: '20s', target: 0  },
      ],
      gracefulRampDown: '10s',
      exec:             'albScenario',
      tags:             { ingress: 'alb' },
    },
  },
  thresholds: {
    apigw_duration: ['p(95)<3000'],
    alb_duration:   ['p(95)<3000'],
    apigw_errors:   ['rate<0.10'],
    alb_errors:     ['rate<0.10'],
  },
};

// ── Shared workload ────────────────────────────────────────────────────────────
const HEADERS = { 'Content-Type': 'application/json' };

function runWorkload(baseUrl, latencyMetric, errorMetric, tag) {
  const uid       = `${tag}_vu${__VU}_i${__ITER}`;
  const accountId = `CMP_${uid.toUpperCase()}`;

  function post(path, body) {
    return http.post(
      `${baseUrl}/${path}`,
      JSON.stringify(body),
      { headers: HEADERS, tags: { endpoint: path, ingress: tag } }
    );
  }

  function track(res, label) {
    latencyMetric.add(res.timings.duration);
    const passed = res.status === 200;
    errorMetric.add(passed ? 0 : 1);
    check(res, { [`[${tag}] ${label} 200`]: r => r.status === 200 });
    return passed;
  }

  group(`deposit_flow_${tag}`, () => {
    let res;

    res = post('accounts', { action: 'create_account', account_id: accountId, owner_name: 'Compare User', account_type: 'SAVINGS' });
    track(res, 'create_account');

    res = post('transactions', { action: 'deposit', account_id: accountId, amount: 500 });
    track(res, 'deposit');

    res = post('transactions', { action: 'balance', account_id: accountId });
    track(res, 'balance');

    res = post('transactions', { action: 'withdraw', account_id: accountId, amount: 50 });
    track(res, 'withdraw');
  });

  sleep(1);
}

// ── Scenario functions ─────────────────────────────────────────────────────────
export function apiGatewayScenario() {
  runWorkload(API_BASE, apigwLatency, apigwErrors, 'apigw');
}

export function albScenario() {
  runWorkload(ALB_BASE, albLatency, albErrors, 'alb');
}

// ── Summary ────────────────────────────────────────────────────────────────────
export function handleSummary(data) {
  function val(metric, stat) {
    const m = data.metrics[metric];
    if (!m) return 'n/a     ';
    const v = m.values[stat];
    return v !== undefined ? `${v.toFixed(0)}ms`.padEnd(8) : 'n/a     ';
  }
  function errRate(metric) {
    const m = data.metrics[metric];
    if (!m) return 'n/a  ';
    return `${(m.values.rate * 100).toFixed(1)}%`.padEnd(5);
  }

  const report = `
╔══════════════════════════════════════════════════════════════════╗
║         CLOUD BANK — API GATEWAY vs ALB COMPARISON              ║
╠══════════════════════════════════════════════════════════════════╣
║                    API Gateway          ALB                      ║
╠══════════════════════════════════════════════════════════════════╣
║  p50 latency    ${val('apigw_duration','p(50)')}             ${val('alb_duration','p(50)')}         ║
║  p90 latency    ${val('apigw_duration','p(90)')}             ${val('alb_duration','p(90)')}         ║
║  p95 latency    ${val('apigw_duration','p(95)')}             ${val('alb_duration','p(95)')}         ║
║  p99 latency    ${val('apigw_duration','p(99)')}             ${val('alb_duration','p(99)')}         ║
║  min latency    ${val('apigw_duration','min')}             ${val('alb_duration','min')}         ║
║  max latency    ${val('apigw_duration','max')}             ${val('alb_duration','max')}         ║
╠══════════════════════════════════════════════════════════════════╣
║  error rate     ${errRate('apigw_errors')}                ${errRate('alb_errors')}              ║
╠══════════════════════════════════════════════════════════════════╣
║  API GW  : ${API_BASE.padEnd(55)}║
║  ALB     : ${ALB_BASE.padEnd(55)}║
╚══════════════════════════════════════════════════════════════════╝

Note: Both endpoints call identical Lambda functions. Differences in
latency reflect ingress overhead only (API Gateway processing vs ALB
path-based routing). In LocalStack, differences may be minimal.
`;

  console.log(report);

  return {
    'load-test/compare-summary.txt': report,
    stdout: report,
  };
}
