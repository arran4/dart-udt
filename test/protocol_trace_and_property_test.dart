import 'dart:math';
import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  group('golden protocol traces', () {
    test('parses deterministic upstream-style control traces', () {
      final traces = <({String name, Uint8List datagram, UdtControlType type})>[
        (
          name: 'keepalive-empty',
          datagram: Uint8List.fromList([
            0x80,
            0x01,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x64,
            0x00,
            0x00,
            0x00,
            0x2A,
          ]),
          type: UdtControlType.keepAlive,
        ),
        (
          name: 'ack2-empty',
          datagram: Uint8List.fromList([
            0x80,
            0x06,
            0x00,
            0x00,
            0x00,
            0x00,
            0x01,
            0x23,
            0x00,
            0x00,
            0x00,
            0xC8,
            0x00,
            0x00,
            0x00,
            0x2A,
          ]),
          type: UdtControlType.ack2,
        ),
        (
          name: 'message-drop',
          datagram: Uint8List.fromList([
            0x80,
            0x07,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x11,
            0x00,
            0x00,
            0x00,
            0xE1,
            0x00,
            0x00,
            0x00,
            0x2A,
            0x00,
            0x00,
            0x00,
            0x64,
            0x00,
            0x00,
            0x00,
            0x78,
          ]),
          type: UdtControlType.messageDropRequest,
        ),
      ];

      for (final trace in traces) {
        final parsedPacket = UdtPacket.parse(trace.datagram);
        final control = UdtControlPacket.parse(parsedPacket);

        expect(control.type, trace.type, reason: trace.name);
        expect(
          control.toPacket().toBytes(),
          trace.datagram,
          reason: trace.name,
        );
      }
    });
  });

  group('property-style parser/state coverage', () {
    test('header and packet round-trip across seeded random values', () {
      final random = Random(0x5EED1234);

      for (var i = 0; i < 200; i++) {
        final isControl = random.nextBool();
        final header = isControl
            ? UdtPacketHeader.control(
                controlType: random.nextInt(0x8000),
                controlReserved: random.nextInt(0x10000),
                additionalInfo: random.nextInt(1 << 32),
                timestamp: random.nextInt(1 << 32),
                destinationSocketId: random.nextInt(1 << 32),
              )
            : UdtPacketHeader.data(
                sequenceNumber: random.nextInt(0x80000000),
                timestamp: random.nextInt(1 << 32),
                destinationSocketId: random.nextInt(1 << 32),
              );

        final payloadLength = random.nextInt(64);
        final payload = Uint8List.fromList(
          List<int>.generate(payloadLength, (_) => random.nextInt(256)),
        );

        final reparsed = UdtPacket.parse(
          UdtPacket(header: header, payload: payload).toBytes(),
        );

        expect(reparsed.header.toBytes(), header.toBytes());
        expect(reparsed.payload, payload);
      }
    });

    test('ack/nak timeout model agrees with reference state machine', () {
      final random = Random(20240229);
      final clock = UdtFakeClock();
      const retransmissionTimeoutMicros = 25;
      final model = UdtAckNakTimerModel(
        clock: clock,
        retransmissionTimeoutMicros: retransmissionTimeoutMicros,
      );
      final referenceSentAt = <int, int>{};

      for (var step = 0; step < 250; step++) {
        switch (random.nextInt(5)) {
          case 0:
            final sequence = random.nextInt(20);
            model.onPacketSent(sequence);
            referenceSentAt[sequence] = clock.nowMicros;
            break;
          case 1:
            final sequence = random.nextInt(20);
            model.onAckReceived(sequence);
            referenceSentAt.remove(sequence);
            break;
          case 2:
            final losses = List<int>.generate(3, (_) => random.nextInt(20));
            final expectedDueNow = losses
                .where(referenceSentAt.containsKey)
                .toSet()
                .toList()
              ..sort();
            final dueNow = model.onNakReceived(losses);
            for (final sequence in expectedDueNow) {
              referenceSentAt[sequence] =
                  clock.nowMicros - retransmissionTimeoutMicros;
            }
            expect(dueNow, expectedDueNow);
            break;
          case 3:
            clock.advanceMicros(random.nextInt(5));
            break;
          case 4:
            final deadline = clock.nowMicros - retransmissionTimeoutMicros;
            final expectedTimedOut = referenceSentAt.entries
                .where((entry) => entry.value <= deadline)
                .map((entry) => entry.key)
                .toList()
              ..sort();
            expect(model.collectTimedOutSequences(), expectedTimedOut);
            break;
        }
      }
    });
  });
}
