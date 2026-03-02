/// Deterministic random source for network impairment simulation.
abstract interface class UdtRandomSource {
  double nextDouble();
}

final class UdtSeededRandomSource implements UdtRandomSource {
  UdtSeededRandomSource(this._seed);

  final int _seed;

  int _state = 0;

  int get _nextState {
    final initial = _state == 0 ? _seed : _state;
    _state = (1664525 * initial + 1013904223) & 0x7fffffff;
    return _state;
  }

  @override
  double nextDouble() {
    return _nextState / 0x7fffffff;
  }
}

final class UdtImpairmentInput {
  const UdtImpairmentInput({
    required this.sequence,
    required this.baseDelayMillis,
  });

  final int sequence;
  final int baseDelayMillis;
}

final class UdtImpairmentConfig {
  const UdtImpairmentConfig({
    this.lossRate = 0.0,
    this.reorderRate = 0.0,
    this.maxJitterMillis = 0,
  });

  final double lossRate;
  final double reorderRate;
  final int maxJitterMillis;
}

final class UdtImpairmentOutcome {
  const UdtImpairmentOutcome({
    required this.sequence,
    required this.dropped,
    required this.delayMillis,
    required this.reordered,
  });

  final int sequence;
  final bool dropped;
  final int delayMillis;
  final bool reordered;
}

/// Deterministic latency/loss/reordering simulator for reproducible tests.
final class UdtLatencyLossSimulator {
  UdtLatencyLossSimulator({UdtRandomSource? random})
      : random = random ?? UdtSeededRandomSource(1337);

  final UdtRandomSource random;

  List<UdtImpairmentOutcome> simulate({
    required UdtImpairmentConfig config,
    required List<UdtImpairmentInput> packets,
  }) {
    _validateConfig(config);

    final outcomes = <UdtImpairmentOutcome>[];
    for (final packet in packets) {
      if (packet.baseDelayMillis < 0) {
        throw ArgumentError.value(
          packet.baseDelayMillis,
          'baseDelayMillis',
          'must be >= 0',
        );
      }

      final dropped = random.nextDouble() < config.lossRate;
      final reorder = !dropped && random.nextDouble() < config.reorderRate;
      final jitter = config.maxJitterMillis == 0
          ? 0
          : (random.nextDouble() * config.maxJitterMillis).round();

      outcomes.add(
        UdtImpairmentOutcome(
          sequence: packet.sequence,
          dropped: dropped,
          delayMillis: packet.baseDelayMillis + jitter,
          reordered: reorder,
        ),
      );
    }

    return outcomes;
  }

  void _validateConfig(UdtImpairmentConfig config) {
    if (config.lossRate < 0 || config.lossRate > 1) {
      throw ArgumentError.value(
        config.lossRate,
        'lossRate',
        'must be in [0, 1]',
      );
    }
    if (config.reorderRate < 0 || config.reorderRate > 1) {
      throw ArgumentError.value(
        config.reorderRate,
        'reorderRate',
        'must be in [0, 1]',
      );
    }
    if (config.maxJitterMillis < 0) {
      throw ArgumentError.value(
        config.maxJitterMillis,
        'maxJitterMillis',
        'must be >= 0',
      );
    }
  }
}
