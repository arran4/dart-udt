import 'dart:typed_data';

import '../common/sequence_numbers.dart';
import '../core/ack_nak_timer_model.dart';

/// Deterministic payload+message-number view returned by [UdtSendBuffer.readData]
/// and successful [UdtSendBuffer.readDataAtOffset] calls.
final class UdtSendBufferReadResult {
  const UdtSendBufferReadResult({
    required this.payload,
    required this.messageNumber,
  });

  final Uint8List payload;
  final int messageNumber;
}

/// Retransmission read result equivalent to upstream
/// `CSndBuffer::readData(... offset ...)` behavior.
final class UdtSendBufferRetransmitResult {
  const UdtSendBufferRetransmitResult.data({
    required this.payload,
    required this.messageNumber,
  }) : isMessageExpired = false,
       expiredMessagePacketLength = 0;

  const UdtSendBufferRetransmitResult.messageExpired({
    required this.messageNumber,
    required this.expiredMessagePacketLength,
  }) : payload = null,
       isMessageExpired = true;

  final Uint8List? payload;
  final int messageNumber;
  final bool isMessageExpired;
  final int expiredMessagePacketLength;
}

/// Pure-Dart sender-buffer port for upstream `CSndBuffer` in `buffer.h/cpp`.
///
/// This keeps packet chunking, message-boundary flags, retransmission lookup,
/// and TTL-expiration behavior deterministic without socket/file side effects.
final class UdtSendBuffer {
  UdtSendBuffer({
    int size = 32,
    int maximumSegmentSize = 1500,
    UdtProtocolClock? clock,
  }) : _size = size,
       _maximumSegmentSize = maximumSegmentSize,
       _clock = clock ?? _MonotonicProtocolClock() {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }
    if (maximumSegmentSize <= 0) {
      throw ArgumentError.value(
        maximumSegmentSize,
        'maximumSegmentSize',
        'must be positive',
      );
    }
  }

  static const int _msgBoundaryFirst = 0x80000000;
  static const int _msgBoundaryLast = 0x40000000;
  static const int _msgOrderBit = 0x20000000;
  static const int _msgNumberMask = 0x1FFFFFFF;

  final UdtProtocolClock _clock;
  final int _maximumSegmentSize;

  int _size;
  int _nextMsgNo = 1;

  final List<_SendBlock> _blocks = <_SendBlock>[];
  int _currReadOffset = 0;

  int get currentPacketCount => _blocks.length;

  void addBuffer(Uint8List data, {int ttlMillis = -1, bool inOrder = false}) {
    if (ttlMillis < -1) {
      throw ArgumentError.value(ttlMillis, 'ttlMillis', 'must be >= -1');
    }

    final packetCount = data.isEmpty
        ? 1
        : ((data.length + _maximumSegmentSize - 1) ~/ _maximumSegmentSize);

    while (packetCount + _blocks.length >= _size) {
      _increase();
    }

    final originMicros = _clock.nowMicros;
    final baseMsgNo = _nextMsgNo;
    final orderBits = inOrder ? _msgOrderBit : 0;

    for (var i = 0; i < packetCount; i++) {
      final start = i * _maximumSegmentSize;
      final end = (start + _maximumSegmentSize < data.length)
          ? start + _maximumSegmentSize
          : data.length;
      final chunk = (data.isEmpty && i == 0)
          ? Uint8List(0)
          : Uint8List.sublistView(data, start, end);

      var msgNo = baseMsgNo | orderBits;
      if (i == 0) {
        msgNo |= _msgBoundaryFirst;
      }
      if (i == packetCount - 1) {
        msgNo |= _msgBoundaryLast;
      }

      _blocks.add(
        _SendBlock(
          payload: Uint8List.fromList(chunk),
          messageNumber: msgNo,
          originMicros: originMicros,
          ttlMillis: ttlMillis,
        ),
      );
    }

    _nextMsgNo++;
    if (_nextMsgNo == UdtMessageNumber.maxValue) {
      _nextMsgNo = 1;
    }
  }

  UdtSendBufferReadResult? readData() {
    if (_currReadOffset >= _blocks.length) {
      return null;
    }

    final block = _blocks[_currReadOffset];
    _currReadOffset++;

    return UdtSendBufferReadResult(
      payload: Uint8List.fromList(block.payload),
      messageNumber: block.messageNumber,
    );
  }

  UdtSendBufferRetransmitResult? readDataAtOffset(int offset) {
    if (offset < 0 || offset >= _blocks.length) {
      return null;
    }

    final block = _blocks[offset];
    if (_isExpired(block)) {
      final baseMsgNo = block.messageNumber & _msgNumberMask;
      var msgLength = 1;
      var index = offset + 1;
      while (index < _blocks.length &&
          (_blocks[index].messageNumber & _msgNumberMask) == baseMsgNo) {
        msgLength++;
        index++;
      }

      if (_currReadOffset >= offset && _currReadOffset < offset + msgLength) {
        _currReadOffset = offset + msgLength;
      }

      return UdtSendBufferRetransmitResult.messageExpired(
        messageNumber: baseMsgNo,
        expiredMessagePacketLength: msgLength,
      );
    }

    return UdtSendBufferRetransmitResult.data(
      payload: Uint8List.fromList(block.payload),
      messageNumber: block.messageNumber,
    );
  }

  void ackData(int offset) {
    if (offset <= 0) {
      return;
    }

    final acknowledged = offset > _blocks.length ? _blocks.length : offset;
    _blocks.removeRange(0, acknowledged);
    _currReadOffset = _currReadOffset - acknowledged;
    if (_currReadOffset < 0) {
      _currReadOffset = 0;
    }
  }

  bool _isExpired(_SendBlock block) {
    if (block.ttlMillis < 0) {
      return false;
    }

    final ageMicros = _clock.nowMicros - block.originMicros;
    return (ageMicros ~/ 1000) > block.ttlMillis;
  }

  void _increase() {
    _size += _size;
  }
}

final class _SendBlock {
  const _SendBlock({
    required this.payload,
    required this.messageNumber,
    required this.originMicros,
    required this.ttlMillis,
  });

  final Uint8List payload;
  final int messageNumber;
  final int originMicros;
  final int ttlMillis;
}

final class _MonotonicProtocolClock implements UdtProtocolClock {
  static final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  int get nowMicros => _stopwatch.elapsedMicroseconds;
}
