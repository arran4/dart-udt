import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _ExecutionFakeTarget implements UdtSocketRuntimeTarget {
  _ExecutionFakeTarget({this.failFirst = false, this.alwaysFail = false});

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

void main() {
  const plan = UdtSocketRuntimePlan(
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

  test('executor binds first successful plan', () async {
    const executor = UdtSocketRuntimeExecutor();
    final target = _ExecutionFakeTarget();

    final report = await executor.executeBindPlan(
      target: target,
      runtimePlan: plan,
    );

    expect(report.isBound, isTrue);
    expect(report.selectedPlan, isNotNull);
    expect(report.selectedPlan!.family, UdtBindFamily.ipv6);
    expect(report.attempts, hasLength(1));
    expect(report.attempts.first.success, isTrue);
  });

  test('executor falls back to second plan when first bind fails', () async {
    const executor = UdtSocketRuntimeExecutor();
    final target = _ExecutionFakeTarget(failFirst: true);

    final report = await executor.executeBindPlan(
      target: target,
      runtimePlan: plan,
    );

    expect(report.isBound, isTrue);
    expect(report.selectedPlan!.family, UdtBindFamily.ipv4);
    expect(report.attempts, hasLength(2));
    expect(report.attempts.first.success, isFalse);
    expect(report.attempts.last.success, isTrue);
  });

  test('executor returns unbound report when all binds fail', () async {
    const executor = UdtSocketRuntimeExecutor();
    final target = _ExecutionFakeTarget(alwaysFail: true);

    final report = await executor.executeBindPlan(
      target: target,
      runtimePlan: plan,
    );

    expect(report.isBound, isFalse);
    expect(report.selectedPlan, isNull);
    expect(report.attempts, hasLength(2));
    expect(
      report.attempts.every((attempt) => attempt.success == false),
      isTrue,
    );
  });

  test(
    'executor short-circuits when runtime plan has blocking failure',
    () async {
      final blockingPlan = UdtSocketRuntimePlan(
        bindPlans: plan.bindPlans,
        applyReport: UdtSocketOptionApplicationReport([
          UdtSocketOptionApplyResult(
            key: UdtSocketOptionKey.ipv6Only,
            value: true,
            status: UdtSocketOptionApplyStatus.failedRequired,
            reason: 'required failure',
          ),
        ]),
      );

      const executor = UdtSocketRuntimeExecutor();
      final target = _ExecutionFakeTarget();

      final report = await executor.executeBindPlan(
        target: target,
        runtimePlan: blockingPlan,
      );

      expect(report.isBound, isFalse);
      expect(report.attempts, isEmpty);
    },
  );
}
