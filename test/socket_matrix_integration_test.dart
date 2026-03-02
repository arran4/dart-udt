import 'dart:io';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _MatrixFakeTarget
    implements
        UdtSocketOptionTarget,
        UdtSocketRuntimeTarget,
        UdtSocketConnectTarget {
  _MatrixFakeTarget({
    required Set<InternetAddressType> supportedFamilies,
    this.failDualStackIpv6 = false,
  }) : _supportedFamilies = supportedFamilies;

  final Set<InternetAddressType> _supportedFamilies;
  final bool failDualStackIpv6;

  @override
  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {
    final attempted = switch (family) {
      UdtBindFamily.ipv4 => InternetAddressType.IPv4,
      UdtBindFamily.ipv6 => InternetAddressType.IPv6,
    };

    if (!_supportedFamilies.contains(attempted)) {
      throw StateError('family $family unsupported');
    }

    if (family == UdtBindFamily.ipv6 && dualStack && failDualStackIpv6) {
      throw StateError('dual-stack ipv6 bind unsupported');
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> connect(UdtEndpointFamily family) async {
    final attempted = switch (family) {
      UdtEndpointFamily.ipv4 => InternetAddressType.IPv4,
      UdtEndpointFamily.ipv6 => InternetAddressType.IPv6,
    };

    if (!_supportedFamilies.contains(attempted)) {
      throw StateError('connect family $family unsupported');
    }
  }

  @override
  Future<void> setIpv6Only(bool enabled) async {}

  @override
  Future<void> setReceiveBufferBytes(int bytes) async {}

  @override
  Future<void> setReuseAddress(bool enabled) async {}

  @override
  Future<void> setReusePort(bool enabled) async {}

  @override
  Future<void> setSendBufferBytes(int bytes) async {}
}

void main() {
  test(
    'matrix rows are wired into runtime planner/executor expectations',
    () async {
      const harness = UdtSocketMatrixIntegrationHarness();

      for (final row in buildUdtDualStackMatrix()) {
        final target = _MatrixFakeTarget(
          supportedFamilies: row.expectedBindFamilies,
        );

        final result = await harness.executeRow(
          row: row,
          optionTarget: target,
          runtimeTarget: target,
          connectTarget: target,
        );

        expect(result.runtimePlan.hasBlockingFailure, isFalse);
        expect(result.executionReport.isBound, isTrue);
        expect(result.selectedFamily, isNotNull);
        expect(result.plannedBindFamilies, row.expectedBindFamilies);
        expect(result.plannedConnectFamilies, row.expectedBindFamilies);
        expect(row.expectedBindFamilies, contains(result.selectedFamily));
        expect(
          row.expectedBindFamilies.containsAll(result.attemptedFamilies),
          isTrue,
        );
        expect(result.connectReport.isConnected, isTrue);
        if (result.connectReport.selectedPlan != null) {
          expect(
            row.expectedBindFamilies,
            contains(result.connectReport.selectedPlan!.addressType),
          );
        }
      }
    },
  );

  test(
    'dual-stack row falls back to ipv4 while respecting matrix families',
    () async {
      const harness = UdtSocketMatrixIntegrationHarness();

      final row = buildUdtDualStackMatrix().singleWhere(
        (row) => row.platform == 'linux' && row.mode == UdtIpMode.dualStack,
      );

      final target = _MatrixFakeTarget(
        supportedFamilies: row.expectedBindFamilies,
        failDualStackIpv6: true,
      );

      final result = await harness.executeRow(
        row: row,
        optionTarget: target,
        runtimeTarget: target,
        connectTarget: target,
      );

      expect(result.executionReport.isBound, isTrue);
      expect(result.selectedFamily, InternetAddressType.IPv4);
      expect(result.attemptedFamilies, {
        InternetAddressType.IPv4,
        InternetAddressType.IPv6,
      });
      expect(
        row.expectedBindFamilies.containsAll(result.attemptedFamilies),
        isTrue,
      );
      expect(result.connectPlans.first.family, UdtEndpointFamily.ipv4);
      expect(result.connectReport.isConnected, isTrue);
      expect(result.connectReport.selectedPlan!.family, UdtEndpointFamily.ipv4);
    },
  );
}
