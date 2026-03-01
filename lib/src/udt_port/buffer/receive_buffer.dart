import 'dart:typed_data';

/// Lightweight receive-unit model equivalent to a populated upstream `CUnit`.
final class UdtReceiveBufferUnit {
  const UdtReceiveBufferUnit({
    required this.payload,
    required this.messageNumber,
  });

  final Uint8List payload;

  /// Includes upstream UDT message bits in the high 3 bits.
  final int messageNumber;

  static const int _boundaryFirst = 0x80000000;
  static const int _boundaryLast = 0x40000000;
  static const int _messageNumberMask = 0x1FFFFFFF;

  int get baseMessageNumber => messageNumber & _messageNumberMask;

  /// 3 => single packet message, 2 => first, 1 => last, 0 => middle.
  int get messageBoundary {
    final first = (messageNumber & _boundaryFirst) != 0;
    final last = (messageNumber & _boundaryLast) != 0;
    if (first && last) {
      return 3;
    }
    if (first) {
      return 2;
    }
    if (last) {
      return 1;
    }
    return 0;
  }

  bool get inOrderDelivery => (messageNumber & 0x20000000) != 0;
}

/// Shared counter model equivalent to upstream `CUnitQueue::m_iCount` updates.
final class UdtReceiveUnitQueueCounter {
  int inUseCount = 0;
}

enum _UdtReceiveUnitState { free, available, readAfterPassAck, dropped }

final class _UdtReceiveSlot {
  _UdtReceiveSlot({required this.unit, required this.state});

  UdtReceiveBufferUnit unit;
  _UdtReceiveUnitState state;
}

/// Pure-Dart receive-buffer port for upstream `CRcvBuffer` in `buffer.h/cpp`.
///
/// This class intentionally keeps deterministic circular-buffer and message-scan
/// behavior while avoiding socket/file dependencies.
final class UdtReceiveBuffer {
  UdtReceiveBuffer({
    required UdtReceiveUnitQueueCounter queueCounter,
    int bufferSize = 65536,
  }) : _queueCounter = queueCounter,
       _size = bufferSize,
       _units = List<_UdtReceiveSlot?>.filled(bufferSize, null, growable: false) {
    if (bufferSize <= 1) {
      throw ArgumentError.value(bufferSize, 'bufferSize', 'must be > 1');
    }
  }

  final UdtReceiveUnitQueueCounter _queueCounter;
  final int _size;
  final List<_UdtReceiveSlot?> _units;

  int _startPos = 0;
  int _lastAckPos = 0;
  int _maxPos = 0;
  int _notch = 0;

  int addData(UdtReceiveBufferUnit unit, int offset) {
    final pos = (_lastAckPos + offset) % _size;
    if (offset > _maxPos) {
      _maxPos = offset;
    }

    if (_units[pos] != null) {
      return -1;
    }

    _units[pos] = _UdtReceiveSlot(unit: unit, state: _UdtReceiveUnitState.available);
    _queueCounter.inUseCount++;
    return 0;
  }

  Uint8List readBuffer(int length) {
    var p = _startPos;
    final lastAck = _lastAckPos;
    var remaining = length;
    final collected = BytesBuilder(copy: false);

    while (p != lastAck && remaining > 0) {
      final slot = _units[p];
      if (slot == null) {
        break;
      }

      final payload = slot.unit.payload;
      var unitSize = payload.length - _notch;
      if (unitSize > remaining) {
        unitSize = remaining;
      }

      collected.add(Uint8List.sublistView(payload, _notch, _notch + unitSize));

      if ((remaining > unitSize) || (remaining == payload.length - _notch)) {
        _units[p] = null;
        _queueCounter.inUseCount--;
        p = (p + 1) % _size;
        _notch = 0;
      } else {
        _notch += remaining;
      }

      remaining -= unitSize;
    }

    _startPos = p;
    return collected.takeBytes();
  }

  void ackData(int length) {
    _lastAckPos = (_lastAckPos + length) % _size;
    _maxPos -= length;
    if (_maxPos < 0) {
      _maxPos = 0;
    }
  }

  int get availableBufferSize => _size - receivedDataSize - 1;

  int get receivedDataSize {
    if (_lastAckPos >= _startPos) {
      return _lastAckPos - _startPos;
    }

    return _size + _lastAckPos - _startPos;
  }

  void dropMessage(int messageNumber) {
    final target = messageNumber & 0x1FFFFFFF;
    for (var i = _startPos, n = (_lastAckPos + _maxPos) % _size; i != n; i = (i + 1) % _size) {
      final slot = _units[i];
      if (slot != null && slot.unit.baseMessageNumber == target) {
        slot.state = _UdtReceiveUnitState.dropped;
      }
    }
  }

  Uint8List readMessage(int length) {
    final scan = _scanMessage();
    if (scan == null) {
      return Uint8List(0);
    }

    var p = scan.start;
    final q = scan.end;
    var remaining = length;
    final collected = BytesBuilder(copy: false);

    while (p != (q + 1) % _size) {
      final slot = _units[p]!;
      var unitSize = slot.unit.payload.length;
      if (remaining >= 0 && unitSize > remaining) {
        unitSize = remaining;
      }

      if (unitSize > 0) {
        collected.add(Uint8List.sublistView(slot.unit.payload, 0, unitSize));
        remaining -= unitSize;
      }

      if (!scan.passAck) {
        _units[p] = null;
        _queueCounter.inUseCount--;
      } else {
        slot.state = _UdtReceiveUnitState.readAfterPassAck;
      }

      p = (p + 1) % _size;
    }

    if (!scan.passAck) {
      _startPos = (q + 1) % _size;
    }

    return collected.takeBytes();
  }

  int get receivedMessageCount => _scanMessage() == null ? 0 : 1;

  _ScanResult? _scanMessage() {
    if ((_startPos == _lastAckPos) && (_maxPos <= 0)) {
      return null;
    }

    while (_startPos != _lastAckPos) {
      final slot = _units[_startPos];
      if (slot == null) {
        _startPos = (_startPos + 1) % _size;
        continue;
      }

      final boundary = slot.unit.messageBoundary;
      if (slot.state == _UdtReceiveUnitState.available && boundary > 1) {
        var good = true;
        for (var i = _startPos; i != _lastAckPos;) {
          final ahead = _units[i];
          if (ahead == null || ahead.state != _UdtReceiveUnitState.available) {
            good = false;
            break;
          }

          final aheadBoundary = ahead.unit.messageBoundary;
          if (aheadBoundary == 1 || aheadBoundary == 3) {
            break;
          }

          i = (i + 1) % _size;
        }

        if (good) {
          break;
        }
      }

      _units[_startPos] = null;
      _queueCounter.inUseCount--;
      _startPos = (_startPos + 1) % _size;
    }

    var p = -1;
    var q = _startPos;
    var passAck = _startPos == _lastAckPos;
    var found = false;

    for (var i = 0, n = _maxPos + receivedDataSize; i <= n; i++) {
      final slot = _units[q];
      if (slot != null && slot.state == _UdtReceiveUnitState.available) {
        final boundary = slot.unit.messageBoundary;
        if (boundary == 3) {
          p = q;
          found = true;
        } else if (boundary == 2) {
          p = q;
        } else if (boundary == 1 && p != -1) {
          found = true;
        }
      } else {
        p = -1;
      }

      if (found) {
        if (!passAck || !slot!.unit.inOrderDelivery) {
          break;
        }
        found = false;
      }

      q = (q + 1) % _size;
      if (q == _lastAckPos) {
        passAck = true;
      }
    }

    if (!found) {
      if (p != -1 && (q + 1) % _size == p) {
        found = true;
      }
    }

    if (!found) {
      return null;
    }

    return _ScanResult(start: p, end: q, passAck: passAck);
  }
}

final class _ScanResult {
  const _ScanResult({
    required this.start,
    required this.end,
    required this.passAck,
  });

  final int start;
  final int end;
  final bool passAck;
}
