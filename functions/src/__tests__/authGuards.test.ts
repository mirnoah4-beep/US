// Unit tests for the M2 server-authoritative email-verification decision.
import { test } from 'node:test';
import * as assert from 'node:assert';
import { passwordUserNeedsVerification } from '../authGuards';

test('M2: password user with unverified email must be blocked', () => {
  assert.strictEqual(
    passwordUserNeedsVerification({ firebase: { sign_in_provider: 'password' }, email_verified: false }), true);
  assert.strictEqual(
    passwordUserNeedsVerification({ firebase: { sign_in_provider: 'password' } }), true); // missing claim
});

test('M2: password user with verified email is allowed', () => {
  assert.strictEqual(
    passwordUserNeedsVerification({ firebase: { sign_in_provider: 'password' }, email_verified: true }), false);
});

test('M2: federated providers are never blocked (email_verified irrelevant)', () => {
  assert.strictEqual(
    passwordUserNeedsVerification({ firebase: { sign_in_provider: 'google.com' }, email_verified: false }), false);
  assert.strictEqual(
    passwordUserNeedsVerification({ firebase: { sign_in_provider: 'apple.com' } }), false);
});

test('M2: a missing/empty token is not treated as a blocked password user', () => {
  assert.strictEqual(passwordUserNeedsVerification(undefined), false);
  assert.strictEqual(passwordUserNeedsVerification(null), false);
  assert.strictEqual(passwordUserNeedsVerification({}), false);
});
