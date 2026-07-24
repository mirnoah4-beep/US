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

enum JoinFailureReason {
  invalidCode,
  ownInvite,
  alreadyPartnered,
  inviteExpired,
  networkError,
}
