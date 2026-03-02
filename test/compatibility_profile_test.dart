import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('builder composes socket options, mtu plan, and mobile policy', () {
    const builder = UdtCompatibilityProfileBuilder();

    final profile = builder.build(
      platform: 'linux',
      ipMode: UdtIpMode.dualStack,
      ipv6: true,
      pathMtuHint: 1300,
      mobileInput: const UdtMobilePolicyInput(
        appState: UdtMobileAppState.background,
        networkType: UdtMobileNetworkType.wifi,
        allowBackgroundNetwork: true,
        batterySaverEnabled: false,
      ),
    );

    expect(profile.platform, 'linux');
    expect(profile.ipMode, UdtIpMode.dualStack);
    expect(profile.socketOptions, isNotEmpty);
    expect(
      profile.socketOptions.any((o) => o.key == UdtSocketOptionKey.ipv6Only),
      isTrue,
    );
    expect(profile.mtu.recommendedMtu, 1300);
    expect(profile.mobileDecision.ackIntervalMultiplier, 1.25);
  });

  test('builder handles ipv4-only profile with no ipv6-only option', () {
    const builder = UdtCompatibilityProfileBuilder();

    final profile = builder.build(
      platform: 'windows',
      ipMode: UdtIpMode.ipv4Only,
      ipv6: false,
      mobileInput: const UdtMobilePolicyInput(
        appState: UdtMobileAppState.foreground,
        networkType: UdtMobileNetworkType.wifi,
        allowBackgroundNetwork: true,
        batterySaverEnabled: false,
      ),
    );

    expect(
      profile.socketOptions.where((o) => o.key == UdtSocketOptionKey.ipv6Only),
      isEmpty,
    );
    expect(profile.mtu.recommendedMtu, 1400);
    expect(profile.mobileDecision.shouldPauseSending, isFalse);
  });
}
