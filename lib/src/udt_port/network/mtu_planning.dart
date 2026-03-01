/// Deterministic MTU planning input for section-4 compatibility work.
final class UdtMtuPlanningInput {
  const UdtMtuPlanningInput({
    required this.platform,
    required this.ipv6,
    this.pathMtuHint,
  });

  final String platform;
  final bool ipv6;
  final int? pathMtuHint;
}

final class UdtMtuPlanningDecision {
  const UdtMtuPlanningDecision({
    required this.recommendedMtu,
    required this.recommendedPayloadSize,
    required this.headerOverhead,
    required this.reason,
  });

  final int recommendedMtu;
  final int recommendedPayloadSize;
  final int headerOverhead;
  final String reason;
}

/// Deterministic MTU/path-MTU planner for Linux/macOS/Windows guidance.
final class UdtMtuPlanner {
  const UdtMtuPlanner();

  UdtMtuPlanningDecision plan(UdtMtuPlanningInput input) {
    final platform = input.platform.toLowerCase();

    final defaultMtu = switch (platform) {
      'windows' => 1400,
      'macos' => 1500,
      _ => 1500,
    };

    final boundedHint = _normalizePathMtuHint(input.pathMtuHint);
    final mtu = boundedHint ?? defaultMtu;

    final ipOverhead = input.ipv6 ? 40 : 20;
    const udpOverhead = 8;
    const udtHeaderOverhead = 16;
    final totalOverhead = ipOverhead + udpOverhead + udtHeaderOverhead;

    final payload = mtu - totalOverhead;
    final safePayload = payload > 0 ? payload : 1;

    return UdtMtuPlanningDecision(
      recommendedMtu: mtu,
      recommendedPayloadSize: safePayload,
      headerOverhead: totalOverhead,
      reason: boundedHint != null
          ? 'Using bounded path-MTU hint with protocol overhead subtraction.'
          : 'Using platform default MTU baseline with protocol overhead subtraction.',
    );
  }

  int? _normalizePathMtuHint(int? hint) {
    if (hint == null) {
      return null;
    }

    if (hint < 576) {
      return 576;
    }

    if (hint > 9000) {
      return 9000;
    }

    return hint;
  }
}
