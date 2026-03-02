import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('addBuffer chunks payload by MSS and marks message boundaries', () {
    final buffer = UdtSendBuffer(size: 2, maximumSegmentSize: 4);

    buffer.addBuffer(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]));

    final first = buffer.readData();
    final second = buffer.readData();
    final third = buffer.readData();

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(third, isNotNull);

    expect(first!.payload, [1, 2, 3, 4]);
    expect(second!.payload, [5, 6, 7, 8]);
    expect(third!.payload, [9]);

    expect((first.messageNumber & 0x80000000) != 0, isTrue);
    expect((first.messageNumber & 0x40000000) != 0, isFalse);
    expect((second.messageNumber & 0x80000000) != 0, isFalse);
    expect((second.messageNumber & 0x40000000) != 0, isFalse);
    expect((third.messageNumber & 0x40000000) != 0, isTrue);
  });

  test('ackData drops acknowledged packets and updates visible count', () {
    final buffer = UdtSendBuffer(size: 4, maximumSegmentSize: 2);
    buffer.addBuffer(Uint8List.fromList([1, 2, 3, 4, 5]));

    expect(buffer.currentPacketCount, 3);
    buffer.ackData(2);

    expect(buffer.currentPacketCount, 1);
    final remaining = buffer.readData();
    expect(remaining, isNotNull);
    expect(remaining!.payload, [5]);
  });

  test('readDataAtOffset returns expired result for TTL timeout', () {
    final clock = UdtFakeClock();
    final buffer = UdtSendBuffer(size: 4, maximumSegmentSize: 3, clock: clock);

    buffer.addBuffer(Uint8List.fromList([1, 2, 3, 4, 5, 6]), ttlMillis: 2);

    clock.advanceMicros(3001);
    final result = buffer.readDataAtOffset(0);

    expect(result, isNotNull);
    expect(result!.isMessageExpired, isTrue);
    expect(result.messageNumber, greaterThan(0));
    expect(result.expiredMessagePacketLength, 2);
    expect(result.payload, isNull);
  });

  test('readDataAtOffset returns payload for non-expired packet', () {
    final clock = UdtFakeClock();
    final buffer = UdtSendBuffer(size: 4, maximumSegmentSize: 4, clock: clock);

    buffer.addBuffer(Uint8List.fromList([10, 11, 12]), ttlMillis: 10);
    clock.advanceMicros(1000);

    final result = buffer.readDataAtOffset(0);
    expect(result, isNotNull);
    expect(result!.isMessageExpired, isFalse);
    expect(result.payload, [10, 11, 12]);
  });

  test('validates constructor and method inputs', () {
    expect(
      () => UdtSendBuffer(size: 0, maximumSegmentSize: 1500),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => UdtSendBuffer(size: 8, maximumSegmentSize: 0),
      throwsA(isA<ArgumentError>()),
    );

    final buffer = UdtSendBuffer(size: 2, maximumSegmentSize: 2);
    expect(
      () => buffer.addBuffer(Uint8List.fromList([1]), ttlMillis: -2),
      throwsA(isA<ArgumentError>()),
    );
    expect(buffer.readDataAtOffset(0), isNull);
  });
}
