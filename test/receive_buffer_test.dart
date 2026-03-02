import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  int msgNo(
    int base, {
    bool first = false,
    bool last = false,
    bool ordered = false,
  }) {
    var value = base & 0x1FFFFFFF;
    if (first) {
      value |= 0x80000000;
    }
    if (last) {
      value |= 0x40000000;
    }
    if (ordered) {
      value |= 0x20000000;
    }
    return value;
  }

  test('addData rejects duplicate slot and updates queue counter', () {
    final queue = UdtReceiveUnitQueueCounter();
    final buffer = UdtReceiveBuffer(queueCounter: queue, bufferSize: 8);

    expect(
      buffer.addData(
        UdtReceiveBufferUnit(
          payload: Uint8List.fromList([1]),
          messageNumber: msgNo(10, first: true, last: true),
        ),
        1,
      ),
      0,
    );
    expect(
      buffer.addData(
        UdtReceiveBufferUnit(
          payload: Uint8List.fromList([2]),
          messageNumber: msgNo(11, first: true, last: true),
        ),
        1,
      ),
      -1,
    );
    expect(queue.inUseCount, 1);
  });

  test('readBuffer reads contiguous bytes and frees consumed slots', () {
    final queue = UdtReceiveUnitQueueCounter();
    final buffer = UdtReceiveBuffer(queueCounter: queue, bufferSize: 8);

    buffer.addData(
      UdtReceiveBufferUnit(
        payload: Uint8List.fromList([1, 2]),
        messageNumber: msgNo(1, first: true, last: true),
      ),
      0,
    );
    buffer.addData(
      UdtReceiveBufferUnit(
        payload: Uint8List.fromList([3, 4]),
        messageNumber: msgNo(2, first: true, last: true),
      ),
      1,
    );
    buffer.ackData(2);

    final bytes = buffer.readBuffer(3);
    expect(bytes, [1, 2, 3]);
    expect(queue.inUseCount, 1);
  });

  test('readMessage reassembles multi-packet message and clears slots', () {
    final queue = UdtReceiveUnitQueueCounter();
    final buffer = UdtReceiveBuffer(queueCounter: queue, bufferSize: 16);

    buffer.addData(
      UdtReceiveBufferUnit(
        payload: Uint8List.fromList([1, 2]),
        messageNumber: msgNo(77, first: true),
      ),
      0,
    );
    buffer.addData(
      UdtReceiveBufferUnit(
        payload: Uint8List.fromList([3, 4]),
        messageNumber: msgNo(77, last: true),
      ),
      1,
    );
    buffer.ackData(2);

    expect(buffer.receivedMessageCount, 1);
    expect(buffer.readMessage(10), [1, 2, 3, 4]);
    expect(queue.inUseCount, 0);
    expect(buffer.receivedMessageCount, 0);
  });

  test('dropMessage marks message unusable for readMessage scan', () {
    final queue = UdtReceiveUnitQueueCounter();
    final buffer = UdtReceiveBuffer(queueCounter: queue, bufferSize: 16);

    buffer.addData(
      UdtReceiveBufferUnit(
        payload: Uint8List.fromList([9]),
        messageNumber: msgNo(90, first: true, last: true),
      ),
      0,
    );
    buffer.ackData(1);
    buffer.dropMessage(90);

    expect(buffer.receivedMessageCount, 0);
    expect(buffer.readMessage(8), isEmpty);
  });

  test('constructor validates minimum buffer size', () {
    expect(
      () => UdtReceiveBuffer(
        queueCounter: UdtReceiveUnitQueueCounter(),
        bufferSize: 1,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
