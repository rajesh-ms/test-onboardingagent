$ErrorActionPreference = "Stop"

function Get-CurrentCommitSha {
  $sha = git rev-parse --verify HEAD 2>$null
  if ($LASTEXITCODE -ne 0) {
    return "local-demo"
  }
  return $sha
}

if (-not $env:MARKETPLACE_API_URL) {
  throw "MARKETPLACE_API_URL is required. Example: https://<api-host>"
}

$tenantId = if ($env:MARKETPLACE_TENANT_ID) { $env:MARKETPLACE_TENANT_ID } else { "contoso" }
$manifest = Get-Content ./agent-manifest.json -Raw | ConvertFrom-Json
$repoUrl = $manifest.repository.url
$branch = if ($env:GITHUB_REF_NAME) { $env:GITHUB_REF_NAME } else { $manifest.repository.branch }
$commitSha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { Get-CurrentCommitSha }
if (-not $commitSha) { $commitSha = "local-demo" }

$body = @{
  tenantId = $tenantId
  actorId = "github-actions"
  source = "github-app-webhook"
  manifest = $manifest
  repoContext = @{
    url = $repoUrl
    branch = $branch
    commit_sha = $commitSha
    workflow_run_id = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { "local-demo" }
  }
} | ConvertTo-Json -Depth 20

$headers = @{ "Content-Type" = "application/json" }
if ($env:MARKETPLACE_API_KEY) {
  $headers["x-functions-key"] = $env:MARKETPLACE_API_KEY
}

$apiUrl = $env:MARKETPLACE_API_URL.TrimEnd("/")
$response = Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions" -Headers $headers -Body $body
$response | ConvertTo-Json -Depth 20
Set-Content -Path .onboarding-submission.json -Value ($response | ConvertTo-Json -Depth 20)

if ($env:GITHUB_OUTPUT) {
  "submission_id=$($response.submissionId)" >> $env:GITHUB_OUTPUT
  "status=$($response.status)" >> $env:GITHUB_OUTPUT
  "stage=$($response.currentStage)" >> $env:GITHUB_OUTPUT
  "risk_tier=$($response.riskTier)" >> $env:GITHUB_OUTPUT
}