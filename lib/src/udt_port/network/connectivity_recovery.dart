import 'mobile_constraints.dart';

final class UdtRecoveryInput {
  const UdtRecoveryInput({
    required this.consecutiveFailures,
    required this.appState,
    required this.networkType,
    required this.batterySaverEnabled,
    required this.baseRetryDelayMillis,
  });

  final int consecutiveFailures;
  final UdtMobileAppState appState;
  final UdtMobileNetworkType networkType;
  final bool batterySaverEnabled;
  final int baseRetryDelayMillis;
}

final class UdtRecoveryDecision {
  const UdtRecoveryDecision({
    required this.nextRetryDelayMillis,
    required this.shouldResetSession,
    required this.shouldEscalateToOperator,
    required this.reason,
  });

  final int nextRetryDelayMillis;
  final bool shouldResetSession;
  final bool shouldEscalateToOperator;
  final String reason;
}

/// Deterministic connectivity-recovery policy for section-4 reliability work.
final class UdtConnectivityRecoveryPolicy {
  const UdtConnectivityRecoveryPolicy();

  UdtRecoveryDecision evaluate(UdtRecoveryInput input) {
    if (input.consecutiveFailures < 0) {
      throw ArgumentError.value(
        input.consecutiveFailures,
        'consecutiveFailures',
        'must be >= 0',
      );
    }
    if (input.baseRetryDelayMillis <= 0) {
      throw ArgumentError.value(
        input.baseRetryDelayMillis,
        'baseRetryDelayMillis',
        'must be > 0',
      );
    }

    final cappedFailures =
        input.consecutiveFailures > 6 ? 6 : input.consecutiveFailures;
    final backoffMultiplier = 1 << cappedFailures;

    var nextDelay = input.baseRetryDelayMillis * backoffMultiplier;

    if (input.appState == UdtMobileAppState.background) {
      nextDelay = (nextDelay * 1.5).round();
    }
    if (input.networkType == UdtMobileNetworkType.cellular) {
      nextDelay = (nextDelay * 1.25).round();
    }
    if (input.batterySaverEnabled) {
      nextDelay = (nextDelay * 1.5).round();
    }

    final shouldResetSession = input.consecutiveFailures >= 3;
    final shouldEscalate = input.consecutiveFailures >= 5;

    return UdtRecoveryDecision(
      nextRetryDelayMillis: nextDelay,
      shouldResetSession: shouldResetSession,
      shouldEscalateToOperator: shouldEscalate,
      reason: shouldEscalate
          ? 'High repeated failure count; escalate and reset aggressively.'
          : (shouldResetSession
              ? 'Repeated failures; reset session before retry.'
              : 'Initial retry backoff path.'),
    );
  }
}
