[CmdletBinding()]
param(
  [int]$WaitSeconds = 45,
  [int]$ExtraWaitSeconds = 30,
  [switch]$PurgeDlq
)

$ErrorActionPreference = 'Stop'

function Get-ApiBaseFromConfig {
  param([string]$Path = 'config.js')
  if (-not (Test-Path $Path)) {
    throw "config file not found: $Path (run reset.bat/terraform apply first)"
  }
  $line = Select-String -Path $Path -Pattern 'apiBase:' | Select-Object -First 1
  if (-not $line) { throw "apiBase not found in $Path" }
  $parts = $line.Line -split '"'
  if ($parts.Length -lt 2) { throw "unable to parse apiBase from: $($line.Line)" }
  return $parts[1]
}

function Post-Json {
  param(
    [Parameter(Mandatory=$true)][string]$Uri,
    [Parameter(Mandatory=$true)][string]$Json
  )
  Invoke-RestMethod -Method Post -Uri $Uri -ContentType 'application/json' -Body $Json
}

function Try-UnwrapSnsEnvelope {
  param([object]$BodyObj)

  # For SNS->SQS subscriptions, the SQS message body is an SNS envelope:
  # { Type: "Notification", Message: "{...business json...}", ... }
  if ($null -ne $BodyObj -and $BodyObj.PSObject.Properties.Name -contains 'Message') {
    $msg = $BodyObj.Message
    if ($msg -is [string]) {
      try { return ($msg | ConvertFrom-Json) } catch { return $BodyObj }
    }
    if ($msg -is [hashtable] -or $msg -is [pscustomobject]) {
      return $msg
    }
  }
  return $BodyObj
}

Write-Host "==============================================================="
Write-Host "  DLQ Test - Real Lambda Failure Scenario (PowerShell)"
Write-Host "==============================================================="
Write-Host ""

$apiBase = Get-ApiBaseFromConfig
$apiDlq = "$apiBase/dlq"
Write-Host "API_DLQ: $apiDlq"
Write-Host ""

# Discover SNS topic ARN
$topics = aws --endpoint-url=http://localhost:4566 sns list-topics --region ap-southeast-1 | ConvertFrom-Json
$topicArn = $topics.Topics | ForEach-Object { $_.TopicArn } | Where-Object { $_ -match 'transaction' } | Select-Object -First 1
if (-not $topicArn) {
  throw 'SNS topic containing "transaction" not found. Is terraform apply complete?'
}
Write-Host "SNS Topic: $topicArn"
Write-Host ""

Write-Host "Step 1: Verify DLQ is empty"
Write-Host "---------------------------------------------------------------"
$initialStats = Post-Json -Uri $apiDlq -Json '{"action":"stats"}'
$initialStats | Select-Object queue, messages, in_flight | ConvertTo-Json -Depth 5
Write-Host ""

Write-Host "Step 2: Publish malformed transaction to SNS"
Write-Host "---------------------------------------------------------------"
Write-Host 'Message: {action:deposit, account_id:FAIL_TEST, amount:invalid_number}'
$publish = aws --endpoint-url=http://localhost:4566 sns publish --topic-arn $topicArn --message '{"action":"deposit","account_id":"FAIL_TEST","amount":"invalid_number"}' --region ap-southeast-1 | ConvertFrom-Json
Write-Host "Published MessageId: $($publish.MessageId)"
Write-Host ""
Write-Host "Flow: SNS -> SQS -> Lambda -> Fails on float('invalid_number')"
Write-Host "      -> Retry 1 -> Fails"
Write-Host "      -> Retry 2 -> Fails"
Write-Host "      -> Retry 3 -> Fails"
Write-Host "      -> Moved to DLQ"
Write-Host ""

Write-Host "Step 3: Waiting $WaitSeconds seconds for Lambda to retry..."
Write-Host "---------------------------------------------------------------"
Start-Sleep -Seconds $WaitSeconds
Write-Host ""

Write-Host "Step 4: Check DLQ for failed message"
Write-Host "---------------------------------------------------------------"
$stats = Post-Json -Uri $apiDlq -Json '{"action":"stats"}'
$stats | Select-Object queue, messages, in_flight | ConvertTo-Json -Depth 5

if ([int]$stats.messages -le 0 -and $ExtraWaitSeconds -gt 0) {
  Write-Host "DLQ empty, waiting extra $ExtraWaitSeconds seconds..."
  Start-Sleep -Seconds $ExtraWaitSeconds
  $stats = Post-Json -Uri $apiDlq -Json '{"action":"stats"}'
  $stats | Select-Object queue, messages, in_flight | ConvertTo-Json -Depth 5
}

if ([int]$stats.messages -gt 0) {
  Write-Host ""
  Write-Host "SUCCESS: Message landed in DLQ after failed retries"
  Write-Host ""

  Write-Host "Step 5: View failed message details"
  Write-Host "---------------------------------------------------------------"
  $peek = Post-Json -Uri $apiDlq -Json '{"action":"peek","max_messages":1}'

  if ($peek.messages -and $peek.messages.Count -gt 0) {
    $m = $peek.messages[0]
    $bodyObj = $null
    try { $bodyObj = $m.body | ConvertFrom-Json } catch { }
    $payloadObj = Try-UnwrapSnsEnvelope -BodyObj $bodyObj

    [pscustomobject]@{
      message_id     = $m.message_id
      account_id     = $payloadObj.account_id
      action         = $payloadObj.action
      amount         = $payloadObj.amount
      receive_count  = $m.receive_count
      sent_at        = $m.sent_at
    } | ConvertTo-Json -Depth 5
  } else {
    $peek | ConvertTo-Json -Depth 10
  }

  if ($PurgeDlq) {
    Write-Host ""
    Write-Host "Step 6: Purge DLQ"
    Write-Host "---------------------------------------------------------------"
    Post-Json -Uri $apiDlq -Json '{"action":"purge"}' | ConvertTo-Json -Depth 10
    Write-Host "DLQ purged"
  } else {
    Write-Host ""
    Write-Host "DLQ not purged. You can redrive with:"
    Write-Host "Invoke-RestMethod -Method Post -Uri '$apiDlq' -ContentType 'application/json' -Body '{\"action\":\"redrive\"}'"
  }

  exit 0
}

Write-Host ""
Write-Host "WARNING: No messages in DLQ"
Write-Host "This could mean:"
Write-Host "  1) Still processing (wait longer)"
Write-Host "  2) Lambda didn't fail (check Lambda logs)"
Write-Host "  3) Message was processed successfully"
exit 2

