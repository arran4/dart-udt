import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('simulator produces reproducible outcomes with same seed', () {
    const config = UdtImpairmentConfig(
      lossRate: 0.25,
      reorderRate: 0.4,
      maxJitterMillis: 15,
    );

    final packets = List.generate(
      6,
      (index) => UdtImpairmentInput(sequence: index + 1, baseDelayMillis: 10),
    );

    const simA = UdtLatencyLossSimulator(random: UdtSeededRandomSource(42));
    const simB = UdtLatencyLossSimulator(random: UdtSeededRandomSource(42));

    final outcomesA = simA.simulate(config: config, packets: packets);
    final outcomesB = simB.simulate(config: config, packets: packets);

    expect(outcomesA.length, outcomesB.length);
    for (var i = 0; i < outcomesA.length; i++) {
      expect(outcomesA[i].sequence, outcomesB[i].sequence);
      expect(outcomesA[i].dropped, outcomesB[i].dropped);
      expect(outcomesA[i].reordered, outcomesB[i].reordered);
      expect(outcomesA[i].delayMillis, outcomesB[i].delayMillis);
    }
  });

  test('simulator bounds jitter and preserves minimum base delay', () {
    const simulator = UdtLatencyLossSimulator(random: UdtSeededRandomSource(99));
    const config = UdtImpairmentConfig(lossRate: 0, reorderRate: 0, maxJitterMillis: 20);
    final packets = List.generate(
      10,
      (index) => UdtImpairmentInput(sequence: index, baseDelayMillis: 7),
    );

    final outcomes = simulator.simulate(config: config, packets: packets);
    expect(outcomes.every((o) => o.dropped == false), isTrue);
    expect(outcomes.every((o) => o.delayMillis >= 7), isTrue);
    expect(outcomes.every((o) => o.delayMillis <= 27), isTrue);
  });

  test('simulator validates config and packet delay inputs', () {
    const simulator = UdtLatencyLossSimulator();

    expect(
      () => simulator.simulate(
        config: const UdtImpairmentConfig(lossRate: -0.1),
        packets: const [],
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => simulator.simulate(
        config: const UdtImpairmentConfig(reorderRate: 1.1),
        packets: const [],
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => simulator.simulate(
        config: const UdtImpairmentConfig(maxJitterMillis: -1),
        packets: const [],
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => simulator.simulate(
        config: const UdtImpairmentConfig(),
        packets: const [UdtImpairmentInput(sequence: 1, baseDelayMillis: -5)],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
