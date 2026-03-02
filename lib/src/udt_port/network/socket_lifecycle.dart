import 'mobile_constraints.dart';
import 'socket_runtime_plan.dart';
import 'transition_simulation.dart';

/// Runtime adapter boundary for upcoming live-socket modules.
abstract interface class UdtSocketRuntimeTarget {
  Future<void> bind(UdtBindFamily family, {required bool dualStack});
  Future<void> close();
}

enum UdtLifecycleState { idle, bound, paused, closed }

final class UdtLifecycleSnapshot {
  const UdtLifecycleSnapshot({
    required this.state,
    required this.boundFamily,
    required this.ackIntervalMillis,
    required this.rtoScale,
    required this.reason,
  });

  final UdtLifecycleState state;
  final UdtBindFamily? boundFamily;
  final int ackIntervalMillis;
  final double rtoScale;
  final String reason;
}

/// Deterministic lifecycle coordinator for section-4 socket integration.
///
/// This consumes runtime bind plans plus transition simulation output to provide
/// auditable bind/pause/resume behavior before real socket I/O is wired.
final class UdtSocketLifecycleCoordinator {
  const UdtSocketLifecycleCoordinator({
    UdtNetworkTransitionSimulator transitionSimulator =
        const UdtNetworkTransitionSimulator(),
  }) : _transitionSimulator = transitionSimulator;

  final UdtNetworkTransitionSimulator _transitionSimulator;

  Future<UdtLifecycleSnapshot> start({
    required UdtSocketRuntimeTarget target,
    required UdtSocketRuntimePlan runtimePlan,
    required UdtMobilePolicyInput initialMobileInput,
  }) async {
    if (runtimePlan.hasBlockingFailure) {
      return const UdtLifecycleSnapshot(
        state: UdtLifecycleState.closed,
        boundFamily: null,
        ackIntervalMillis: 0,
        rtoScale: 0,
        reason: 'Required socket option failed; runtime plan is blocking.',
      );
    }

    if (runtimePlan.bindPlans.isEmpty) {
      return const UdtLifecycleSnapshot(
        state: UdtLifecycleState.closed,
        boundFamily: null,
        ackIntervalMillis: 0,
        rtoScale: 0,
        reason: 'No bind plan available.',
      );
    }

    final selected = runtimePlan.bindPlans.first;
    await target.bind(selected.family, dualStack: selected.dualStack);

    final transition = _transitionSimulator.run([
      UdtTransitionEvent(input: initialMobileInput, elapsedMillis: 0),
    ]).single;

    final paused = transition.decision.shouldPauseSending;
    return UdtLifecycleSnapshot(
      state: paused ? UdtLifecycleState.paused : UdtLifecycleState.bound,
      boundFamily: selected.family,
      ackIntervalMillis: transition.recommendedAckIntervalMillis,
      rtoScale: transition.recommendedRtoScale,
      reason: selected.reason,
    );
  }

  UdtLifecycleSnapshot onTransition({
    required UdtLifecycleSnapshot previous,
    required UdtMobilePolicyInput mobileInput,
    required int elapsedMillis,
  }) {
    final transition = _transitionSimulator.run([
      UdtTransitionEvent(input: mobileInput, elapsedMillis: elapsedMillis),
    ]).single;

    return UdtLifecycleSnapshot(
      state: transition.decision.shouldPauseSending
          ? UdtLifecycleState.paused
          : (previous.state == UdtLifecycleState.closed
                ? UdtLifecycleState.closed
                : UdtLifecycleState.bound),
      boundFamily: previous.boundFamily,
      ackIntervalMillis: transition.recommendedAckIntervalMillis,
      rtoScale: transition.recommendedRtoScale,
      reason: transition.decision.reason,
    );
  }

  Future<UdtLifecycleSnapshot> shutdown({
    required UdtSocketRuntimeTarget target,
    required UdtLifecycleSnapshot previous,
  }) async {
    await target.close();
    return UdtLifecycleSnapshot(
      state: UdtLifecycleState.closed,
      boundFamily: previous.boundFamily,
      ackIntervalMillis: previous.ackIntervalMillis,
      rtoScale: previous.rtoScale,
      reason: 'Socket lifecycle closed by coordinator.',
    );
  }
}
