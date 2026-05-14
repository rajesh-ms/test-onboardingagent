export function evaluateClaimSubmission(claim) {
  const missing = requiredFields.filter((field) => !claim?.[field]);
  if (missing.length > 0) {
    return {
      decision: 'needs-information',
      priority: 'normal',
      rationale: `Missing required claim fields: ${missing.join(', ')}`,
      nextStep: 'return-to-submitter',
    };
  }

  if (claim.amount >= 25000 || claim.requiresPriorAuthorization === true) {
    return {
      decision: 'requires-review',
      priority: 'high',
      rationale: 'Claim requires a human review because it is high value or prior authorization is required.',
      nextStep: 'route-to-claims-reviewer',
    };
  }

  return {
    decision: 'ready-to-submit',
    priority: 'normal',
    rationale: 'Claim has complete intake data and no automatic exception triggers.',
    nextStep: 'submit-to-core-claims-system',
  };
}

export function buildReviewerHandoff(claim, evaluation) {
  return {
    claimId: claim?.claimId ?? 'unknown',
    memberId: claim?.memberId ?? 'unknown',
    decision: evaluation.decision,
    priority: evaluation.priority,
    summary: evaluation.rationale,
    controls: ['human-review-required', 'audit-log-enabled', 'no-autonomous-denial'],
  };
}

const requiredFields = ['claimId', 'memberId', 'procedureCode', 'amount'];