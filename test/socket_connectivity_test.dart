import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _FakeConnectTarget implements UdtSocketConnectTarget {
  _FakeConnectTarget({this.failIpv6 = false, this.failIpv4 = false});

  final bool failIpv6;
  final bool failIpv4;

  @override
  Future<void> connect(UdtEndpointFamily family) async {
    if (family == UdtEndpointFamily.ipv6 && failIpv6) {
      throw StateError('ipv6 connect failed');
    }
    if (family == UdtEndpointFamily.ipv4 && failIpv4) {
      throw StateError('ipv4 connect failed');
    }
  }
}

void main() {
  test('connect planner emits dual-stack family order for ipv6 dual-stack bind', () {
    const planner = UdtSocketConnectPlanner();
    const bindPlan = UdtBindPlan(
      family: UdtBindFamily.ipv6,
      dualStack: true,
      requireIpv6OnlyFalse: true,
      reason: 'dual-stack bind',
    );

    final plans = planner.planFromBind(bindPlan);
    expect(plans, hasLength(2));
    expect(plans.first.family, UdtEndpointFamily.ipv6);
    expect(plans.last.family, UdtEndpointFamily.ipv4);
  });

  test('connect planner emits ipv4-only strategy for ipv4 bind', () {
    const planner = UdtSocketConnectPlanner();
    const bindPlan = UdtBindPlan(
      family: UdtBindFamily.ipv4,
      dualStack: false,
      requireIpv6OnlyFalse: false,
      reason: 'ipv4 bind',
    );

    final plans = planner.planFromBind(bindPlan);
    expect(plans, hasLength(1));
    expect(plans.single.family, UdtEndpointFamily.ipv4);
  });

  test('connect executor falls back from ipv6 to ipv4', () async {
    const planner = UdtSocketConnectPlanner();
    const bindPlan = UdtBindPlan(
      family: UdtBindFamily.ipv6,
      dualStack: true,
      requireIpv6OnlyFalse: true,
      reason: 'dual-stack',
    );
    final plans = planner.planFromBind(bindPlan);

    const executor = UdtSocketConnectExecutor();
    final target = _FakeConnectTarget(failIpv6: true);

    final report = await executor.execute(target: target, plans: plans);
    expect(report.isConnected, isTrue);
    expect(report.selectedPlan, isNotNull);
    expect(report.selectedPlan!.family, UdtEndpointFamily.ipv4);
    expect(report.attempts, hasLength(2));
    expect(report.attempts.first.success, isFalse);
    expect(report.attempts.last.success, isTrue);
  });

  test('connect executor reports unconnected when all plans fail', () async {
    const planner = UdtSocketConnectPlanner();
    const bindPlan = UdtBindPlan(
      family: UdtBindFamily.ipv6,
      dualStack: true,
      requireIpv6OnlyFalse: true,
      reason: 'dual-stack',
    );

    const executor = UdtSocketConnectExecutor();
    final target = _FakeConnectTarget(failIpv6: true, failIpv4: true);

    final report = await executor.execute(
      target: target,
      plans: planner.planFromBind(bindPlan),
    );

    expect(report.isConnected, isFalse);
    expect(report.selectedPlan, isNull);
    expect(report.attempts, hasLength(2));
  });
}
