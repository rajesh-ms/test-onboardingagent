---
name: uap-onboarding
description: "Use when onboarding, validating, submitting, approving, deploying, or troubleshooting a domain agent for the AI Marketplace from VS Code, GitHub, CLI, or the Publisher Portal."
---

# UAP Onboarding

## Overview

Use this skill to guide a domain engineer from local agent code to a governed AI Marketplace submission. It works with the same backend onboarding pipeline used by the Publisher Portal and GitHub push flow.

## When To Use

- You want to onboard a domain agent into AI Marketplace.
- You need to create or validate `agent-manifest.json`.
- You want to submit a repo-backed agent from VS Code.
- You need to understand a failed onboarding stage.
- You want CLI or UI directions for onboarding.

## Required Inputs

- `tenantId`
- agent name, version, owner team, and owner email
- runtime image reference for ACA
- capability tags
- RAI tags and data categories
- GitHub repository URL, branch, and commit SHA

## Manifest Template

Create `agent-manifest.json` in the agent repository root:

```json
{
  "name": "Claims Copilot",
  "version": "1.0.0",
  "description": "Assists claims analysts with document summarization and routing.",
  "owner": { "team": "claims-platform", "email": "claims-platform@example.com" },
  "runtime": { "type": "aca", "image": "contoso.azurecr.io/claims-copilot:1.0.0" },
  "capabilities": ["claims-summary"],
  "rai": { "tags": ["human-in-the-loop"], "data_categories": ["pii"] },
  "repository": { "url": "https://github.com/contoso/claims-copilot", "branch": "main" }
}
```

## VS Code Workflow

1. Ask for missing required inputs.
2. Inspect the repo shape and identify likely runtime, Dockerfile, tests, and manifest location.
3. Create or update `agent-manifest.json`.
4. Run local validation if the marketplace API is available:

```powershell
npm run test:onboarding --workspace ai-marketplace-api --
```

5. Submit through the UI or CLI path below.

## Submit Via CLI

If the `uap` CLI is installed:

```powershell
uap validate --path .
uap submit --path . --tenant contoso
uap status <submissionId>
```

If the CLI is not installed yet, use the API-backed local surrogate:

```powershell
$base = $env:UAP_API_BASE_URL ?? "http://localhost:7071/api"
$tenantId = "contoso"
$manifest = Get-Content .\agent-manifest.json -Raw | ConvertFrom-Json
$body = @{
  tenantId = $tenantId
  actorId = "vscode-uap-onboarding"
  source = "vscode-skill"
  manifest = $manifest
  repoContext = @{
    url = $manifest.repository.url
    branch = $manifest.repository.branch
    commit_sha = (git rev-parse HEAD)
  }
} | ConvertTo-Json -Depth 20
Invoke-RestMethod -Method Post -Uri "$base/onboarding/submissions" -ContentType "application/json" -Body $body
```

## Submit Via UI

Open the Publisher Portal onboarding page:

```text
/onboarding/new
```

Local development URL:

```text
http://localhost:3000/onboarding/new
```

## Troubleshooting

- `approval-pending`: a reviewer must approve the submission before provisioning.
- `failed` during provenance: check issuer, source SHA, builder identity, and attestation URL.
- `failed` during scan: resolve critical findings or declare PHI only when approved.
- `failed` during eval: pass rate must be at least `0.8` and score delta must be no worse than `-0.02`.