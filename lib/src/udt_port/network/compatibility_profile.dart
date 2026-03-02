import 'mobile_constraints.dart';
import 'mtu_planning.dart';
import 'platform_compatibility.dart';

/// Consolidated deterministic network compatibility profile for one endpoint.
final class UdtCompatibilityProfile {
  const UdtCompatibilityProfile({
    required this.platform,
    required this.ipMode,
    required this.socketOptions,
    required this.mtu,
    required this.mobileDecision,
  });

  final String platform;
  final UdtIpMode ipMode;
  final List<UdtSocketOptionRecommendation> socketOptions;
  final UdtMtuPlanningDecision mtu;
  final UdtMobilePolicyDecision mobileDecision;
}

/// Builds a deterministic compatibility profile by composing section-4 planners.
final class UdtCompatibilityProfileBuilder {
  const UdtCompatibilityProfileBuilder({
    UdtSocketOptionPlanner? socketOptionPlanner,
    UdtMtuPlanner mtuPlanner = const UdtMtuPlanner(),
    UdtMobileConstraintsPolicy mobilePolicy =
        const UdtMobileConstraintsPolicy(),
  })  : _socketOptionPlanner = socketOptionPlanner,
        _mtuPlanner = mtuPlanner,
        _mobilePolicy = mobilePolicy;

  final UdtSocketOptionPlanner? _socketOptionPlanner;
  final UdtMtuPlanner _mtuPlanner;
  final UdtMobileConstraintsPolicy _mobilePolicy;

  UdtCompatibilityProfile build({
    required String platform,
    required UdtIpMode ipMode,
    required bool ipv6,
    int? pathMtuHint,
    required UdtMobilePolicyInput mobileInput,
  }) {
    final planner = _socketOptionPlanner ??
        UdtSocketOptionPlanner(platformOverride: platform);

    final socketOptions = planner.plan(mode: ipMode);
    final mtu = _mtuPlanner.plan(
      UdtMtuPlanningInput(
        platform: platform,
        ipv6: ipv6,
        pathMtuHint: pathMtuHint,
      ),
    );
    final mobileDecision = _mobilePolicy.evaluate(mobileInput);

    return UdtCompatibilityProfile(
      platform: platform,
      ipMode: ipMode,
      socketOptions: socketOptions,
      mtu: mtu,
      mobileDecision: mobileDecision,
    );
  }
}
