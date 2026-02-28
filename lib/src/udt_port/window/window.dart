import '../core/ack_nak_timer_model.dart';

/// Pure-Dart ACK history window ported from upstream `window.h`/`window.cpp`
/// `CACKWindow`.
final class UdtAckWindow {
  UdtAckWindow({required UdtProtocolClock clock, int size = 1024})
    : _clock = clock,
      _size = size,
      _ackSeqNo = List<int>.filled(size, 0),
      _ackNumbers = List<int>.filled(size, 0),
      _timestampsMicros = List<int>.filled(size, 0) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'Must be > 0');
    }
    _ackSeqNo[0] = -1;
  }

  final UdtProtocolClock _clock;
  final int _size;
  final List<int> _ackSeqNo;
  final List<int> _ackNumbers;
  final List<int> _timestampsMicros;
  int _head = 0;
  int _tail = 0;

  void store(int sequenceNumber, int ackNumber) {
    _ackSeqNo[_head] = sequenceNumber;
    _ackNumbers[_head] = ackNumber;
    _timestampsMicros[_head] = _clock.nowMicros;

    _head = (_head + 1) % _size;

    if (_head == _tail) {
      _tail = (_tail + 1) % _size;
    }
  }

  UdtAcknowledgedAck? acknowledge(int sequenceNumber) {
    if (_head >= _tail) {
      for (var i = _tail; i < _head; i++) {
        if (sequenceNumber == _ackSeqNo[i]) {
          return _consumeAt(i);
        }
      }
      return null;
    }

    for (var j = _tail; j < _head + _size; j++) {
      final index = j % _size;
      if (sequenceNumber == _ackSeqNo[index]) {
        return _consumeAt(index);
      }
    }

    return null;
  }

  UdtAcknowledgedAck _consumeAt(int index) {
    final ackNumber = _ackNumbers[index];
    final rttMicros = _clock.nowMicros - _timestampsMicros[index];

    if (index + 1 == _head) {
      _tail = 0;
      _head = 0;
      _ackSeqNo[0] = -1;
    } else {
      _tail = (index + 1) % _size;
    }

    return UdtAcknowledgedAck(ackNumber: ackNumber, rttMicros: rttMicros);
  }
}

final class UdtAcknowledgedAck {
  const UdtAcknowledgedAck({required this.ackNumber, required this.rttMicros});

  final int ackNumber;
  final int rttMicros;
}

/// Pure-Dart packet/probe timing window ported from upstream
/// `window.h`/`window.cpp` `CPktTimeWindow`.
final class UdtPacketTimeWindow {
  UdtPacketTimeWindow({
    required UdtProtocolClock clock,
    int arrivalWindowSize = 16,
    int probeWindowSize = 16,
  }) : _clock = clock,
       _arrivalWindowSize = arrivalWindowSize,
       _probeWindowSize = probeWindowSize,
       _packetIntervalsMicros = List<int>.filled(arrivalWindowSize, 1000000),
       _probeIntervalsMicros = List<int>.filled(probeWindowSize, 1000),
       _lastArrivalMicros = clock.nowMicros {
    if (arrivalWindowSize <= 0) {
      throw ArgumentError.value(
        arrivalWindowSize,
        'arrivalWindowSize',
        'Must be > 0',
      );
    }
    if (probeWindowSize <= 0) {
      throw ArgumentError.value(
        probeWindowSize,
        'probeWindowSize',
        'Must be > 0',
      );
    }
  }

  final UdtProtocolClock _clock;
  final int _arrivalWindowSize;
  final int _probeWindowSize;
  final List<int> _packetIntervalsMicros;
  final List<int> _probeIntervalsMicros;
  int _packetWindowPtr = 0;
  int _probeWindowPtr = 0;
  int _lastSentTimeMicros = 0;
  int _minPacketSendIntervalMicros = 1000000;
  int _lastArrivalMicros;
  int _probeTimeMicros = 0;

  int get minPacketSendIntervalMicros => _minPacketSendIntervalMicros;

  int getPacketReceiveSpeedPacketsPerSecond() {
    final replica = List<int>.from(_packetIntervalsMicros)..sort();
    final median = replica[_arrivalWindowSize ~/ 2];

    final upper = median << 3;
    final lower = median >> 3;
    var count = 0;
    var sum = 0;

    for (final value in _packetIntervalsMicros) {
      if (value < upper && value > lower) {
        count++;
        sum += value;
      }
    }

    if (count > (_arrivalWindowSize >> 1)) {
      return (1000000.0 / (sum / count)).ceil();
    }

    return 0;
  }

  int getBandwidthPacketsPerSecond() {
    final replica = List<int>.from(_probeIntervalsMicros)..sort();
    final median = replica[_probeWindowSize ~/ 2];

    final upper = median << 3;
    final lower = median >> 3;
    var count = 1;
    var sum = median;

    for (final value in _probeIntervalsMicros) {
      if (value < upper && value > lower) {
        count++;
        sum += value;
      }
    }

    return (1000000.0 / (sum / count)).ceil();
  }

  void onPacketSent(int currentTimeMicros) {
    final interval = currentTimeMicros - _lastSentTimeMicros;
    if (interval < _minPacketSendIntervalMicros && interval > 0) {
      _minPacketSendIntervalMicros = interval;
    }
    _lastSentTimeMicros = currentTimeMicros;
  }

  void onPacketArrival() {
    final currentArrivalMicros = _clock.nowMicros;
    _packetIntervalsMicros[_packetWindowPtr] =
        currentArrivalMicros - _lastArrivalMicros;

    _packetWindowPtr++;
    if (_packetWindowPtr == _arrivalWindowSize) {
      _packetWindowPtr = 0;
    }

    _lastArrivalMicros = currentArrivalMicros;
  }

  void probe1Arrival() {
    _probeTimeMicros = _clock.nowMicros;
  }

  void probe2Arrival() {
    final currentArrivalMicros = _clock.nowMicros;
    _probeIntervalsMicros[_probeWindowPtr] = currentArrivalMicros - _probeTimeMicros;

    _probeWindowPtr++;
    if (_probeWindowPtr == _probeWindowSize) {
      _probeWindowPtr = 0;
    }
  }

}
