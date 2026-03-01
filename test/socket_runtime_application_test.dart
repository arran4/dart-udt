import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _FakeRuntimeTarget implements UdtSocketRuntimeTarget {
  _FakeRuntimeTarget({this.failFirst = false, this.alwaysFail = false});

  final bool failFirst;
  final bool alwaysFail;
  int _bindCount = 0;

  @override
  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {
    _bindCount++;
    if (alwaysFail || (failFirst && _bindCount == 1)) {
      throw StateError('bind failed $_bindCount');
    }
  }

  @override
  Future<void> close() async {}
}

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
  const dualStackPlan = UdtSocketRuntimePlan(
    bindPlans: [
      UdtBindPlan(
        family: UdtBindFamily.ipv6,
        dualStack: true,
        requireIpv6OnlyFalse: true,
        reason: 'primary',
      ),
      UdtBindPlan(
        family: UdtBindFamily.ipv4,
        dualStack: false,
        requireIpv6OnlyFalse: false,
        reason: 'fallback',
      ),
    ],
    applyReport: UdtSocketOptionApplicationReport([]),
  );

  test('applier logs bind fallback and succeeds on second plan', () async {
    const applier = UdtSocketRuntimeApplier();
    final target = _FakeRuntimeTarget(failFirst: true);

    final report = await applier.apply(
      runtimePlan: dualStackPlan,
      runtimeTarget: target,
    );

    expect(report.execution.isBound, isTrue);
    expect(report.execution.selectedPlan!.family, UdtBindFamily.ipv4);
    expect(report.logs.any((line) => line.contains('bind fallback')), isTrue);
  });

  test('applier logs connect fallback and succeeds on ipv4 connect', () async {
    const applier = UdtSocketRuntimeApplier();
    final runtimeTarget = _FakeRuntimeTarget();
    final connectTarget = _FakeConnectTarget(failIpv6: true);

    final report = await applier.apply(
      runtimePlan: dualStackPlan,
      runtimeTarget: runtimeTarget,
      connectTarget: connectTarget,
    );

    expect(report.execution.isBound, isTrue);
    expect(report.connect, isNotNull);
    expect(report.connect!.isConnected, isTrue);
    expect(report.connect!.selectedPlan!.family, UdtEndpointFamily.ipv4);
    expect(report.logs.any((line) => line.contains('connect fallback')), isTrue);
  });

  test('applier logs hard bind failure', () async {
    const applier = UdtSocketRuntimeApplier();
    final target = _FakeRuntimeTarget(alwaysFail: true);

    final report = await applier.apply(
      runtimePlan: dualStackPlan,
      runtimeTarget: target,
    );

    expect(report.execution.isBound, isFalse);
    expect(report.logs.any((line) => line.contains('bind failed')), isTrue);
  });
}
