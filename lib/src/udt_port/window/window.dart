/// Injectable microsecond clock used by pure-Dart window timing models.
typedef UdtNowMicros = int Function();

/// Pure-Dart port of upstream `CACKWindow` from `window.h/.cpp`.
///
/// Stores sent ACK packets (`ackSeq` -> `dataAck`) and computes RTT on ACK-2.
class UdtAckWindow {
  UdtAckWindow({int size = 1024, UdtNowMicros? nowMicros})
    : assert(size > 0),
      _size = size,
      _nowMicros = nowMicros ?? _defaultNowMicros,
      _ackSeqNo = List<int>.filled(size, -1),
      _ack = List<int>.filled(size, 0),
      _timeStampMicros = List<int>.filled(size, 0);

  final int _size;
  final UdtNowMicros _nowMicros;
  final List<int> _ackSeqNo;
  final List<int> _ack;
  final List<int> _timeStampMicros;

  int _head = 0;
  int _tail = 0;

  static int _defaultNowMicros() => DateTime.now().microsecondsSinceEpoch;

  /// Mirrors upstream `CACKWindow::store`.
  void store({required int ackSeq, required int dataAck}) {
    _ackSeqNo[_head] = ackSeq;
    _ack[_head] = dataAck;
    _timeStampMicros[_head] = _nowMicros();

    _head = (_head + 1) % _size;

    if (_head == _tail) {
      _tail = (_tail + 1) % _size;
    }
  }

  /// Mirrors upstream `CACKWindow::acknowledge`.
  ///
  /// Returns `null` if the ACK seq is not in window (overwritten or unknown).
  UdtAckWindowAck2Result? acknowledge(int ack2Seq) {
    final Iterable<int> searchRange =
        _head >= _tail
            ? Iterable<int>.generate(_head - _tail, (i) => _tail + i)
            : Iterable<int>.generate(
              (_head + _size) - _tail,
              (i) => (_tail + i) % _size,
            );

    for (final index in searchRange) {
      if (ack2Seq != _ackSeqNo[index]) {
        continue;
      }

      final ack = _ack[index];
      final rttMicros = _nowMicros() - _timeStampMicros[index];

      if ((index + 1) % _size == _head) {
        _tail = 0;
        _head = 0;
        _ackSeqNo[0] = -1;
      } else {
        _tail = (index + 1) % _size;
      }

      return UdtAckWindowAck2Result(dataAck: ack, rttMicros: rttMicros);
    }

    return null;
  }
}

/// ACK-2 lookup result produced by [UdtAckWindow.acknowledge].
class UdtAckWindowAck2Result {
  const UdtAckWindowAck2Result({
    required this.dataAck,
    required this.rttMicros,
  });

  final int dataAck;
  final int rttMicros;
}

/// Pure-Dart port of upstream `CPktTimeWindow` from `window.h/.cpp`.
class UdtPacketTimeWindow {
  UdtPacketTimeWindow({
    int arrivalWindowSize = 16,
    int probeWindowSize = 16,
    UdtNowMicros? nowMicros,
  }) : assert(arrivalWindowSize > 0),
       assert(probeWindowSize > 0),
       _arrivalWindowSize = arrivalWindowSize,
       _probeWindowSize = probeWindowSize,
       _nowMicros = nowMicros ?? UdtAckWindow._defaultNowMicros,
       _packetWindowMicros = List<int>.filled(arrivalWindowSize, 1000000),
       _probeWindowMicros = List<int>.filled(probeWindowSize, 1000),
       _lastArrivalMicros = (nowMicros ?? UdtAckWindow._defaultNowMicros)();

  final int _arrivalWindowSize;
  final int _probeWindowSize;
  final UdtNowMicros _nowMicros;
  final List<int> _packetWindowMicros;
  final List<int> _probeWindowMicros;

  int _packetWindowPointer = 0;
  int _probeWindowPointer = 0;

  int _lastSentTimeMicros = 0;
  int _minimumPacketSendIntervalMicros = 1000000;

  int _lastArrivalMicros;
  int _currentArrivalMicros = 0;
  int _probeStartMicros = 0;

  int get minimumPacketSendIntervalMicros => _minimumPacketSendIntervalMicros;

  int get packetReceiveSpeedPacketsPerSecond =>
      _medianFilteredPacketsPerSecond(_packetWindowMicros, requireHalfPlusOne: true);

  int get estimatedBandwidthPacketsPerSecond =>
      _medianFilteredPacketsPerSecond(_probeWindowMicros, requireHalfPlusOne: false);

  void onPacketSent(int currentMicros) {
    final interval = currentMicros - _lastSentTimeMicros;
    if (interval > 0 && interval < _minimumPacketSendIntervalMicros) {
      _minimumPacketSendIntervalMicros = interval;
    }
    _lastSentTimeMicros = currentMicros;
  }

  void onPacketArrival() {
    _currentArrivalMicros = _nowMicros();
    _packetWindowMicros[_packetWindowPointer] =
        _currentArrivalMicros - _lastArrivalMicros;

    _packetWindowPointer = (_packetWindowPointer + 1) % _arrivalWindowSize;
    _lastArrivalMicros = _currentArrivalMicros;
  }

  void onProbe1Arrival() {
    _probeStartMicros = _nowMicros();
  }

  void onProbe2Arrival() {
    _currentArrivalMicros = _nowMicros();
    _probeWindowMicros[_probeWindowPointer] =
        _currentArrivalMicros - _probeStartMicros;
    _probeWindowPointer = (_probeWindowPointer + 1) % _probeWindowSize;
  }

  int _medianFilteredPacketsPerSecond(
    List<int> window, {
    required bool requireHalfPlusOne,
  }) {
    final replica = List<int>.from(window)..sort();
    final median = replica[replica.length ~/ 2];
    final upper = median << 3;
    final lower = median >> 3;

    var count = requireHalfPlusOne ? 0 : 1;
    var sum = requireHalfPlusOne ? 0 : median;

    for (final sample in window) {
      if (sample < upper && sample > lower) {
        count++;
        sum += sample;
      }
    }

    if (count == 0 || (requireHalfPlusOne && count <= (window.length >> 1))) {
      return 0;
    }

    return (1000000.0 / (sum / count)).ceil();
  }
}
