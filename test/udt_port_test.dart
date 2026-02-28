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

  test('typed packet container round-trips header and payload', () {
    final packet = UdtPacket(
      header: UdtPacketHeader.data(
        sequenceNumber: 0x01020304,
        timestamp: 0x11223344,
        destinationSocketId: 0x55667788,
      ),
      payload: Uint8List.fromList([1, 2, 3, 4]),
    );

    final reparsed = UdtPacket.parse(packet.toBytes());
    expect(reparsed.header.sequenceNumber, equals(0x01020304));
    expect(reparsed.header.timestamp, equals(0x11223344));
    expect(reparsed.header.destinationSocketId, equals(0x55667788));
    expect(reparsed.payload, Uint8List.fromList([1, 2, 3, 4]));
  });

  test('handshake round-trips with deterministic byte layout', () {
    final handshake = UdtHandshake(
      version: 4,
      socketType: 1,
      initialSequenceNumber: 0x12345678,
      maximumSegmentSize: 1500,
      flightFlagSize: 25600,
      requestType: -1,
      socketId: 42,
      cookie: 0x10203040,
      peerIp: const [0x0A000001, 0, 0, 0],
    );

    final bytes = handshake.toBytes();
    expect(bytes.lengthInBytes, equals(UdtHandshake.contentSize));
    expect(
      bytes,
      Uint8List.fromList([
        0x00, 0x00, 0x00, 0x04,
        0x00, 0x00, 0x00, 0x01,
        0x12, 0x34, 0x56, 0x78,
        0x00, 0x00, 0x05, 0xDC,
        0x00, 0x00, 0x64, 0x00,
        0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x00, 0x00, 0x2A,
        0x10, 0x20, 0x30, 0x40,
        0x0A, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]),
    );

    final reparsed = UdtHandshake.parse(bytes);
    expect(reparsed.version, equals(4));
    expect(reparsed.socketType, equals(1));
    expect(reparsed.initialSequenceNumber, equals(0x12345678));
    expect(reparsed.maximumSegmentSize, equals(1500));
    expect(reparsed.flightFlagSize, equals(25600));
    expect(reparsed.requestType, equals(-1));
    expect(reparsed.socketId, equals(42));
    expect(reparsed.cookie, equals(0x10203040));
    expect(reparsed.peerIp, equals(const [0x0A000001, 0, 0, 0]));
  });

  test('control handshake packet round-trips through typed wrapper', () {
    final handshake = UdtHandshake(
      version: 5,
      socketType: 2,
      initialSequenceNumber: 0x11111111,
      maximumSegmentSize: 1400,
      flightFlagSize: 8192,
      requestType: 1,
      socketId: 300,
      cookie: 0x7F7F7F7F,
      peerIp: const [0x7F000001, 0, 0, 0],
    );
    final controlPacket = UdtControlPacket.handshake(
      handshake: handshake,
      timestamp: 100,
      destinationSocketId: 200,
    );

    final reparsed = UdtControlPacket.parse(
      UdtPacket.parse(controlPacket.toPacket().toBytes()),
    );

    expect(reparsed.type, equals(UdtControlType.handshake));
    expect(reparsed.parseHandshake().socketId, equals(300));
  });

  test('ACK control packet keeps sequence and optional metrics', () {
    final packet = UdtControlPacket.ack(
      ackSequenceNumber: 77,
      info: const UdtAckControlInfo(
        receivedSequenceNumber: 1200,
        optionalMetrics: [50, 7, 4096, 64, 900],
      ),
      timestamp: 10,
      destinationSocketId: 11,
    );

    final reparsed = UdtControlPacket.parse(UdtPacket.parse(packet.toPacket().toBytes()));
    expect(reparsed.type, equals(UdtControlType.ack));
    expect(reparsed.header.additionalInfo, equals(77));
    expect(reparsed.parseAckControlInfo().receivedSequenceNumber, equals(1200));
    expect(reparsed.parseAckControlInfo().optionalMetrics, equals([50, 7, 4096, 64, 900]));
  });

  test('keep-alive and ACK2 control packets carry no payload bytes', () {
    final keepAlive = UdtControlPacket.keepAlive(
      timestamp: 12,
      destinationSocketId: 13,
    );
    final ack2 = UdtControlPacket.ack2(
      ackSequenceNumber: 99,
      timestamp: 14,
      destinationSocketId: 15,
    );

    expect(keepAlive.controlInformation, isEmpty);
    expect(ack2.controlInformation, isEmpty);
    expect(ack2.header.additionalInfo, equals(99));
  });

  test('NAK and message drop request control payloads are deterministic', () {
    final nak = UdtControlPacket.nak(
      lossList: [0x10000001, 0x00000042],
      timestamp: 21,
      destinationSocketId: 22,
    );
    final drop = UdtControlPacket.messageDropRequest(
      messageId: 123,
      info: const UdtMessageDropRequestControlInfo(
        firstSequenceNumber: 500,
        lastSequenceNumber: 700,
      ),
      timestamp: 23,
      destinationSocketId: 24,
    );

    final reparsedNak = UdtControlPacket.parse(UdtPacket.parse(nak.toPacket().toBytes()));
    final reparsedDrop = UdtControlPacket.parse(UdtPacket.parse(drop.toPacket().toBytes()));

    expect(reparsedNak.parseNakLossList(), equals([0x10000001, 0x00000042]));
    expect(reparsedDrop.header.additionalInfo, equals(123));
    expect(reparsedDrop.parseMessageDropRequest().firstSequenceNumber, equals(500));
    expect(reparsedDrop.parseMessageDropRequest().lastSequenceNumber, equals(700));
  });

  test('invalid payload size throws', () {
    expect(
      () => UdtPacketHeader.parse(Uint8List(8)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('invalid handshake size throws', () {
    expect(
      () => UdtHandshake.parse(Uint8List(8)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('invalid ACK payload throws', () {
    expect(
      () => UdtAckControlInfo.parse(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ArgumentError>()),
    );
  });
}
