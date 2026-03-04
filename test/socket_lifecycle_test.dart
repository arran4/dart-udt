import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _FakeRuntimeTarget implements UdtSocketRuntimeTarget {
  UdtBindFamily? boundFamily;
  bool dualStack = false;
  bool closed = false;

  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {
    boundFamily = family;
    this.dualStack = dualStack;
  }

  Future<void> close() async {
    closed = true;
  }
}

void main() {
  test(
    'start binds first plan and returns bound state when sending allowed',
    () async {
      final target = _FakeRuntimeTarget();
      const coordinator = UdtSocketLifecycleCoordinator();

      const runtimePlan = UdtSocketRuntimePlan(
        bindPlans: [
          UdtBindPlan(
            family: UdtBindFamily.ipv6,
            dualStack: true,
            requireIpv6OnlyFalse: true,
            reason: 'test-plan',
          ),
        ],
        applyReport: UdtSocketOptionApplicationReport([]),
      );

      final snapshot = await coordinator.start(
        target: target,
        runtimePlan: runtimePlan,
        initialMobileInput: const UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      );

      expect(target.boundFamily, UdtBindFamily.ipv6);
      expect(target.dualStack, isTrue);
      expect(snapshot.state, UdtLifecycleState.bound);
      expect(snapshot.ackIntervalMillis, 10);
    },
  );

  test('start returns closed state when runtime plan is blocking', () async {
    final target = _FakeRuntimeTarget();
    const coordinator = UdtSocketLifecycleCoordinator();

    const runtimePlan = UdtSocketRuntimePlan(
      bindPlans: [
        UdtBindPlan(
          family: UdtBindFamily.ipv4,
          dualStack: false,
          requireIpv6OnlyFalse: false,
          reason: 'fallback',
        ),
      ],
      applyReport: UdtSocketOptionApplicationReport([
        UdtSocketOptionApplyResult(
          key: UdtSocketOptionKey.ipv6Only,
          value: true,
          status: UdtSocketOptionApplyStatus.failedRequired,
          reason: 'required option failed',
        ),
      ]),
    );

    final snapshot = await coordinator.start(
      target: target,
      runtimePlan: runtimePlan,
      initialMobileInput: const UdtMobilePolicyInput(
        appState: UdtMobileAppState.foreground,
        networkType: UdtMobileNetworkType.wifi,
        allowBackgroundNetwork: true,
        batterySaverEnabled: false,
      ),
    );

    expect(target.boundFamily, isNull);
    expect(snapshot.state, UdtLifecycleState.closed);
  });

  test('onTransition can move lifecycle to paused state', () {
    const coordinator = UdtSocketLifecycleCoordinator();

    const previous = UdtLifecycleSnapshot(
      state: UdtLifecycleState.bound,
      boundFamily: UdtBindFamily.ipv4,
      ackIntervalMillis: 10,
      rtoScale: 1,
      reason: 'initial',
    );

    final next = coordinator.onTransition(
      previous: previous,
      elapsedMillis: 20,
      mobileInput: const UdtMobilePolicyInput(
        appState: UdtMobileAppState.background,
        networkType: UdtMobileNetworkType.cellular,
        allowBackgroundNetwork: true,
        batterySaverEnabled: false,
      ),
    );

    expect(next.state, UdtLifecycleState.paused);
    expect(next.boundFamily, UdtBindFamily.ipv4);
    expect(next.ackIntervalMillis, 20);
  });

  test('shutdown closes target and marks lifecycle closed', () async {
    final target = _FakeRuntimeTarget();
    const coordinator = UdtSocketLifecycleCoordinator();

    const previous = UdtLifecycleSnapshot(
      state: UdtLifecycleState.bound,
      boundFamily: UdtBindFamily.ipv6,
      ackIntervalMillis: 10,
      rtoScale: 1,
      reason: 'running',
    );

    final closed = await coordinator.shutdown(
      target: target,
      previous: previous,
    );

    expect(target.closed, isTrue);
    expect(closed.state, UdtLifecycleState.closed);
    expect(closed.boundFamily, UdtBindFamily.ipv6);
  });
}
