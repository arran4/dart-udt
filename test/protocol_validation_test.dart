import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  group('packet/header validation branches', () {
    test('packet header parse rejects invalid byte length', () {
      expect(
        () => UdtPacketHeader.parse(Uint8List(15)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('packet parse rejects shorter-than-header datagram', () {
      expect(
        () => UdtPacket.parse(Uint8List(10)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('data and control constructors validate numeric ranges', () {
      expect(
        () => UdtPacketHeader.data(
          sequenceNumber: -1,
          timestamp: 0,
          destinationSocketId: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => UdtPacketHeader.control(
          controlType: 0x8000,
          timestamp: 0,
          destinationSocketId: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('handshake validation branches', () {
    test('handshake parse rejects payload length mismatch', () {
      expect(
        () => UdtHandshake.parse(Uint8List(UdtHandshake.contentSize - 1)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handshake serialization validates peerIp constraints', () {
      const badLength = UdtHandshake(
        version: 4,
        socketType: 1,
        initialSequenceNumber: 10,
        maximumSegmentSize: 1500,
        flightFlagSize: 32,
        requestType: 1,
        socketId: 20,
        cookie: 30,
        peerIp: [1, 2, 3],
      );

      expect(() => badLength.toBytes(), throwsA(isA<ArgumentError>()));

      const badWord = UdtHandshake(
        version: 4,
        socketType: 1,
        initialSequenceNumber: 10,
        maximumSegmentSize: 1500,
        flightFlagSize: 32,
        requestType: 1,
        socketId: 20,
        cookie: 30,
        peerIp: [-1, 0, 0, 0],
      );

      expect(() => badWord.toBytes(), throwsA(isA<ArgumentError>()));
    });
  });

  group('control-packet validation and mismatch branches', () {
    test('control type lookup rejects unknown value', () {
      expect(
        () => UdtControlType.fromCode(0x1235),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ACK and message-drop payload codecs validate lengths', () {
      expect(
        () => UdtAckControlInfo.parse(Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => UdtAckControlInfo.parse(Uint8List(6)),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => UdtMessageDropRequestControlInfo.parse(Uint8List(7)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('control packet parse rejects data packet', () {
      final dataPacket = UdtPacket(
        header: UdtPacketHeader.data(
          sequenceNumber: 1,
          timestamp: 2,
          destinationSocketId: 3,
        ),
      );

      expect(
        () => UdtControlPacket.parse(dataPacket),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('typed control parsers fail on mismatched packet kind', () {
      final keepAlive = UdtControlPacket.keepAlive(
        timestamp: 5,
        destinationSocketId: 6,
      );

      expect(() => keepAlive.parseAckControlInfo(), throwsA(isA<StateError>()));
      expect(() => keepAlive.parseHandshake(), throwsA(isA<StateError>()));
      expect(
        () => keepAlive.parseMessageDropRequest(),
        throwsA(isA<StateError>()),
      );
      expect(() => keepAlive.parseNakLossList(), throwsA(isA<StateError>()));
    });

    test('NAK parser validates 4-byte aligned payload', () {
      final malformedNakPacket = UdtPacket(
        header: UdtPacketHeader.control(
          controlType: UdtControlType.nak.code,
          timestamp: 1,
          destinationSocketId: 2,
        ),
        payload: Uint8List.fromList([1, 2, 3]),
      );
      final control = UdtControlPacket.parse(malformedNakPacket);

      expect(() => control.parseNakLossList(), throwsA(isA<ArgumentError>()));
    });

    test('user-defined constructor validates extended type range', () {
      expect(
        () => UdtControlPacket.userDefined(
          extendedType: 0x10000,
          timestamp: 1,
          destinationSocketId: 2,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
