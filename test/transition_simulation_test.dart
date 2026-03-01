import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('simulator tracks cumulative time and adapts ACK/RTO recommendations', () {
    const simulator = UdtNetworkTransitionSimulator(baseAckIntervalMillis: 10);

    final snapshots = simulator.run([
      const UdtTransitionEvent(
        elapsedMillis: 0,
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      ),
      const UdtTransitionEvent(
        elapsedMillis: 50,
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.cellular,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      ),
    ]);

    expect(snapshots, hasLength(2));
    expect(snapshots[0].timeMillis, 0);
    expect(snapshots[0].recommendedAckIntervalMillis, 10);
    expect(snapshots[0].recommendedRtoScale, 1.0);

    expect(snapshots[1].timeMillis, 50);
    expect(snapshots[1].recommendedAckIntervalMillis, 20);
    expect(snapshots[1].recommendedRtoScale, 1.5);
    expect(snapshots[1].decision.shouldPauseSending, isTrue);
  });

  test('simulator policy-transition matrix covers app/network/power branches', () {
    const simulator = UdtNetworkTransitionSimulator(baseAckIntervalMillis: 10);

    final snapshots = simulator.run([
      const UdtTransitionEvent(
        elapsedMillis: 5,
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      ),
      const UdtTransitionEvent(
        elapsedMillis: 5,
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.cellular,
          allowBackgroundNetwork: true,
          batterySaverEnabled: true,
        ),
      ),
      const UdtTransitionEvent(
        elapsedMillis: 5,
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.unknown,
          allowBackgroundNetwork: false,
          batterySaverEnabled: false,
        ),
      ),
      const UdtTransitionEvent(
        elapsedMillis: 5,
        input: UdtMobilePolicyInput(
          appState: UdtMobileAppState.background,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      ),
    ]);

    expect(snapshots, hasLength(4));

    expect(snapshots[0].recommendedAckIntervalMillis, 10);
    expect(snapshots[0].recommendedRtoScale, 1.0);

    expect(snapshots[1].recommendedAckIntervalMillis, 15);
    expect(snapshots[1].recommendedRtoScale, 1.2);

    expect(snapshots[2].recommendedAckIntervalMillis, 20);
    expect(snapshots[2].recommendedRtoScale, 1.5);

    expect(snapshots[3].recommendedAckIntervalMillis, 13);
    expect(snapshots[3].recommendedRtoScale, 1.2);

    expect(
      snapshots.map((snapshot) => snapshot.timeMillis).toList(),
      <int>[5, 10, 15, 20],
    );
  });

  test('simulator validates transition elapsedMillis', () {
    const simulator = UdtNetworkTransitionSimulator();

    expect(
      () => simulator.run([
        const UdtTransitionEvent(
          elapsedMillis: -1,
          input: UdtMobilePolicyInput(
            appState: UdtMobileAppState.foreground,
            networkType: UdtMobileNetworkType.wifi,
            allowBackgroundNetwork: true,
            batterySaverEnabled: false,
          ),
        ),
      ]),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('simulator enforces positive base ACK interval', () {
    const simulator = UdtNetworkTransitionSimulator(baseAckIntervalMillis: 0);

    expect(
      () => simulator.run(const <UdtTransitionEvent>[]),
      throwsA(isA<StateError>()),
    );
  });
}
