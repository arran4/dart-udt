import 'socket_lifecycle.dart';
import 'socket_runtime_plan.dart';

final class UdtBindAttemptResult {
  const UdtBindAttemptResult({
    required this.plan,
    required this.success,
    this.error,
  });

  final UdtBindPlan plan;
  final bool success;
  final Object? error;
}

final class UdtSocketRuntimeExecutionReport {
  const UdtSocketRuntimeExecutionReport({
    required this.attempts,
    required this.selectedPlan,
  });

  final List<UdtBindAttemptResult> attempts;
  final UdtBindPlan? selectedPlan;

  bool get isBound => selectedPlan != null;
}

/// Deterministic bind executor that walks runtime bind plans with fallback.
///
/// This remains socket-I/O agnostic and works with [UdtSocketRuntimeTarget]
/// adapters for deterministic tests and later real runtime wiring.
final class UdtSocketRuntimeExecutor {
  const UdtSocketRuntimeExecutor();

  Future<UdtSocketRuntimeExecutionReport> executeBindPlan({
    required UdtSocketRuntimeTarget target,
    required UdtSocketRuntimePlan runtimePlan,
  }) async {
    final attempts = <UdtBindAttemptResult>[];

    if (runtimePlan.hasBlockingFailure) {
      return UdtSocketRuntimeExecutionReport(
        attempts: attempts,
        selectedPlan: null,
      );
    }

    for (final bindPlan in runtimePlan.bindPlans) {
      try {
        await target.bind(bindPlan.family, dualStack: bindPlan.dualStack);
        attempts.add(UdtBindAttemptResult(plan: bindPlan, success: true));
        return UdtSocketRuntimeExecutionReport(
          attempts: attempts,
          selectedPlan: bindPlan,
        );
      } catch (error) {
        attempts.add(
          UdtBindAttemptResult(plan: bindPlan, success: false, error: error),
        );
      }
    }

    return UdtSocketRuntimeExecutionReport(attempts: attempts, selectedPlan: null);
  }
}
