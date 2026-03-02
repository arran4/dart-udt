import 'connectivity_recovery.dart';
import 'mobile_constraints.dart';

/// Circuit breaker states for deterministic network failure handling.
enum UdtCircuitBreakerState { closed, open, halfOpen }

final class UdtCircuitBreakerSnapshot {
  const UdtCircuitBreakerSnapshot({
    required this.state,
    required this.failureCount,
    required this.nextRetryAfterMillis,
    required this.reason,
  });

  final UdtCircuitBreakerState state;
  final int failureCount;
  final int nextRetryAfterMillis;
  final String reason;
}

/// Deterministic circuit breaker built on top of connectivity recovery policy.
final class UdtCircuitBreaker {
  UdtCircuitBreaker({
    required UdtConnectivityRecoveryPolicy recoveryPolicy,
    required int baseRetryDelayMillis,
  }) : _recoveryPolicy = recoveryPolicy,
       _baseRetryDelayMillis = baseRetryDelayMillis {
    if (baseRetryDelayMillis <= 0) {
      throw ArgumentError.value(
        baseRetryDelayMillis,
        'baseRetryDelayMillis',
        'must be > 0',
      );
    }
  }

  final UdtConnectivityRecoveryPolicy _recoveryPolicy;
  final int _baseRetryDelayMillis;

  int _failureCount = 0;
  UdtCircuitBreakerState _state = UdtCircuitBreakerState.closed;
  int _nextRetryAfterMillis = 0;

  UdtCircuitBreakerSnapshot snapshot() => UdtCircuitBreakerSnapshot(
    state: _state,
    failureCount: _failureCount,
    nextRetryAfterMillis: _nextRetryAfterMillis,
    reason: _state == UdtCircuitBreakerState.closed
        ? 'Healthy closed state.'
        : (_state == UdtCircuitBreakerState.open
              ? 'Open due to repeated failures.'
              : 'Half-open probe state.'),
  );

  UdtCircuitBreakerSnapshot onSuccess() {
    _failureCount = 0;
    _state = UdtCircuitBreakerState.closed;
    _nextRetryAfterMillis = 0;
    return snapshot();
  }

  UdtCircuitBreakerSnapshot onFailure({
    required UdtCircuitBreakerRecoveryContext context,
  }) {
    _failureCount += 1;

    final decision = _recoveryPolicy.evaluate(
      UdtRecoveryInput(
        consecutiveFailures: _failureCount,
        appState: context.appState,
        networkType: context.networkType,
        batterySaverEnabled: context.batterySaverEnabled,
        baseRetryDelayMillis: _baseRetryDelayMillis,
      ),
    );

    _nextRetryAfterMillis = decision.nextRetryDelayMillis;
    _state = decision.shouldEscalateToOperator
        ? UdtCircuitBreakerState.open
        : (decision.shouldResetSession
              ? UdtCircuitBreakerState.halfOpen
              : UdtCircuitBreakerState.closed);

    return snapshot();
  }

  UdtCircuitBreakerSnapshot elapseTime(int elapsedMillis) {
    if (elapsedMillis < 0) {
      throw ArgumentError.value(elapsedMillis, 'elapsedMillis', 'must be >= 0');
    }

    if (_nextRetryAfterMillis > elapsedMillis) {
      _nextRetryAfterMillis -= elapsedMillis;
    } else {
      _nextRetryAfterMillis = 0;
      if (_state == UdtCircuitBreakerState.open) {
        _state = UdtCircuitBreakerState.halfOpen;
      }
    }

    return snapshot();
  }
}

final class UdtCircuitBreakerRecoveryContext {
  const UdtCircuitBreakerRecoveryContext({
    required this.appState,
    required this.networkType,
    required this.batterySaverEnabled,
  });

  final UdtMobileAppState appState;
  final UdtMobileNetworkType networkType;
  final bool batterySaverEnabled;
}
