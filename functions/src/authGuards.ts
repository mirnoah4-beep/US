// Pure authorization guards, kept free of firebase-admin / firebase-functions
// so the decision logic is unit-testable without the emulator or a runtime.
// index.ts wraps these in HttpsError-throwing helpers.

export type AuthTokenClaims = {
  email_verified?: boolean;
  firebase?: { sign_in_provider?: string };
};

/// Server-authoritative email verification (audit M2).
///
/// True when this caller must be blocked for an unverified email: i.e. the
/// account signed in with the PASSWORD provider and its token does not carry
/// email_verified === true. Federated providers (google.com, apple.com, …)
/// are never 'password', so they are never blocked here. A missing/!object
/// token is treated as "not a password user" and is not blocked by this
/// predicate (the caller still enforces authentication separately).
export function passwordUserNeedsVerification(token: AuthTokenClaims | undefined | null): boolean {
  return token?.firebase?.sign_in_provider === 'password' && token.email_verified !== true;
}
