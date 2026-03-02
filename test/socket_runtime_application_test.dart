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
  _FakeConnectTarget({this.failIpv6 = false});

  final bool failIpv6;

  @override
  Future<void> connect(UdtEndpointFamily family) async {
    if (family == UdtEndpointFamily.ipv6 && failIpv6) {
      throw StateError('ipv6 connect failed');
    }
  }
}

final class _ProfileFakeTarget
    implements
        UdtSocketRuntimeTarget,
        UdtSocketConnectTarget,
        UdtSocketOptionTarget {
  final List<String> appliedOptions = <String>[];
  final List<UdtEndpointFamily> connectAttempts = <UdtEndpointFamily>[];

  @override
  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> connect(UdtEndpointFamily family) async {
    connectAttempts.add(family);
  }

  @override
  Future<void> setIpv6Only(bool enabled) async {
    appliedOptions.add('ipv6Only:$enabled');
  }

  @override
  Future<void> setReceiveBufferBytes(int bytes) async {
    appliedOptions.add('rcv:$bytes');
  }

  @override
  Future<void> setReuseAddress(bool enabled) async {
    appliedOptions.add('reuseAddress:$enabled');
  }

  @override
  Future<void> setReusePort(bool enabled) async {
    appliedOptions.add('reusePort:$enabled');
  }

  @override
  Future<void> setSendBufferBytes(int bytes) async {
    appliedOptions.add('snd:$bytes');
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

    expect(report.runtimePlan, same(dualStackPlan));
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
    expect(
      report.logs.any((line) => line.contains('connect fallback')),
      isTrue,
    );
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

  test(
    'applier can build runtime plan from profile and apply in one call',
    () async {
      const builder = UdtCompatibilityProfileBuilder();
      final profile = builder.build(
        platform: 'linux',
        ipMode: UdtIpMode.dualStack,
        ipv6: true,
        mobileInput: const UdtMobilePolicyInput(
          appState: UdtMobileAppState.foreground,
          networkType: UdtMobileNetworkType.wifi,
          allowBackgroundNetwork: true,
          batterySaverEnabled: false,
        ),
      );

      const applier = UdtSocketRuntimeApplier();
      final target = _ProfileFakeTarget();

      final report = await applier.applyProfile(
        profile: profile,
        optionTarget: target,
        runtimeTarget: target,
        connectTarget: target,
      );

      expect(report.runtimePlan.bindPlans, isNotEmpty);
      expect(report.runtimePlan.applyReport.results, isNotEmpty);
      expect(target.appliedOptions, isNotEmpty);
      expect(target.connectAttempts, isNotEmpty);
    },
  );
}
