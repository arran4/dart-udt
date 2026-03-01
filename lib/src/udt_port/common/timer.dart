import '../core/ack_nak_timer_model.dart';
import '../core/threading.dart';

/// Pure-Dart timer/event helper port for upstream `CTimer` in `common.h/cpp`.
///
/// The timer is deterministic when driven by an injectable [UdtProtocolClock]
/// and explicit [tick]/[interrupt] calls in tests.
final class UdtTimer {
  UdtTimer({required UdtProtocolClock clock}) : _clock = clock;

  final UdtProtocolClock _clock;
  final UdtAsyncSignal _tickSignal = UdtAsyncSignal();

  int _scheduledMicros = 0;

  Future<void> sleepMicros(int intervalMicros) {
    if (intervalMicros < 0) {
      throw ArgumentError.value(intervalMicros, 'intervalMicros', 'must be >= 0');
    }

    return sleepToMicros(_clock.nowMicros + intervalMicros);
  }

  Future<void> sleepToMicros(int nextMicros) async {
    _scheduledMicros = nextMicros;

    while (_clock.nowMicros < _scheduledMicros) {
      final observed = _tickSignal.sequence;
      await _tickSignal.waitForNext(
        observed,
        timeout: const Duration(milliseconds: 1),
      );
    }
  }

  /// Stops current sleep cycle (equivalent to upstream `CTimer::interrupt`).
  void interrupt() {
    _scheduledMicros = _clock.nowMicros;
    tick();
  }

  /// Triggers a timer tick wake-up (equivalent to upstream `CTimer::tick`).
  void tick() {
    _tickSignal.signal();
  }

  static final UdtAsyncSignal _eventSignal = UdtAsyncSignal();

  /// Equivalent to upstream `CTimer::triggerEvent`.
  static void triggerEvent() {
    _eventSignal.signal();
  }

  /// Equivalent to upstream `CTimer::waitForEvent`.
  static Future<void> waitForEvent({Duration? timeout}) {
    return _eventSignal.waitForNext(_eventSignal.sequence, timeout: timeout);
  }

  /// Equivalent to upstream `CTimer::getTime`.
  static int getTimeMicros(UdtProtocolClock clock) => clock.nowMicros;

  /// Equivalent to upstream `CTimer::getCPUFrequency` fallback branch.
  static int getCpuFrequency() => 1;

  /// Equivalent to upstream `CTimer::rdtsc` fallback branch.
  static int readClockTicks(UdtProtocolClock clock) => clock.nowMicros;
}
