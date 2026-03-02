/// Deterministic clock abstraction for protocol-state testing.
abstract interface class UdtProtocolClock {
  int get nowMicros;
}

/// Mutable fake clock for deterministic tests.
final class UdtFakeClock implements UdtProtocolClock {
  UdtFakeClock({int initialMicros = 0}) : _nowMicros = initialMicros;

  int _nowMicros;

  @override
  int get nowMicros => _nowMicros;

  void advanceMicros(int deltaMicros) {
    if (deltaMicros < 0) {
      throw ArgumentError.value(deltaMicros, 'deltaMicros', 'Must be >= 0');
    }
    _nowMicros += deltaMicros;
  }
}

/// Minimal ACK/NAK timeout model with injectable clock.
///
/// This is a pure-Dart deterministic building block for upstream retransmission
/// behavior in `core.cpp` and `queue.cpp`.
final class UdtAckNakTimerModel {
  UdtAckNakTimerModel({
    required UdtProtocolClock clock,
    required int retransmissionTimeoutMicros,
  }) : _clock = clock,
       _retransmissionTimeoutMicros = retransmissionTimeoutMicros {
    if (retransmissionTimeoutMicros <= 0) {
      throw ArgumentError.value(
        retransmissionTimeoutMicros,
        'retransmissionTimeoutMicros',
        'Must be > 0',
      );
    }
  }

  final UdtProtocolClock _clock;
  final int _retransmissionTimeoutMicros;
  final Map<int, int> _sentAtMicrosBySequence = <int, int>{};

  void onPacketSent(int sequenceNumber) {
    _sentAtMicrosBySequence[sequenceNumber] = _clock.nowMicros;
  }

  void onAckReceived(int acknowledgedSequenceNumber) {
    _sentAtMicrosBySequence.remove(acknowledgedSequenceNumber);
  }

  /// Marks explicitly reported lost sequence numbers as immediately timed out.
  List<int> onNakReceived(List<int> lostSequenceNumbers) {
    final nowMicros = _clock.nowMicros;
    final dueNow = <int>[];
    for (final sequence in lostSequenceNumbers) {
      if (_sentAtMicrosBySequence.containsKey(sequence)) {
        _sentAtMicrosBySequence[sequence] =
            nowMicros - _retransmissionTimeoutMicros;
        dueNow.add(sequence);
      }
    }
    dueNow.sort();
    return dueNow;
  }

  List<int> collectTimedOutSequences() {
    final deadline = _clock.nowMicros - _retransmissionTimeoutMicros;
    final timedOut = <int>[];
    _sentAtMicrosBySequence.forEach((sequenceNumber, sentAtMicros) {
      if (sentAtMicros <= deadline) {
        timedOut.add(sequenceNumber);
      }
    });
    timedOut.sort();
    return timedOut;
  }
}
