sealed class JoinResult {
  const JoinResult();
}

final class JoinSuccess extends JoinResult {
  final String coupleId;
  const JoinSuccess(this.coupleId);
}

final class JoinFailure extends JoinResult {
  final JoinFailureReason reason;
  const JoinFailure(this.reason);
}

/// Mirrors the `details.reason` values the `joinCouple` / `createInvite`
/// callables return. Every server reason maps 1:1 — there is no generic
/// "permission denied → already partnered" guess any more.
enum JoinFailureReason {
  invalidCode,
  ownInvite,
  /// The CALLER already has a valid, active partner.
  selfAlreadyPartnered,
  /// The INVITER already has a valid, active partner.
  inviterAlreadyPartnered,
  inviteExpired,
  networkError,
}

/// Maps a callable failure to a precise reason. [code] is the
/// FirebaseFunctionsException code, [details] its `details` payload.
/// Pure so it is unit-testable without Firebase.
JoinFailureReason mapPairingError({required String? code, required Object? details}) {
  final reason = details is Map ? details['reason'] : null;
  switch (reason) {
    case 'invalid-code':
      return JoinFailureReason.invalidCode;
    case 'invite-expired':
      return JoinFailureReason.inviteExpired;
    case 'own-invite':
      return JoinFailureReason.ownInvite;
    case 'already-paired':
      return JoinFailureReason.selfAlreadyPartnered;
    case 'inviter-already-paired':
      return JoinFailureReason.inviterAlreadyPartnered;
  }
  // No structured reason: a transport/server failure. `not-found` without a
  // reason can only be a wrong function/region, never a user error.
  return JoinFailureReason.networkError;
}
