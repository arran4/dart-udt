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
}
