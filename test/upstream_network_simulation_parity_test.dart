import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test(
    'upstream-style network simulation trace matches deterministic fixture',
    () {
      const simulator = UdtLatencyLossSimulator(
        random: UdtSeededRandomSource(2024),
      );

      const config = UdtImpairmentConfig(
        lossRate: 0.2,
        reorderRate: 0.35,
        maxJitterMillis: 12,
      );

      final packets = List.generate(
        8,
        (index) => UdtImpairmentInput(sequence: index + 1, baseDelayMillis: 10),
      );

      final outcomes = simulator.simulate(config: config, packets: packets);

      const expected =
          <(int sequence, bool dropped, bool reordered, int delay)>[
            (1, true, false, 19),
            (2, false, true, 17),
            (3, false, false, 20),
            (4, false, false, 13),
            (5, false, false, 19),
            (6, false, false, 15),
            (7, true, false, 15),
            (8, false, false, 15),
          ];

      expect(outcomes, hasLength(expected.length));
      for (var i = 0; i < expected.length; i++) {
        expect(outcomes[i].sequence, expected[i].$1);
        expect(outcomes[i].dropped, expected[i].$2);
        expect(outcomes[i].reordered, expected[i].$3);
        expect(outcomes[i].delayMillis, expected[i].$4);
      }
    },
  );
}
