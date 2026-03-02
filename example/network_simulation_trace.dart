import 'package:dart_udt/dart_udt.dart';

void main() {
  final simulator = UdtLatencyLossSimulator(
    random: UdtSeededRandomSource(2024),
  );

  const config = UdtImpairmentConfig(
    lossRate: 0.2,
    reorderRate: 0.35,
    maxJitterMillis: 12,
  );

  final outcomes = simulator.simulate(
    config: config,
    packets: List.generate(
      8,
      (index) => UdtImpairmentInput(sequence: index + 1, baseDelayMillis: 10),
    ),
  );

  for (final outcome in outcomes) {
    print(
      'seq=${outcome.sequence} dropped=${outcome.dropped} '
      'reordered=${outcome.reordered} delayMs=${outcome.delayMillis}',
    );
  }
}
