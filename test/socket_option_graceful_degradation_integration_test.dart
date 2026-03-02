import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _DegradeOptionTarget
    implements UdtSocketOptionTarget, UdtSocketRuntimeTarget {
  _DegradeOptionTarget({this.failReusePort = false, this.failIpv6Only = false});

  final bool failReusePort;
  final bool failIpv6Only;

  @override
  Future<void> setReceiveBufferBytes(int bytes) async {}

  @override
  Future<void> setSendBufferBytes(int bytes) async {}

  @override
  Future<void> setReuseAddress(bool enabled) async {}

  @override
  Future<void> setReusePort(bool enabled) async {
    if (failReusePort) {
      throw UnsupportedError('reuse port unsupported');
    }
  }

  @override
  Future<void> setIpv6Only(bool enabled) async {
    if (enabled && failIpv6Only) {
      throw UnsupportedError('ipv6 only unsupported');
    }
  }

  @override
  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {}

  @override
  Future<void> close() async {}
}

void main() {
  test(
    'optional socket-option failure degrades gracefully and runtime bind continues',
    () async {
      const builder = UdtCompatibilityProfileBuilder();
      final profile = builder.build(
        platform: 'linux',
        ipMode: UdtIpMode.dualStack,
        ipv6: true,
        mobileInput: const UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      );

      final target = _DegradeOptionTarget(failReusePort: true);

      const planner = UdtSocketRuntimePlanner();
      final runtimePlan = await planner.buildPlan(
        profile: profile,
        optionTarget: target,
      );

      expect(runtimePlan.hasBlockingFailure, isFalse);
      expect(
        runtimePlan.applyReport.results.any(
          (result) =>
              result.key == UdtSocketOptionKey.reusePort &&
              result.status == UdtSocketOptionApplyStatus.skippedUnsupported,
        ),
        isTrue,
      );

      const executor = UdtSocketRuntimeExecutor();
      final execution = await executor.executeBindPlan(
        target: target,
        runtimePlan: runtimePlan,
      );

      expect(execution.isBound, isTrue);
    },
  );

  test(
    'required socket-option failure blocks runtime bind execution',
    () async {
      const builder = UdtCompatibilityProfileBuilder();
      final profile = builder.build(
        platform: 'linux',
        ipMode: UdtIpMode.ipv6Only,
        ipv6: true,
        mobileInput: const UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      );

      final target = _DegradeOptionTarget(failIpv6Only: true);

      const planner = UdtSocketRuntimePlanner();
      final runtimePlan = await planner.buildPlan(
        profile: profile,
        optionTarget: target,
      );

      expect(runtimePlan.hasBlockingFailure, isTrue);
      expect(
        runtimePlan.applyReport.results.any(
          (result) =>
              result.key == UdtSocketOptionKey.ipv6Only &&
              result.status == UdtSocketOptionApplyStatus.failedRequired,
        ),
        isTrue,
      );

      const executor = UdtSocketRuntimeExecutor();
      final execution = await executor.executeBindPlan(
        target: target,
        runtimePlan: runtimePlan,
      );

      expect(execution.isBound, isFalse);
      expect(execution.attempts, isEmpty);
    },
  );
}
