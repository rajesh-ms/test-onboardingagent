param(
  [Parameter(Mandatory = $true)]
  [string]$SubmissionId
)

$ErrorActionPreference = "Stop"

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

$tenantId = if ($env:MARKETPLACE_TENANT_ID) { $env:MARKETPLACE_TENANT_ID } else { "contoso" }
$apiUrl = $env:MARKETPLACE_API_URL.TrimEnd("/")
$manifest = Get-Content ./agent-manifest.json -Raw | ConvertFrom-Json
$repo = Get-RepositoryFullName -RepositoryUrl ([string]$manifest.repository.url)
$serverUrl = if ($env:GITHUB_SERVER_URL) { $env:GITHUB_SERVER_URL } else { "https://github.com" }
$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { "local-demo" }
$sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { Get-CurrentCommitSha }
$ref = if ($env:GITHUB_REF) { $env:GITHUB_REF } else { "refs/heads/main" }

$headers = @{ "Content-Type" = "application/json" }
if ($env:MARKETPLACE_API_KEY) {
  $headers["x-functions-key"] = $env:MARKETPLACE_API_KEY
}

$provenance = @{
  tenantId = $tenantId
  actorId = "github-actions"
  issuer = "token.actions.githubusercontent.com"
  subject = "repo:${repo}:ref:$ref"
  sourceSha = $sha
  builderIdentity = "github-actions"
  attestationUrl = "$serverUrl/$repo/actions/runs/$runId"
  sbomUrl = "$serverUrl/$repo/actions/runs/$runId"
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions/$SubmissionId/provenance" -Headers $headers -Body $provenance | ConvertTo-Json -Depth 20

$scan = @{
  tenantId = $tenantId
  actorId = "github-actions"
  phiSuspected = $false
  findings = @()
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions/$SubmissionId/scan-findings" -Headers $headers -Body $scan | ConvertTo-Json -Depth 20
