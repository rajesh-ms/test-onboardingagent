import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateClaimSubmission, buildReviewerHandoff } from '../src/agent.js';

test('routes incomplete claims back to the submitter', () => {
  const result = evaluateClaimSubmission({ claimId: 'CLM-1001', amount: 120 });
  assert.equal(result.decision, 'needs-information');
  assert.equal(result.nextStep, 'return-to-submitter');
});

test('routes high value claims to human review', () => {
  const result = evaluateClaimSubmission({
    claimId: 'CLM-1002',
    memberId: 'MBR-9',
    procedureCode: '99213',
    amount: 30000,
  });
  assert.equal(result.decision, 'requires-review');
  assert.equal(result.priority, 'high');
});

test('builds an auditable reviewer handoff', () => {
  const claim = { claimId: 'CLM-1003', memberId: 'MBR-10', procedureCode: '70551', amount: 1000 };
  const evaluation = evaluateClaimSubmission(claim);
  const handoff = buildReviewerHandoff(claim, evaluation);
  assert.equal(handoff.claimId, 'CLM-1003');
  assert.ok(handoff.controls.includes('human-review-required'));
});