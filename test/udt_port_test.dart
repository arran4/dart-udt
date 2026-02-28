import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('status reports scaffold state', () {
    const scaffold = UdtPortScaffold();
    expect(scaffold.status(), contains('scaffold'));
  });

  test('module map includes canonical packet target', () {
    const scaffold = UdtPortScaffold();
    expect(
      scaffold.moduleTargets()[UdtModule.packet],
      equals('lib/src/udt_port/protocol/'),
    );
  });

  test('data packet header round-trips with deterministic bytes', () {
    final header = UdtPacketHeader.data(
      sequenceNumber: 0x01234567,
      timestamp: 0x89ABCDEF,
      destinationSocketId: 0x10203040,
    );

    final bytes = header.toBytes();
    expect(
      bytes,
      Uint8List.fromList([
        0x01,
        0x23,
        0x45,
        0x67,
        0x00,
        0x00,
        0x00,
        0x00,
        0x89,
        0xAB,
        0xCD,
        0xEF,
        0x10,
        0x20,
        0x30,
        0x40,
      ]),
    );

    final reparsed = UdtPacketHeader.parse(bytes);
    expect(reparsed.isControl, isFalse);
    expect(reparsed.sequenceNumber, equals(0x01234567));
    expect(reparsed.timestamp, equals(0x89ABCDEF));
    expect(reparsed.destinationSocketId, equals(0x10203040));
  });

  test('control packet header round-trips with deterministic bytes', () {
    final header = UdtPacketHeader.control(
      controlType: 0x1234,
      controlReserved: 0xABCD,
      additionalInfo: 0x10203040,
      timestamp: 0x55667788,
      destinationSocketId: 0xDEADBEEF,
    );

    final bytes = header.toBytes();
    expect(
      bytes,
      Uint8List.fromList([
        0x92,
        0x34,
        0xAB,
        0xCD,
        0x10,
        0x20,
        0x30,
        0x40,
        0x55,
        0x66,
        0x77,
        0x88,
        0xDE,
        0xAD,
        0xBE,
        0xEF,
      ]),
    );

    final reparsed = UdtPacketHeader.parse(bytes);
    expect(reparsed.isControl, isTrue);
    expect(reparsed.controlType, equals(0x1234));
    expect(reparsed.controlReserved, equals(0xABCD));
    expect(reparsed.additionalInfo, equals(0x10203040));
    expect(reparsed.timestamp, equals(0x55667788));
    expect(reparsed.destinationSocketId, equals(0xDEADBEEF));
  });

  test('invalid payload size throws', () {
    expect(
      () => UdtPacketHeader.parse(Uint8List(8)),
      throwsA(isA<ArgumentError>()),
    );
  });
}
