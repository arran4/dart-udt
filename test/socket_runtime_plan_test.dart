import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _RuntimeFakeTarget implements UdtSocketOptionTarget {
  _RuntimeFakeTarget({this.failRequiredIpv6Only = false});

  final bool failRequiredIpv6Only;

  @override
  Future<void> setIpv6Only(bool enabled) async {
    if (failRequiredIpv6Only && enabled) {
      throw UnsupportedError('ipv6Only true unsupported');
    }
  }

  @override
  Future<void> setReceiveBufferBytes(int bytes) async {}

  @override
  Future<void> setReuseAddress(bool enabled) async {}

  @override
  Future<void> setReusePort(bool enabled) async {}

  @override
  Future<void> setSendBufferBytes(int bytes) async {}
}

void main() {
  test('runtime planner creates dual-stack bind strategy', () async {
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

    const planner = UdtSocketRuntimePlanner();
    final runtime = await planner.buildPlan(
      profile: profile,
      optionTarget: _RuntimeFakeTarget(),
    );

    expect(runtime.hasBlockingFailure, isFalse);
    expect(runtime.bindPlans, hasLength(2));
    expect(runtime.bindPlans.first.family, UdtBindFamily.ipv6);
    expect(runtime.bindPlans.first.dualStack, isTrue);
    expect(runtime.bindPlans.first.requireIpv6OnlyFalse, isTrue);
  });

  test(
    'runtime planner reports blocking failure for required option failure',
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

      const planner = UdtSocketRuntimePlanner();
      final runtime = await planner.buildPlan(
        profile: profile,
        optionTarget: _RuntimeFakeTarget(failRequiredIpv6Only: true),
      );

      expect(runtime.hasBlockingFailure, isTrue);
      expect(
        runtime.applyReport.results.any(
          (r) => r.status == UdtSocketOptionApplyStatus.failedRequired,
        ),
        isTrue,
      );
    },
  );
}
