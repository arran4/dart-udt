import 'dart:io';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('planner validates positive socket buffer sizes', () {
    const planner = UdtSocketOptionPlanner(platformOverride: 'linux');

    expect(
      () => planner.plan(mode: UdtIpMode.ipv4Only, receiveBufferBytes: 0),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => planner.plan(mode: UdtIpMode.ipv4Only, sendBufferBytes: 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('planner emits IPv6-only required option for ipv6Only mode', () {
    const planner = UdtSocketOptionPlanner(platformOverride: 'linux');
    final options = planner.plan(mode: UdtIpMode.ipv6Only);

    final ipv6Only = options
        .where((option) => option.key == UdtSocketOptionKey.ipv6Only)
        .toList();
    expect(ipv6Only, hasLength(1));
    expect(ipv6Only.single.value, isTrue);
    expect(ipv6Only.single.required, isTrue);
  });

  test('planner handles dual-stack with optional IPv6-only toggle', () {
    const linuxPlanner = UdtSocketOptionPlanner(platformOverride: 'linux');
    final linuxOptions = linuxPlanner.plan(mode: UdtIpMode.dualStack);

    final linuxReusePort = linuxOptions.singleWhere(
      (option) => option.key == UdtSocketOptionKey.reusePort,
    );
    expect(linuxReusePort.value, isTrue);

    const windowsPlanner = UdtSocketOptionPlanner(platformOverride: 'windows');
    final windowsOptions = windowsPlanner.plan(mode: UdtIpMode.dualStack);

    final windowsReusePort = windowsOptions.singleWhere(
      (option) => option.key == UdtSocketOptionKey.reusePort,
    );
    expect(windowsReusePort.value, isFalse);

    final ipv6OnlyOptions = windowsOptions
        .where((option) => option.key == UdtSocketOptionKey.ipv6Only)
        .toList();
    expect(ipv6OnlyOptions.length, greaterThanOrEqualTo(1));
    expect(ipv6OnlyOptions.last.value, isFalse);
  });

  test('dual-stack matrix includes all platform/mode combinations', () {
    final rows = buildUdtDualStackMatrix();

    expect(rows, hasLength(9));

    final windowsDual = rows.singleWhere(
      (row) => row.platform == 'windows' && row.mode == UdtIpMode.dualStack,
    );
    expect(windowsDual.expectedBindFamilies, {
      InternetAddressType.IPv4,
      InternetAddressType.IPv6,
    });
    expect(windowsDual.notes, contains('Windows'));
  });
}
