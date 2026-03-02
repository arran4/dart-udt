import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('recovery policy validates inputs', () {
    const policy = UdtConnectivityRecoveryPolicy();

    expect(
      () => policy.evaluate(
        const UdtRecoveryInput(
          consecutiveFailures: -1,
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          batterySaverEnabled: false,
          baseRetryDelayMillis: 100,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => policy.evaluate(
        const UdtRecoveryInput(
          consecutiveFailures: 0,
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          batterySaverEnabled: false,
          baseRetryDelayMillis: 0,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'recovery backoff increases with failures and environment constraints',
    () {
      const policy = UdtConnectivityRecoveryPolicy();

      final foreground = policy.evaluate(
        const UdtRecoveryInput(
          consecutiveFailures: 2,
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          batterySaverEnabled: false,
          baseRetryDelayMillis: 100,
        ),
      );
      final backgroundCellular = policy.evaluate(
        const UdtRecoveryInput(
          consecutiveFailures: 2,
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.cellular,
          batterySaverEnabled: true,
          baseRetryDelayMillis: 100,
        ),
      );

      expect(foreground.nextRetryDelayMillis, 400);
      expect(
        backgroundCellular.nextRetryDelayMillis,
        greaterThan(foreground.nextRetryDelayMillis),
      );
    },
  );

  test('recovery decision toggles reset and escalation thresholds', () {
    const policy = UdtConnectivityRecoveryPolicy();

    final reset = policy.evaluate(
      const UdtRecoveryInput(
        consecutiveFailures: 3,
        appState: UdtMobileAppState.foreground,
        networkType: UdtMobileNetworkType.unknown,
        batterySaverEnabled: false,
        baseRetryDelayMillis: 100,
      ),
    );

    final escalate = policy.evaluate(
      const UdtRecoveryInput(
        consecutiveFailures: 5,
        appState: UdtMobileAppState.foreground,
        networkType: UdtMobileNetworkType.unknown,
        batterySaverEnabled: false,
        baseRetryDelayMillis: 100,
      ),
    );

    expect(reset.shouldResetSession, isTrue);
    expect(reset.shouldEscalateToOperator, isFalse);

    expect(escalate.shouldResetSession, isTrue);
    expect(escalate.shouldEscalateToOperator, isTrue);
  });
}
