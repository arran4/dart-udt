import 'mobile_constraints.dart';

/// Deterministic transition event used for section-4 network/mobile simulation.
final class UdtTransitionEvent {
  const UdtTransitionEvent({required this.input, required this.elapsedMillis});

  final UdtMobilePolicyInput input;
  final int elapsedMillis;
}

/// Snapshot of policy + timing effects after processing one transition step.
final class UdtTransitionSnapshot {
  const UdtTransitionSnapshot({
    required this.timeMillis,
    required this.decision,
    required this.recommendedAckIntervalMillis,
    required this.recommendedRtoScale,
  });

  final int timeMillis;
  final UdtMobilePolicyDecision decision;
  final int recommendedAckIntervalMillis;
  final double recommendedRtoScale;
}

/// Deterministic transition simulator for mobile/network compatibility planning.
///
/// This gives section-4 coverage for backgrounding/network transitions without
/// requiring real network or device lifecycle hooks.
final class UdtNetworkTransitionSimulator {
  const UdtNetworkTransitionSimulator({
    UdtMobileConstraintsPolicy policy = const UdtMobileConstraintsPolicy(),
    int baseAckIntervalMillis = 10,
  }) : _policy = policy,
       _baseAckIntervalMillis = baseAckIntervalMillis;

  final UdtMobileConstraintsPolicy _policy;
  final int _baseAckIntervalMillis;

  List<UdtTransitionSnapshot> run(List<UdtTransitionEvent> events) {
    if (_baseAckIntervalMillis <= 0) {
      throw StateError('baseAckIntervalMillis must be > 0');
    }

    final snapshots = <UdtTransitionSnapshot>[];
    var timeMillis = 0;

    for (final event in events) {
      if (event.elapsedMillis < 0) {
        throw ArgumentError.value(
          event.elapsedMillis,
          'elapsedMillis',
          'must be >= 0',
        );
      }

      timeMillis += event.elapsedMillis;
      final decision = _policy.evaluate(event.input);

      final ackMillis =
          (_baseAckIntervalMillis * decision.ackIntervalMultiplier).round();

      final rtoScale = decision.shouldPauseSending
          ? 1.5
          : (decision.ackIntervalMultiplier > 1.0 ? 1.2 : 1.0);

      snapshots.add(
        UdtTransitionSnapshot(
          timeMillis: timeMillis,
          decision: decision,
          recommendedAckIntervalMillis: ackMillis < 1 ? 1 : ackMillis,
          recommendedRtoScale: rtoScale,
        ),
      );
    }

    return snapshots;
  }
}
