param(
  [string]$SubmissionId = "pending",
  [string]$Stage = "validation",
  [ValidateSet("success", "failure")]
  [string]$Conclusion = "success"
)

$ErrorActionPreference = "Stop"

function New-HmacSignature {
  param([Parameter(Mandatory = $true)][string]$Secret, [Parameter(Mandatory = $true)][string]$Payload)

  $secretBytes = [Text.Encoding]::UTF8.GetBytes($Secret)
  $payloadBytes = [Text.Encoding]::UTF8.GetBytes($Payload)
  $hmac = [Security.Cryptography.HMACSHA256]::new($secretBytes)
  try {
    $hash = $hmac.ComputeHash($payloadBytes)
    return "sha256=" + (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
  }
  finally {
    $hmac.Dispose()
  }
}

function Get-RepositoryFullName {
  param([Parameter(Mandatory = $true)][string]$RepositoryUrl)

  $repoMatch = [regex]::Match($RepositoryUrl.TrimEnd("/"), "^https://github\.com/([^/]+/[^/]+?)(?:\.git)?$", "IgnoreCase")
  if (-not $repoMatch.Success) {
    throw "repository.url must be a GitHub HTTPS URL."
  }
  return $repoMatch.Groups[1].Value
}

function Get-CurrentCommitSha {
  $sha = git rev-parse --verify HEAD 2>$null
  if ($LASTEXITCODE -ne 0) {
    return "local-demo"
  }
  return $sha
}

if (-not $env:MARKETPLACE_API_URL) {
  throw "MARKETPLACE_API_URL is required."
}

$webhookSecret = if ($env:UAP_WEBHOOK_SECRET) { $env:UAP_WEBHOOK_SECRET } else { $env:GITHUB_WEBHOOK_SECRET }
if (-not $webhookSecret) {
  throw "UAP_WEBHOOK_SECRET is required to sign webhook checkpoints."
}

$apiUrl = $env:MARKETPLACE_API_URL.TrimEnd("/")
$manifest = Get-Content ./agent-manifest.json -Raw | ConvertFrom-Json
$repo = Get-RepositoryFullName -RepositoryUrl ([string]$manifest.repository.url)
$serverUrl = if ($env:GITHUB_SERVER_URL) { $env:GITHUB_SERVER_URL } else { "https://github.com" }
$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { "local-demo" }
$sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { Get-CurrentCommitSha }
$deliveryId = "uap-$Stage-$SubmissionId-$runId-$(Get-Date -Format yyyyMMddHHmmssfff)"

$payload = @{
  action = "completed"
  repository = @{
    id = 10101
    full_name = $repo
    html_url = "$serverUrl/$repo"
  }
  workflow_run = @{
    id = $runId
    head_sha = $sha
    status = "completed"
    conclusion = $Conclusion
    html_url = "$serverUrl/$repo/actions/runs/$runId"
  }
  sender = @{
    login = "github-actions"
  }
  uap = @{
    submission_id = $SubmissionId
    stage = $Stage
  }
} | ConvertTo-Json -Depth 20 -Compress

$signature = New-HmacSignature -Secret $webhookSecret -Payload $payload
$headers = @{
  "Content-Type" = "application/json"
  "x-github-event" = "workflow_run"
  "x-github-delivery" = $deliveryId
  "x-hub-signature-256" = $signature
}

Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/github/webhook" -Headers $headers -Body $payload | ConvertTo-Json -Depth 20
