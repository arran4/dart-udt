import 'compatibility_profile.dart';
import 'platform_compatibility.dart';
import 'socket_option_application.dart';

/// Address family selection for deterministic bind/connect runtime planning.
enum UdtBindFamily { ipv4, ipv6 }

final class UdtBindPlan {
  const UdtBindPlan({
    required this.family,
    required this.dualStack,
    required this.requireIpv6OnlyFalse,
    required this.reason,
  });

  final UdtBindFamily family;
  final bool dualStack;
  final bool requireIpv6OnlyFalse;
  final String reason;
}

final class UdtSocketRuntimePlan {
  const UdtSocketRuntimePlan({
    required this.bindPlans,
    required this.applyReport,
  });

  final List<UdtBindPlan> bindPlans;
  final UdtSocketOptionApplicationReport applyReport;

  bool get hasBlockingFailure => applyReport.hasRequiredFailure;
}

/// Deterministic runtime planner that composes profile + option application into
/// concrete bind-family decisions for upcoming live socket modules.
final class UdtSocketRuntimePlanner {
  const UdtSocketRuntimePlanner({
    UdtSocketOptionApplier applier = const UdtSocketOptionApplier(),
  }) : _applier = applier;

  final UdtSocketOptionApplier _applier;

  Future<UdtSocketRuntimePlan> buildPlan({
    required UdtCompatibilityProfile profile,
    required UdtSocketOptionTarget optionTarget,
  }) async {
    final report = await _applier.apply(optionTarget, profile.socketOptions);

    final bindPlans = switch (profile.ipMode) {
      UdtIpMode.ipv4Only => const <UdtBindPlan>[
        UdtBindPlan(
          family: UdtBindFamily.ipv4,
          dualStack: false,
          requireIpv6OnlyFalse: false,
          reason: 'IPv4-only mode explicitly requested.',
        ),
      ],
      UdtIpMode.ipv6Only => const <UdtBindPlan>[
        UdtBindPlan(
          family: UdtBindFamily.ipv6,
          dualStack: false,
          requireIpv6OnlyFalse: false,
          reason: 'IPv6-only mode explicitly requested.',
        ),
      ],
      UdtIpMode.dualStack => const <UdtBindPlan>[
        UdtBindPlan(
          family: UdtBindFamily.ipv6,
          dualStack: true,
          requireIpv6OnlyFalse: true,
          reason: 'Dual-stack prefers IPv6 bind with IPv6-only disabled.',
        ),
        UdtBindPlan(
          family: UdtBindFamily.ipv4,
          dualStack: false,
          requireIpv6OnlyFalse: false,
          reason: 'Fallback IPv4 bind for platforms lacking dual-stack behavior.',
        ),
      ],
    };

    return UdtSocketRuntimePlan(bindPlans: bindPlans, applyReport: report);
  }
}
