sealed class JoinResult {
  const JoinResult();
}

final class JoinSuccess extends JoinResult {
  final String coupleId;
  const JoinSuccess(this.coupleId);
}

final class JoinFailure extends JoinResult {
  final JoinFailureReason reason;
  final String? debugMessage;
  const JoinFailure(this.reason, [this.debugMessage]);
}

enum JoinFailureReason {
  invalidCode,
  ownInvite,
  alreadyPartnered,
  inviteExpired,
  networkError,
}
