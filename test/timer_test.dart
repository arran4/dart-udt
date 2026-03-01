import 'dart:async';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('sleepToMicros waits until clock reaches scheduled deadline', () async {
    final clock = UdtFakeClock(initialMicros: 100);
    final timer = UdtTimer(clock: clock);

    var completed = false;
    final future = timer.sleepToMicros(200).then((_) => completed = true);

    await Future<void>.delayed(const Duration(milliseconds: 2));
    expect(completed, isFalse);

    clock.advanceMicros(100);
    timer.tick();

    await future;
    expect(completed, isTrue);
  });

  test('interrupt releases ongoing sleep immediately', () async {
    final clock = UdtFakeClock(initialMicros: 500);
    final timer = UdtTimer(clock: clock);

    var completed = false;
    final future = timer.sleepMicros(1000).then((_) => completed = true);

    await Future<void>.delayed(const Duration(milliseconds: 2));
    expect(completed, isFalse);

    timer.interrupt();
    await future;
    expect(completed, isTrue);
  });

  test('event signal waits and triggers deterministically', () async {
    var completed = false;
    final wait = UdtTimer.waitForEvent().then((_) => completed = true);

    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(completed, isFalse);

    UdtTimer.triggerEvent();
    await wait;
    expect(completed, isTrue);
  });

  test('timer static helpers return expected fallback values', () {
    final clock = UdtFakeClock(initialMicros: 42);

    expect(UdtTimer.getTimeMicros(clock), 42);
    expect(UdtTimer.readClockTicks(clock), 42);
    expect(UdtTimer.getCpuFrequency(), 1);
  });

  test('sleepMicros validates negative intervals', () {
    final timer = UdtTimer(clock: UdtFakeClock());
    expect(() => timer.sleepMicros(-1), throwsA(isA<ArgumentError>()));
  });
}
