param(
  [Parameter(Mandatory = $true)]
  [string]$SubmissionId
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

if (-not $env:MARKETPLACE_API_URL) {
  throw "MARKETPLACE_API_URL is required."
}

if (-not $env:DEPLOYMENT_OUTPUTS_SECRET) {
  throw "DEPLOYMENT_OUTPUTS_SECRET is required to sign deployment outputs."
}

$tenantId = if ($env:MARKETPLACE_TENANT_ID) { $env:MARKETPLACE_TENANT_ID } else { "contoso" }
$apiUrl = $env:MARKETPLACE_API_URL.TrimEnd("/")
$endpointUrl = if ($env:DEPLOYMENT_ENDPOINT_URL) { $env:DEPLOYMENT_ENDPOINT_URL } else { "https://claim-management-agent.example.com/a2a" }
$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { "local-demo" }

$headers = @{ "Content-Type" = "application/json" }
if ($env:MARKETPLACE_API_KEY) {
  $headers["x-functions-key"] = $env:MARKETPLACE_API_KEY
}

$approval = @{
  tenantId = $tenantId
  reviewerId = "executive-demo-reviewer"
  justification = "Executive demo approval after validation evidence passed."
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions/$SubmissionId/approve" -Headers $headers -Body $approval | ConvertTo-Json -Depth 20

$openGate = @{
  tenantId = $tenantId
  actorId = "onboarding-agent"
  checkRunId = $runId
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions/$SubmissionId/gate/open" -Headers $headers -Body $openGate | ConvertTo-Json -Depth 20

$transitionGate = @{
  tenantId = $tenantId
  actorId = "onboarding-agent"
  targetStatus = "success"
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions/$SubmissionId/gate/transition" -Headers $headers -Body $transitionGate | ConvertTo-Json -Depth 20

$evalReport = @{
  tenantId = $tenantId
  actorId = "github-actions"
  passCount = 10
  failCount = 0
  scoreDeltaVsPrior = 0
  reportUrl = "https://github.com/rajesh-ms/test-onboardingagent/actions/runs/$runId"
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Method Post -Uri "$apiUrl/api/onboarding/submissions/$SubmissionId/eval-report" -Headers $headers -Body $evalReport | ConvertTo-Json -Depth 20

$deploymentPayload = @{
  tenantId = $tenantId
  deploymentOutputs = @{
    endpointUrl = $endpointUrl
    resourceId = "/subscriptions/demo/resourceGroups/rg-uap-demo/providers/Microsoft.App/containerApps/test-claim-management-agent"
    apimOperationUrl = "https://gateway.example.com/agents/test-claim-management-agent/invoke"
  }
} | ConvertTo-Json -Depth 20 -Compress

$signature = New-HmacSignature -Secret $env:DEPLOYMENT_OUTPUTS_SECRET -Payload $deploymentPayload
$deploymentHeaders = $headers.Clone()
$deploymentHeaders["x-uap-signature-256"] = $signature
$activation = Invoke-RestMethod -Method Post -Uri "$apiUrl/api/submissions/$SubmissionId/deployment-outputs" -Headers $deploymentHeaders -Body $deploymentPayload
$activation | ConvertTo-Json -Depth 20

if ($env:GITHUB_WEBHOOK_SECRET) {
  pwsh ./.github/scripts/send-webhook-checkpoint.ps1 -SubmissionId $SubmissionId -Stage activation -Conclusion success
}

if ($env:GITHUB_OUTPUT) {
  "activation_status=$($activation.status)" >> $env:GITHUB_OUTPUT
  "agent_id=$($activation.agentId)" >> $env:GITHUB_OUTPUT
}
