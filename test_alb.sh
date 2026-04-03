#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Cloud Bank — ALB Load Test Script
# 1. Quick smoke test (curl) to confirm the ALB is up
# 2. k6 full user journey against the ALB
# 3. k6 API Gateway vs ALB side-by-side comparison
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# ── Resolve URLs ─────────────────────────────────────────────────────────────
ALB=$(grep 'albBase:' config.js | awk -F'"' '{print $2}')
API=$(grep 'apiBase:' config.js | awk -F'"' '{print $2}')

if [ -z "$ALB" ]; then
  echo "❌  Could not read albBase from config.js — run ./reset.sh first"
  exit 1
fi

echo "════════════════════════════════════════════════════════════════"
echo "  Cloud Bank — ALB Load Test"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  ALB : $ALB"
echo "  API : $API"
echo ""

# ── Check k6 is installed ───────────────────────────────────────────────────
if ! command -v k6 &>/dev/null; then
  echo "❌  k6 is not installed."
  echo "   Install with:  brew install k6"
  exit 1
fi

# ── Phase 1: Smoke test — make sure ALB routes are alive ────────────────────
echo "── Phase 1: Smoke test (curl) ───────────────────────────────────"

SMOKE_PASS=0
SMOKE_FAIL=0

smoke() {
  local path=$1 label=$2
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ALB/$path" \
    -H "Content-Type: application/json" \
    -d "$3")
  if [ "$code" -ge 200 ] && [ "$code" -lt 500 ]; then
    echo "  ✅  $label  (HTTP $code)"
    SMOKE_PASS=$((SMOKE_PASS + 1))
  else
    echo "  ❌  $label  (HTTP $code)"
    SMOKE_FAIL=$((SMOKE_FAIL + 1))
  fi
}

SMOKE_UID="alb_smoke_$$_$(date +%s)"
smoke "auth"          "POST /auth"          "{\"action\":\"register\",\"username\":\"$SMOKE_UID\",\"email\":\"${SMOKE_UID}@test.com\",\"password\":\"MyP@ssword123!\"}"
SMOKE_ACC="SMOKE-ALB-$$"
smoke "accounts"      "POST /accounts"      "{\"action\":\"create_account\",\"account_id\":\"$SMOKE_ACC\",\"owner_name\":\"Smoke\",\"account_type\":\"SAVINGS\"}"
smoke "transactions"  "POST /transactions"  "{\"action\":\"deposit\",\"account_id\":\"$SMOKE_ACC\",\"amount\":100}"
smoke "kyc"           "POST /kyc"           "{\"action\":\"status\",\"account_id\":\"$SMOKE_ACC\"}"
smoke "notifications" "POST /notifications" "{\"action\":\"list\",\"account_id\":\"$SMOKE_ACC\"}"
smoke "dlq"           "POST /dlq"           '{"action":"stats"}'

# Verify default 404
DEFAULT_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB/unknown")
if [ "$DEFAULT_CODE" = "404" ]; then
  echo "  ✅  GET /unknown → 404"
  SMOKE_PASS=$((SMOKE_PASS + 1))
else
  echo "  ❌  GET /unknown → expected 404, got $DEFAULT_CODE"
  SMOKE_FAIL=$((SMOKE_FAIL + 1))
fi

echo ""
echo "  Smoke: $SMOKE_PASS passed, $SMOKE_FAIL failed"
echo ""

if [ "$SMOKE_FAIL" -gt 0 ]; then
  echo "❌  Smoke tests failed — skipping load test"
  exit 1
fi

# ── Phase 2: k6 full user journey against the ALB ──────────────────────────
echo "── Phase 2: k6 load test — full user journey against ALB ────────"
echo ""
echo "  Profile: ramp 0→5 VUs (20s) → hold 10 VUs (1m) → spike 20 VUs (20s) → ramp down"
echo "  Thresholds: p95 < 3s, error rate < 10%"
echo ""

k6 run --env API_BASE="$ALB" load-test/k6.js || echo "  ⚠️  k6 thresholds breached (see above) — continuing to Phase 3"

echo ""

# ── Phase 3: k6 API Gateway vs ALB comparison ──────────────────────────────
echo "── Phase 3: k6 API Gateway vs ALB comparison ────────────────────"
echo ""

k6 run \
  --env API_BASE="$API" \
  --env ALB_BASE="$ALB" \
  load-test/k6-compare.js

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅  ALB load test complete"
echo "════════════════════════════════════════════════════════════════"