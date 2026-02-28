import 'dart:typed_data';
import 'dart:math' as math;

import '../protocol/control_packet.dart';
import '../protocol/packet.dart';

/// Pure-Dart base congestion-control wrapper ported from upstream `CCC`
/// in `ccc.h`/`ccc.cpp`.
///
/// This mirrors the upstream base-class callback surface and mutable transport
/// hints while keeping all side effects injectable for deterministic tests.
class UdtCongestionControl {
  UdtCongestionControl({
    int synIntervalMillis = 10,
    void Function(UdtControlPacket packet)? customMessageSender,
  }) : _synIntervalMillis = synIntervalMillis,
       _customMessageSender = customMessageSender {
    if (synIntervalMillis <= 0) {
      throw ArgumentError.value(
        synIntervalMillis,
        'synIntervalMillis',
        'must be positive',
      );
    }
  }

  final int _synIntervalMillis;
  final void Function(UdtControlPacket packet)? _customMessageSender;

  double _packetSendPeriodMicros = 1.0;
  double _congestionWindowSize = 16.0;
  int _bandwidthPacketsPerSec = 0;
  double _maxCongestionWindowSize = 0;
  int _maximumSegmentSize = 0;
  int _sendCurrentSequenceNumber = 0;
  int _receiveRatePacketsPerSec = 0;
  int _roundTripTimeMicros = 0;
  Uint8List _userParam = Uint8List(0);
  int _ackPeriodMillis = 0;
  int _ackIntervalPackets = 0;
  bool _hasUserDefinedRto = false;
  int _retransmissionTimeoutMicros = -1;

  double get packetSendPeriodMicros => _packetSendPeriodMicros;

  double get congestionWindowSize => _congestionWindowSize;

  int get bandwidthPacketsPerSec => _bandwidthPacketsPerSec;

  double get maxCongestionWindowSize => _maxCongestionWindowSize;

  int get maximumSegmentSize => _maximumSegmentSize;

  int get sendCurrentSequenceNumber => _sendCurrentSequenceNumber;

  int get receiveRatePacketsPerSec => _receiveRatePacketsPerSec;

  int get roundTripTimeMicros => _roundTripTimeMicros;

  Uint8List get userParam => Uint8List.fromList(_userParam);

  int get ackPeriodMillis => _ackPeriodMillis;

  int get ackIntervalPackets => _ackIntervalPackets;

  bool get hasUserDefinedRto => _hasUserDefinedRto;

  int get retransmissionTimeoutMicros => _retransmissionTimeoutMicros;

  /// Mirrors upstream `CCC::m_iSYNInterval` transport tuning base interval.
  int get synIntervalMillis => _synIntervalMillis;

  /// Called when a connection starts.
  void init() {}

  /// Called when a connection closes.
  void close() {}

  /// Called when an ACK control packet is received.
  void onAck(int acknowledgedSequenceNumber) {}

  /// Called when loss sequence numbers are reported.
  void onLoss(List<int> lossList) {}

  /// Called when a timeout event occurs.
  void onTimeout() {}

  /// Called when a data packet is sent.
  void onPacketSent(UdtPacket packet) {}

  /// Called when a data packet is received.
  void onPacketReceived(UdtPacket packet) {}

  /// Called when a custom/user-defined control packet is received.
  void processCustomMessage(UdtControlPacket packet) {}

  /// Port of upstream `CCC::setACKTimer`.
  void setAckTimer(int intervalMillis) {
    _ackPeriodMillis = intervalMillis > _synIntervalMillis
        ? _synIntervalMillis
        : intervalMillis;
  }

  /// Port of upstream `CCC::setACKInterval`.
  void setAckInterval(int packetInterval) {
    _ackIntervalPackets = packetInterval;
  }

  /// Port of upstream `CCC::setRTO`.
  void setRto(int timeoutMicros) {
    _hasUserDefinedRto = true;
    _retransmissionTimeoutMicros = timeoutMicros;
  }

  /// Injectable pure-Dart replacement for upstream `CCC::sendCustomMsg`.
  void sendCustomMessage(UdtControlPacket packet) {
    _customMessageSender?.call(packet);
  }

  /// Port of upstream `CCC::setMSS`.
  void setMaximumSegmentSize(int mss) {
    _maximumSegmentSize = mss;
  }

  /// Port of upstream `CCC::setBandwidth`.
  void setBandwidth(int bandwidthPacketsPerSecond) {
    _bandwidthPacketsPerSec = bandwidthPacketsPerSecond;
  }

  /// Port of upstream `CCC::setSndCurrSeqNo`.
  void setSendCurrentSequenceNumber(int sequenceNumber) {
    _sendCurrentSequenceNumber = sequenceNumber;
  }

  /// Port of upstream `CCC::setRcvRate`.
  void setReceiveRate(int packetsPerSecond) {
    _receiveRatePacketsPerSec = packetsPerSecond;
  }

  /// Port of upstream `CCC::setMaxCWndSize`.
  void setMaxCongestionWindowSize(double congestionWindowPackets) {
    _maxCongestionWindowSize = congestionWindowPackets;
  }

  /// Port of upstream `CCC::setRTT`.
  void setRoundTripTimeMicros(int roundTripTimeMicros) {
    _roundTripTimeMicros = roundTripTimeMicros;
  }

  /// Port of upstream `CCC::setUserParam` with immutable byte ownership.
  void setUserParam(Uint8List param) {
    _userParam = Uint8List.fromList(param);
  }

  /// Maintains parity with mutable upstream base state for derived classes.
  void setPacketSendPeriodMicros(double periodMicros) {
    _packetSendPeriodMicros = periodMicros;
  }

  /// Maintains parity with mutable upstream base state for derived classes.
  void setCongestionWindowSize(double windowPackets) {
    _congestionWindowSize = windowPackets;
  }
}

/// Pure-Dart default congestion-control algorithm mirroring upstream `CUDTCC`
/// in `ccc.cpp` (`init`, `onACK`, `onLoss`, and `onTimeout`).
class UdtDefaultCongestionControl extends UdtCongestionControl {
  UdtDefaultCongestionControl({
    super.synIntervalMillis,
    super.customMessageSender,
    int Function()? nowMicros,
    double Function(int seed)? seededRandomFraction,
  }) : _nowMicros = nowMicros ?? _defaultNowMicros,
       _seededRandomFraction =
           seededRandomFraction ?? _defaultSeededRandomFraction;

  static const int _sequenceThreshold = 0x3FFFFFFF;
  static const int _maxSequenceNumber = 0x7FFFFFFF;
  static const double _minimumAckIncrease = 0.01;

  static final Stopwatch _clock = Stopwatch()..start();

  static int _defaultNowMicros() => _clock.elapsedMicroseconds;

  static double _defaultSeededRandomFraction(int seed) =>
      math.Random(seed).nextDouble();

  final int Function() _nowMicros;
  final double Function(int seed) _seededRandomFraction;

  int _rateControlIntervalMicros = 0;
  int _lastRateControlTimeMicros = 0;
  bool _isSlowStart = true;
  int _lastAckSequenceNumber = 0;
  bool _lossReportedSinceLastAck = false;
  int _lastDecreaseSequenceNumber = 0;
  double _lastDecreasePeriodMicros = 1.0;
  int _nakCount = 0;
  int _decreaseRandom = 1;
  int _averageNakNumber = 0;
  int _decreaseCount = 0;

  @override
  void init() {
    _rateControlIntervalMicros = synIntervalMillis * 1000;
    _lastRateControlTimeMicros = _nowMicros();
    setAckTimer(synIntervalMillis);

    _isSlowStart = true;
    _lastAckSequenceNumber = sendCurrentSequenceNumber;
    _lossReportedSinceLastAck = false;
    _lastDecreaseSequenceNumber = _decrementSequence(_lastAckSequenceNumber);
    _lastDecreasePeriodMicros = 1.0;
    _averageNakNumber = 0;
    _nakCount = 0;
    _decreaseRandom = 1;

    setCongestionWindowSize(16.0);
    setPacketSendPeriodMicros(1.0);
  }

  @override
  void onAck(int acknowledgedSequenceNumber) {
    final currentTimeMicros = _nowMicros();
    if (currentTimeMicros - _lastRateControlTimeMicros < _rateControlIntervalMicros) {
      return;
    }

    _lastRateControlTimeMicros = currentTimeMicros;

    if (_isSlowStart) {
      setCongestionWindowSize(
        congestionWindowSize +
            _sequenceLength(_lastAckSequenceNumber, acknowledgedSequenceNumber),
      );
      _lastAckSequenceNumber = acknowledgedSequenceNumber;

      if (congestionWindowSize > maxCongestionWindowSize) {
        _isSlowStart = false;
        if (receiveRatePacketsPerSec > 0) {
          setPacketSendPeriodMicros(1000000.0 / receiveRatePacketsPerSec);
        } else {
          setPacketSendPeriodMicros(
            (roundTripTimeMicros + _rateControlIntervalMicros) / congestionWindowSize,
          );
        }
      }
    } else {
      setCongestionWindowSize(
        receiveRatePacketsPerSec / 1000000.0 *
                (roundTripTimeMicros + _rateControlIntervalMicros) +
            16,
      );
    }

    if (_isSlowStart) {
      return;
    }

    if (_lossReportedSinceLastAck) {
      _lossReportedSinceLastAck = false;
      return;
    }

    final currentBandwidthPacketsPerSec = bandwidthPacketsPerSec;
    var estimatedSpareBandwidth =
        (currentBandwidthPacketsPerSec - 1000000.0 / packetSendPeriodMicros)
            .toInt();

    if (packetSendPeriodMicros > _lastDecreasePeriodMicros &&
        (currentBandwidthPacketsPerSec / 9) < estimatedSpareBandwidth) {
      estimatedSpareBandwidth = (currentBandwidthPacketsPerSec / 9).toInt();
    }

    final effectiveMss = maximumSegmentSize > 0 ? maximumSegmentSize : 1;
    final double increase;
    if (estimatedSpareBandwidth <= 0) {
      increase = _minimumAckIncrease;
    } else {
      var computedIncrease =
          math.pow(
                10.0,
                _log10(estimatedSpareBandwidth * effectiveMss * 8.0).ceil(),
              ) *
              0.0000015 /
              effectiveMss;
      if (computedIncrease < _minimumAckIncrease) {
        computedIncrease = _minimumAckIncrease;
      }
      increase = computedIncrease.toDouble();
    }

    setPacketSendPeriodMicros(
      (packetSendPeriodMicros * _rateControlIntervalMicros) /
          (packetSendPeriodMicros * increase + _rateControlIntervalMicros),
    );
  }

  @override
  void onLoss(List<int> lossList) {
    if (lossList.isEmpty) {
      return;
    }

    if (_isSlowStart) {
      _isSlowStart = false;
      if (receiveRatePacketsPerSec > 0) {
        setPacketSendPeriodMicros(1000000.0 / receiveRatePacketsPerSec);
        return;
      }

      final rateControl = roundTripTimeMicros + _rateControlIntervalMicros;
      final safeRateControl = rateControl <= 0 ? 1 : rateControl;
      setPacketSendPeriodMicros(congestionWindowSize / safeRateControl);
    }

    _lossReportedSinceLastAck = true;
    final normalizedLoss = lossList.first & 0x7FFFFFFF;
    if (_compareSequence(normalizedLoss, _lastDecreaseSequenceNumber) > 0) {
      _lastDecreasePeriodMicros = packetSendPeriodMicros;
      setPacketSendPeriodMicros((packetSendPeriodMicros * 1.125).ceilToDouble());

      _averageNakNumber = (_averageNakNumber * 0.875 + _nakCount * 0.125).ceil();
      _nakCount = 1;
      _decreaseCount = 1;

      _lastDecreaseSequenceNumber = sendCurrentSequenceNumber;
      _decreaseRandom =
          (_averageNakNumber * _seededRandomFraction(_lastDecreaseSequenceNumber)).ceil();
      if (_decreaseRandom < 1) {
        _decreaseRandom = 1;
      }
      return;
    }

    final previousDecreaseCount = _decreaseCount;
    _decreaseCount += 1;
    if (previousDecreaseCount < 5) {
      _nakCount += 1;
      if (_nakCount % _decreaseRandom == 0) {
        setPacketSendPeriodMicros((packetSendPeriodMicros * 1.125).ceilToDouble());
        _lastDecreaseSequenceNumber = sendCurrentSequenceNumber;
      }
    }
  }

  @override
  void onTimeout() {
    if (_isSlowStart) {
      _isSlowStart = false;
      if (receiveRatePacketsPerSec > 0) {
        setPacketSendPeriodMicros(1000000.0 / receiveRatePacketsPerSec);
      } else {
        final rateControl = roundTripTimeMicros + _rateControlIntervalMicros;
        final safeRateControl = rateControl <= 0 ? 1 : rateControl;
        setPacketSendPeriodMicros(congestionWindowSize / safeRateControl);
      }
    }
  }

  static int _compareSequence(int sequence1, int sequence2) {
    final absoluteDifference = (sequence1 - sequence2).abs();
    return absoluteDifference < _sequenceThreshold
        ? sequence1 - sequence2
        : sequence2 - sequence1;
  }

  static int _sequenceLength(int fromSequence, int toSequence) {
    return fromSequence <= toSequence
        ? toSequence - fromSequence + 1
        : toSequence - fromSequence + _maxSequenceNumber + 2;
  }

  static int _decrementSequence(int sequence) =>
      sequence == 0 ? _maxSequenceNumber : sequence - 1;

  static double _log10(num value) => math.log(value) / math.ln10;
}
