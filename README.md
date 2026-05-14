# Test Claim Management Agent

This repository demonstrates the complete AI Marketplace onboarding loop for a domain agent:

1. A domain engineer builds and tests a claim management agent locally.
2. The engineer opens a pull request.
3. GitHub Actions validates code and `agent-manifest.json`.
4. The workflow posts signed webhook checkpoints to AI Marketplace.
5. The workflow creates an onboarding submission and posts provenance plus scan evidence.
6. After merge to `main`, the publish lane can approve the demo, open the onboarding gate, post eval evidence, sign deployment outputs, and activate the AgentCard.

## Local Validation

```powershell
npm test
npm run validate:manifest
$env:MARKETPLACE_API_URL="http://localhost:7071"
$env:MARKETPLACE_TENANT_ID="contoso"
$env:GITHUB_WEBHOOK_SECRET="local-demo-webhook-secret"
$env:DEPLOYMENT_OUTPUTS_SECRET="local-demo-deployment-secret"
pwsh .\.github\scripts\submit-onboarding.ps1
$submission = Get-Content .\.onboarding-submission.json -Raw | ConvertFrom-Json
pwsh .\.github\scripts\post-validation-evidence.ps1 -SubmissionId $submission.submissionId
pwsh .\.github\scripts\send-webhook-checkpoint.ps1 -SubmissionId $submission.submissionId -Stage validation -Conclusion success
pwsh .\.github\scripts\publish-to-marketplace.ps1 -SubmissionId $submission.submissionId
```

## GitHub Repository Settings

For a GitHub-hosted run, `MARKETPLACE_API_URL` must be a public HTTPS URL for the marketplace API, such as the deployed ACA endpoint or a tunnel to the local Functions host.

```powershell
gh variable set MARKETPLACE_API_URL --body "https://<marketplace-api-host>"
gh variable set MARKETPLACE_TENANT_ID --body "contoso"
gh variable set DEMO_AUTO_APPROVE --body "true"
gh variable set DEPLOYMENT_ENDPOINT_URL --body "https://<claim-agent-endpoint>"
gh secret set GITHUB_WEBHOOK_SECRET --body "<same-secret-as-marketplace-api>"
gh secret set DEPLOYMENT_OUTPUTS_SECRET --body "<same-secret-as-marketplace-api>"
```

Without a public `MARKETPLACE_API_URL`, the PR workflow still validates the agent code and manifest but skips marketplace API calls.