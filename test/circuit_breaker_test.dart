import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  UdtCircuitBreakerRecoveryContext context({
    UdtMobileAppState appState = UdtMobileAppState.foreground,
    UdtMobileNetworkType networkType = UdtMobileNetworkType.wifi,
    bool batterySaverEnabled = false,
  }) =>
      UdtCircuitBreakerRecoveryContext(
        appState: appState,
        networkType: networkType,
        batterySaverEnabled: batterySaverEnabled,
      );

  test('constructor validates base retry delay', () {
    expect(
      () => UdtCircuitBreaker(
        recoveryPolicy: const UdtConnectivityRecoveryPolicy(),
        baseRetryDelayMillis: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('success resets breaker to closed state', () {
    final breaker = UdtCircuitBreaker(
      recoveryPolicy: const UdtConnectivityRecoveryPolicy(),
      baseRetryDelayMillis: 100,
    );

    breaker.onFailure(context: context());
    final closed = breaker.onSuccess();

    expect(closed.state, UdtCircuitBreakerState.closed);
    expect(closed.failureCount, 0);
    expect(closed.nextRetryAfterMillis, 0);
  });

  test('repeated failures transition to half-open and open', () {
    final breaker = UdtCircuitBreaker(
      recoveryPolicy: const UdtConnectivityRecoveryPolicy(),
      baseRetryDelayMillis: 100,
    );

    breaker.onFailure(context: context());
    breaker.onFailure(context: context());
    final halfOpen = breaker.onFailure(context: context());
    final open = breaker.onFailure(context: context());
    final open2 = breaker.onFailure(context: context());

    expect(halfOpen.state, UdtCircuitBreakerState.halfOpen);
    expect(open.state, UdtCircuitBreakerState.halfOpen);
    expect(open2.state, UdtCircuitBreakerState.open);
    expect(open2.failureCount, 5);
    expect(open2.nextRetryAfterMillis, greaterThan(0));
  });

  test(
    'elapseTime validates input and moves open->halfOpen when delay clears',
    () {
      final breaker = UdtCircuitBreaker(
        recoveryPolicy: const UdtConnectivityRecoveryPolicy(),
        baseRetryDelayMillis: 100,
      );

      for (var i = 0; i < 5; i++) {
        breaker.onFailure(context: context());
      }

      final before = breaker.snapshot();
      expect(before.state, UdtCircuitBreakerState.open);

      expect(() => breaker.elapseTime(-1), throwsA(isA<ArgumentError>()));

      final after = breaker.elapseTime(before.nextRetryAfterMillis);
      expect(after.state, UdtCircuitBreakerState.halfOpen);
      expect(after.nextRetryAfterMillis, 0);
    },
  );
}
