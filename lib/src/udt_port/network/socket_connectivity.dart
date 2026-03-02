import 'dart:io';

import 'socket_runtime_plan.dart';

/// Endpoint family target for deterministic socket connect planning.
enum UdtEndpointFamily { ipv4, ipv6 }

final class UdtConnectPlan {
  const UdtConnectPlan({required this.family, required this.reason});

  final UdtEndpointFamily family;
  final String reason;

  InternetAddressType get addressType => switch (family) {
        UdtEndpointFamily.ipv4 => InternetAddressType.IPv4,
        UdtEndpointFamily.ipv6 => InternetAddressType.IPv6,
      };
}

/// Deterministic connect strategy generator derived from a selected bind plan.
///
/// This preserves explicit IPv4/IPv6 branch behavior before live connect APIs
/// are introduced.
final class UdtSocketConnectPlanner {
  const UdtSocketConnectPlanner();

  List<UdtConnectPlan> planFromBind(UdtBindPlan bindPlan) {
    return switch (bindPlan.family) {
      UdtBindFamily.ipv4 => const <UdtConnectPlan>[
          UdtConnectPlan(
            family: UdtEndpointFamily.ipv4,
            reason: 'IPv4 bind requires IPv4 remote endpoint.',
          ),
        ],
      UdtBindFamily.ipv6 when bindPlan.dualStack => const <UdtConnectPlan>[
          UdtConnectPlan(
            family: UdtEndpointFamily.ipv6,
            reason: 'Dual-stack prefers native IPv6 endpoint first.',
          ),
          UdtConnectPlan(
            family: UdtEndpointFamily.ipv4,
            reason: 'Dual-stack fallback allows IPv4 endpoint.',
          ),
        ],
      UdtBindFamily.ipv6 => const <UdtConnectPlan>[
          UdtConnectPlan(
            family: UdtEndpointFamily.ipv6,
            reason: 'IPv6-only bind requires IPv6 remote endpoint.',
          ),
        ],
    };
  }
}

abstract interface class UdtSocketConnectTarget {
  Future<void> connect(UdtEndpointFamily family);
}

final class UdtConnectAttemptResult {
  const UdtConnectAttemptResult({
    required this.plan,
    required this.success,
    this.error,
  });

  final UdtConnectPlan plan;
  final bool success;
  final Object? error;
}

final class UdtSocketConnectReport {
  const UdtSocketConnectReport({
    required this.attempts,
    required this.selectedPlan,
  });

  final List<UdtConnectAttemptResult> attempts;
  final UdtConnectPlan? selectedPlan;

  bool get isConnected => selectedPlan != null;
}

/// Deterministic connect executor with explicit family fallback ordering.
final class UdtSocketConnectExecutor {
  const UdtSocketConnectExecutor();

  Future<UdtSocketConnectReport> execute({
    required UdtSocketConnectTarget target,
    required List<UdtConnectPlan> plans,
  }) async {
    final attempts = <UdtConnectAttemptResult>[];

    for (final plan in plans) {
      try {
        await target.connect(plan.family);
        attempts.add(UdtConnectAttemptResult(plan: plan, success: true));
        return UdtSocketConnectReport(attempts: attempts, selectedPlan: plan);
      } catch (error) {
        attempts.add(
          UdtConnectAttemptResult(plan: plan, success: false, error: error),
        );
      }
    }

    return UdtSocketConnectReport(attempts: attempts, selectedPlan: null);
  }
}
