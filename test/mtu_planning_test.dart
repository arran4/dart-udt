import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('planner uses platform defaults when no path hint is provided', () {
    const planner = UdtMtuPlanner();

    final linux = planner.plan(
      const UdtMtuPlanningInput(platform: 'linux', ipv6: false),
    );
    final windows = planner.plan(
      const UdtMtuPlanningInput(platform: 'windows', ipv6: false),
    );

    expect(linux.recommendedMtu, 1500);
    expect(windows.recommendedMtu, 1400);
    expect(linux.recommendedPayloadSize, 1500 - (20 + 8 + 16));
  });

  test('planner validates platform and IP-family MTU assumptions via matrix', () {
    const planner = UdtMtuPlanner();

    const scenarios = <({String platform, bool ipv6, int expectedMtu})>[
      (platform: 'linux', ipv6: false, expectedMtu: 1500),
      (platform: 'linux', ipv6: true, expectedMtu: 1500),
      (platform: 'macos', ipv6: false, expectedMtu: 1500),
      (platform: 'macos', ipv6: true, expectedMtu: 1500),
      (platform: 'windows', ipv6: false, expectedMtu: 1400),
      (platform: 'windows', ipv6: true, expectedMtu: 1400),
    ];

    for (final scenario in scenarios) {
      final decision = planner.plan(
        UdtMtuPlanningInput(
          platform: scenario.platform,
          ipv6: scenario.ipv6,
        ),
      );

      final expectedOverhead = (scenario.ipv6 ? 40 : 20) + 8 + 16;
      expect(decision.recommendedMtu, scenario.expectedMtu);
      expect(decision.headerOverhead, expectedOverhead);
      expect(
        decision.recommendedPayloadSize,
        scenario.expectedMtu - expectedOverhead,
      );
    }
  });

  test('planner applies IPv6 overhead correctly', () {
    const planner = UdtMtuPlanner();

    final ipv4 = planner.plan(
      const UdtMtuPlanningInput(platform: 'linux', ipv6: false),
    );
    final ipv6 = planner.plan(
      const UdtMtuPlanningInput(platform: 'linux', ipv6: true),
    );

    expect(ipv6.headerOverhead - ipv4.headerOverhead, 20);
    expect(ipv6.recommendedPayloadSize, lessThan(ipv4.recommendedPayloadSize));
  });

  test('planner bounds path MTU hints', () {
    const planner = UdtMtuPlanner();

    final low = planner.plan(
      const UdtMtuPlanningInput(platform: 'linux', ipv6: false, pathMtuHint: 100),
    );
    final high = planner.plan(
      const UdtMtuPlanningInput(platform: 'linux', ipv6: false, pathMtuHint: 20000),
    );

    expect(low.recommendedMtu, 576);
    expect(high.recommendedMtu, 9000);
  });

  test('planner uses in-range path MTU hint across platforms', () {
    const planner = UdtMtuPlanner();

    for (final platform in const ['linux', 'macos', 'windows']) {
      final decision = planner.plan(
        UdtMtuPlanningInput(
          platform: platform,
          ipv6: true,
          pathMtuHint: 1280,
        ),
      );

      expect(decision.recommendedMtu, 1280);
      expect(decision.headerOverhead, 40 + 8 + 16);
      expect(decision.recommendedPayloadSize, 1280 - (40 + 8 + 16));
    }
  });
}
