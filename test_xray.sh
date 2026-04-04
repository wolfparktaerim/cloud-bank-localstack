#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  X-Ray Tracing Test — triggers all 6 Lambdas, then queries & displays traces
# ══════════════════════════════════════════════════════════════════════════════

set -e

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

API_BASE=$(grep 'apiBase:' config.js | awk -F'"' '{print $2}')
if [ -z "$API_BASE" ]; then
  echo "ERROR: Could not read apiBase from config.js — run ./reset.sh first"
  exit 1
fi

UID_TAG="xray_$(date +%s)"

echo "════════════════════════════════════════════════════════════════"
echo "  X-Ray Tracing Test"
echo "════════════════════════════════════════════════════════════════"
echo "  API: $API_BASE"
echo ""

# ── Get initial trace count ─────────────────────────────────────────────────
START_TIME=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

INITIAL_COUNT=$(aws --endpoint-url=http://localhost:4566 --output json \
  xray get-trace-summaries \
  --region ap-southeast-1 \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('TracesProcessedCount',0))" 2>/dev/null || echo "0")

echo "  Initial trace count: $INITIAL_COUNT"
echo ""

# ── Phase 1: Fire requests to all 6 Lambdas ─────────────────────────────────
echo "Phase 1 — Triggering all 6 Lambda functions"
echo "────────────────────────────────────────────────────────────────"

echo -n "  1/6  auth (register)       ... "
R=$(curl -s -m 60 -X POST "$API_BASE/auth" \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"register\",\"username\":\"$UID_TAG\",\"password\":\"MyP@ssword123!\",\"email\":\"$UID_TAG@test.com\"}")
echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','?')))" 2>/dev/null || echo "$R"

echo -n "  2/6  accounts (create)     ... "
R=$(curl -s -m 60 -X POST "$API_BASE/accounts" \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"create_account\",\"account_id\":\"ACC_$UID_TAG\",\"owner_name\":\"XRay Test\",\"account_type\":\"SAVINGS\"}")
echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','?')))" 2>/dev/null || echo "$R"

echo -n "  3/6  transactions (deposit)... "
R=$(curl -s -m 60 -X POST "$API_BASE/transactions" \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"deposit\",\"account_id\":\"ACC_$UID_TAG\",\"amount\":250}")
echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','?')))" 2>/dev/null || echo "$R"

echo -n "  4/6  kyc (submit)          ... "
R=$(curl -s -m 60 -X POST "$API_BASE/kyc" \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"submit_kyc\",\"user_id\":\"ACC_$UID_TAG\",\"full_name\":\"XRay User\",\"id_type\":\"PASSPORT\",\"id_number\":\"P999\"}")
echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','?')))" 2>/dev/null || echo "$R"

echo -n "  5/6  notifications (alert) ... "
R=$(curl -s -m 60 -X POST "$API_BASE/notifications" \
  -H 'Content-Type: application/json' \
  -d '{"action":"send_alert","subject":"XRay Test","message":"Trace test"}')
echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','?')))" 2>/dev/null || echo "$R"

echo -n "  6/6  dlq (stats)           ... "
R=$(curl -s -m 60 -X POST "$API_BASE/dlq" \
  -H 'Content-Type: application/json' \
  -d '{"action":"stats"}')
echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print('messages=' + str(d.get('messages','?')))" 2>/dev/null || echo "$R"

echo ""

# ── Phase 2: Wait for traces ────────────────────────────────────────────────
WAIT=10
echo "Phase 2 — Waiting ${WAIT}s for X-Ray to collect traces"
echo "────────────────────────────────────────────────────────────────"
for i in $(seq $WAIT -1 1); do
  printf "\r  %02d seconds remaining..." $i
  sleep 1
done
printf "\r  Done.                    \n\n"

# ── Phase 3: Query trace summaries ──────────────────────────────────────────
echo "Phase 3 — X-Ray Trace Summaries"
echo "────────────────────────────────────────────────────────────────"

END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

SUMMARIES=$(aws --endpoint-url=http://localhost:4566 --output json \
  xray get-trace-summaries \
  --region ap-southeast-1 \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" 2>&1)

TRACE_COUNT=$(echo "$SUMMARIES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('TracesProcessedCount',0))" 2>/dev/null || echo "0")
NEW_TRACES=$((TRACE_COUNT - INITIAL_COUNT))

echo "  Traces found: $TRACE_COUNT (${NEW_TRACES} new since test started)"
echo ""

if [ "$NEW_TRACES" -gt 0 ]; then
  echo "  ✓ X-Ray is recording traces correctly"
else
  echo "  ⚠ No new traces recorded"
fi
echo ""

if [ "$TRACE_COUNT" -eq 0 ]; then
  echo "  ⚠ No traces found. Possible reasons:"
  echo "    - Lambdas have not been invoked yet"
  echo "    - tracing_config { mode = \"Active\" } not set in main.tf"
  echo "    - IAM roles missing AWSXRayDaemonWriteAccess"
  exit 1
fi

# Print summary table
echo "$SUMMARIES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
traces = data.get('TraceSummaries', [])
print(f'  {'ID':<52} {'Duration':>8}  {'Error':>5}  {'Fault':>5}')
print(f'  {\"─\"*52} {\"─\"*8}  {\"─\"*5}  {\"─\"*5}')
for t in traces:
    tid = t['Id']
    dur = f\"{t['Duration']:.1f}s\" if t['Duration'] > 0 else '< 1s'
    err = '✗' if t.get('HasError') else '✓'
    flt = '✗' if t.get('HasFault') else '✓'
    print(f'  {tid:<52} {dur:>8}  {err:>5}  {flt:>5}')
print()
"

# ── Phase 4: Get full detail for the most recent trace ──────────────────────
echo "Phase 4 — Detailed trace (most recent)"
echo "────────────────────────────────────────────────────────────────"

LATEST_ID=$(echo "$SUMMARIES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
traces = data.get('TraceSummaries', [])
if traces:
    print(traces[-1]['Id'])
" 2>/dev/null)

if [ -z "$LATEST_ID" ]; then
  echo "  Could not extract a trace ID."
  exit 1
fi

echo "  Trace ID: $LATEST_ID"
echo ""

DETAIL=$(aws --endpoint-url=http://localhost:4566 --output json \
  xray batch-get-traces \
  --trace-ids "$LATEST_ID" \
  --region ap-southeast-1 2>&1)

echo "$DETAIL" | python3 -c "
import sys, json

data = json.load(sys.stdin)
for trace in data.get('Traces', []):
    print(f'  Trace: {trace[\"Id\"]}  (duration: {trace[\"Duration\"]}s)')
    print()
    for seg in trace.get('Segments', []):
        doc = json.loads(seg['Document'])
        name     = doc.get('name', '?')
        seg_type = doc.get('type', 'segment')
        ns       = doc.get('namespace', '')
        start    = doc.get('start_time', 0)
        end      = doc.get('end_time', 0)
        elapsed  = (end - start) * 1000

        # AWS subsegment details
        aws_info = doc.get('aws', {})
        http_info = doc.get('http', {})
        op = aws_info.get('operation', '')
        status = http_info.get('response', {}).get('status', '')

        indent = '    → ' if seg_type == 'subsegment' else '  '
        detail = ''
        if op:
            detail = f'  [{op}]'
        if status:
            detail += f'  HTTP {status}'

        print(f'{indent}{name:<25} {elapsed:>7.1f}ms  {ns}{detail}')
    print()
"

# ── Phase 5: Service map ────────────────────────────────────────────────────
echo "Phase 5 — Service Graph"
echo "────────────────────────────────────────────────────────────────"

SERVICE_GRAPH=$(aws --endpoint-url=http://localhost:4566 --output json \
  xray get-service-graph \
  --region ap-southeast-1 \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" 2>&1)

echo "$SERVICE_GRAPH" | python3 -c "
import sys, json
data = json.load(sys.stdin)
services = data.get('Services', [])
if not services:
    print('  (service graph empty — this is normal on LocalStack)')
else:
    for svc in services:
        name = svc.get('Name', '?')
        stype = svc.get('Type', '?')
        edges = len(svc.get('Edges', []))
        print(f'  {name} ({stype}) → {edges} downstream connection(s)')
print()
"

# ── Done ─────────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════"
echo "  X-Ray Test Complete"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Quick reference:"
echo "    # List traces"
echo "    aws --endpoint-url=http://localhost:4566 xray get-trace-summaries \\"
echo "      --region ap-southeast-1 \\"
echo "      --start-time \$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \\"
echo "      --end-time \$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "    # Detail for a specific trace"
echo "    aws --endpoint-url=http://localhost:4566 xray batch-get-traces \\"
echo "      --trace-ids \"$LATEST_ID\" --region ap-southeast-1"
echo ""

