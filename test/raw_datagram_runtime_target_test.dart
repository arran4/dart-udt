import 'dart:io';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('raw datagram target requires bound socket before connect', () async {
    final target = UdtRawDatagramRuntimeTarget(
      ipv4RemoteAddress: InternetAddress.loopbackIPv4,
      remotePort: 9000,
    );

    expect(
      () => target.connect(UdtEndpointFamily.ipv4),
      throwsA(isA<StateError>()),
    );
  });

  test('raw datagram target validates remote endpoint configuration', () async {
    final target = UdtRawDatagramRuntimeTarget();

    expect(
      () => target.connect(UdtEndpointFamily.ipv6),
      throwsA(isA<StateError>()),
    );
  });

  test('raw datagram target reports unsupported buffer option setters', () {
    final target = UdtRawDatagramRuntimeTarget();

    expect(
      () => target.setReceiveBufferBytes(1024),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => target.setSendBufferBytes(1024),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
