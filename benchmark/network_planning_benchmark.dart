import 'dart:math';

import 'package:dart_udt/dart_udt.dart';

void main() {
  final stopwatch = Stopwatch()..start();

  const planner = UdtSocketOptionPlanner(platformOverride: 'linux');
  const mtuPlanner = UdtMtuPlanner();
  final simulator = UdtLatencyLossSimulator(random: UdtSeededRandomSource(7));

  var payloadSum = 0;
  for (var i = 0; i < 20000; i++) {
    final mode = UdtIpMode.values[i % UdtIpMode.values.length];
    final options = planner.plan(mode: mode);
    payloadSum += options.length;

    final mtu = mtuPlanner.plan(
      UdtMtuPlanningInput(
        platform: i.isEven ? 'linux' : 'windows',
        ipv6: i % 3 == 0,
        pathMtuHint: 1200 + (i % 400),
      ),
    );
    payloadSum += mtu.recommendedPayloadSize;

    final outcomes = simulator.simulate(
      config: const UdtImpairmentConfig(
        lossRate: 0.01,
        reorderRate: 0.02,
        maxJitterMillis: 10,
      ),
      packets: [UdtImpairmentInput(sequence: i, baseDelayMillis: 5 + (i % 5))],
    );
    payloadSum += outcomes.first.delayMillis;
  }

  stopwatch.stop();
  final micros = max(stopwatch.elapsedMicroseconds, 1);
  final opsPerSec = (20000 * 3) / (micros / 1000000);

  print('network planning benchmark:');
  print('  iterations: 20000');
  print('  aggregate: $payloadSum');
  print('  elapsed_us: $micros');
  print('  approx_ops_per_sec: ${opsPerSec.toStringAsFixed(0)}');
}
