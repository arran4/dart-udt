import 'dart:io';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test(
    'live runtime target records optional socket-option skips in plan report',
    () async {
      const builder = UdtCompatibilityProfileBuilder();
      final profile = builder.build(
        platform: 'linux',
        ipMode: UdtIpMode.ipv4Only,
        ipv6: true,
        mobileInput: const UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      );

      final target = UdtRawDatagramRuntimeTarget(
        ipv4BindAddress: InternetAddress.loopbackIPv4,
        localPort: 0,
      );

      const applier = UdtSocketRuntimeApplier();
      final report = await applier.applyProfile(
        profile: profile,
        optionTarget: target,
        runtimeTarget: target,
      );

      expect(report.runtimePlan.applyReport.hasRequiredFailure, isFalse);
      expect(
        report.runtimePlan.applyReport.results.any(
          (result) =>
              result.key == UdtSocketOptionKey.receiveBufferBytes &&
              result.status == UdtSocketOptionApplyStatus.skippedUnsupported,
        ),
        isTrue,
      );
      expect(report.execution.isBound, isTrue);

      await target.close();
    },
  );

  test(
    'required option failure from runtime target blocks bind execution',
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

      final target = UdtRawDatagramRuntimeTarget(
        ipv6BindAddress: InternetAddress.loopbackIPv6,
        localPort: 0,
        supportsIpv6OnlyOption: false,
      );

      const applier = UdtSocketRuntimeApplier();
      final report = await applier.applyProfile(
        profile: profile,
        optionTarget: target,
        runtimeTarget: target,
      );

      expect(report.runtimePlan.applyReport.hasRequiredFailure, isTrue);
      expect(report.execution.isBound, isFalse);
      expect(
        report.runtimePlan.applyReport.results.any(
          (result) =>
              result.key == UdtSocketOptionKey.ipv6Only &&
              result.status == UdtSocketOptionApplyStatus.failedRequired,
        ),
        isTrue,
      );

      await target.close();
    },
  );
}
