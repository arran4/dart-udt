import 'dart:typed_data';

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
