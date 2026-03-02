import 'dart:async';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('async mutex serializes overlapping critical sections', () async {
    final mutex = UdtAsyncMutex();
    final trace = <String>[];

    Future<void> critical(String id, Duration hold) async {
      await mutex.synchronized(() async {
        trace.add('enter:$id');
        await Future<void>.delayed(hold);
        trace.add('exit:$id');
      });
    }

    final first = critical('A', const Duration(milliseconds: 5));
    final second = critical('B', const Duration(milliseconds: 1));

    await Future.wait([first, second]);
    expect(trace, equals(['enter:A', 'exit:A', 'enter:B', 'exit:B']));
  });

  test('async signal wakes waiters after sequence advance', () async {
    final signal = UdtAsyncSignal();
    final observed = signal.sequence;

    var resumed = false;
    final waiter = signal.waitForNext(observed).then((_) {
      resumed = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(resumed, isFalse);

    signal.signal();
    await waiter;
    expect(resumed, isTrue);
  });

  test('async signal timeout completes without throwing', () async {
    final signal = UdtAsyncSignal();
    final observed = signal.sequence;

    await signal.waitForNext(
      observed,
      timeout: const Duration(milliseconds: 1),
    );
    expect(signal.sequence, equals(observed));
  });

  test('serial executor preserves task order and waits on close', () async {
    final executor = UdtSerialExecutor();
    final trace = <int>[];

    final taskA = executor.schedule(() async {
      await Future<void>.delayed(const Duration(milliseconds: 3));
      trace.add(1);
    });
    final taskB = executor.schedule(() {
      trace.add(2);
    });

    await Future.wait([taskA, taskB]);
    await executor.close();

    expect(trace, equals([1, 2]));
    expect(executor.isClosed, isTrue);
    expect(() => executor.schedule(() => 3), throwsA(isA<StateError>()));
  });
}
