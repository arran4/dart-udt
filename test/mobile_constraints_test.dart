import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('foreground baseline keeps sending and receiving active', () {
    const policy = UdtMobileConstraintsPolicy();

    final decision = policy.evaluate(
      const UdtMobilePolicyInput(
        appState: UdtMobileAppState.foreground,
        networkType: UdtMobileNetworkType.wifi,
        allowBackgroundNetwork: true,
        batterySaverEnabled: false,
      ),
    );

    expect(decision.shouldPauseSending, isFalse);
    expect(decision.shouldKeepReceiving, isTrue);
    expect(decision.ackIntervalMultiplier, 1.0);
  });

  test('mobile policy matrix validates background/power/network transitions', () {
    const policy = UdtMobileConstraintsPolicy();

    const scenarios = <
      ({
        UdtMobilePolicyInput input,
        bool pause,
        bool keepReceiving,
        double ackMultiplier,
      })
    >[
      (
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
        pause: false,
        keepReceiving: true,
        ackMultiplier: 1.0,
      ),
      (
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.cellular,
          allowBackgroundNetwork: true,
          batterySaverEnabled: true,
        ),
        pause: false,
        keepReceiving: true,
        ackMultiplier: 1.5,
      ),
      (
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.unknown,
          allowBackgroundNetwork: false,
          batterySaverEnabled: false,
        ),
        pause: true,
        keepReceiving: false,
        ackMultiplier: 2.0,
      ),
      (
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.cellular,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
        pause: true,
        keepReceiving: true,
        ackMultiplier: 2.0,
      ),
      (
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: true,
        ),
        pause: true,
        keepReceiving: true,
        ackMultiplier: 2.0,
      ),
      (
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
        pause: false,
        keepReceiving: true,
        ackMultiplier: 1.25,
      ),
    ];

    for (final scenario in scenarios) {
      final decision = policy.evaluate(scenario.input);
      expect(decision.shouldPauseSending, scenario.pause);
      expect(decision.shouldKeepReceiving, scenario.keepReceiving);
      expect(decision.ackIntervalMultiplier, scenario.ackMultiplier);
    }
  });

  test('foreground + cellular + battery saver increases ACK interval', () {
    const policy = UdtMobileConstraintsPolicy();

    final decision = policy.evaluate(
      const UdtMobilePolicyInput(
        appState: UdtMobileAppState.foreground,
        networkType: UdtMobileNetworkType.cellular,
        allowBackgroundNetwork: true,
        batterySaverEnabled: true,
      ),
    );

    expect(decision.shouldPauseSending, isFalse);
    expect(decision.shouldKeepReceiving, isTrue);
    expect(decision.ackIntervalMultiplier, 1.5);
  });

  test('background with networking disallowed pauses traffic', () {
    const policy = UdtMobileConstraintsPolicy();

    final decision = policy.evaluate(
      const UdtMobilePolicyInput(
        appState: UdtMobileAppState.background,
        networkType: UdtMobileNetworkType.unknown,
        allowBackgroundNetwork: false,
        batterySaverEnabled: false,
      ),
    );

    expect(decision.shouldPauseSending, isTrue);
    expect(decision.shouldKeepReceiving, isFalse);
    expect(decision.ackIntervalMultiplier, 2.0);
  });

  test('background constrained mode keeps receive path but pauses send', () {
    const policy = UdtMobileConstraintsPolicy();

    final decision = policy.evaluate(
      const UdtMobilePolicyInput(
        appState: UdtMobileAppState.background,
        networkType: UdtMobileNetworkType.cellular,
        allowBackgroundNetwork: true,
        batterySaverEnabled: false,
      ),
    );

    expect(decision.shouldPauseSending, isTrue);
    expect(decision.shouldKeepReceiving, isTrue);
    expect(decision.ackIntervalMultiplier, 2.0);
  });
}
