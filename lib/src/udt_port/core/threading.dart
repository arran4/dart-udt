import 'dart:async';
import 'dart:collection';

/// Pure-Dart concurrency helpers that replace upstream pthread lock/cond/thread
/// patterns in `queue.h`/`queue.cpp` with deterministic async primitives.
///
/// These wrappers intentionally keep semantics small and explicit so ported
/// modules can remain line-by-line traceable while avoiding pointer/native APIs.
final class UdtAsyncMutex {
  bool _locked = false;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// Runs [action] under mutual exclusion.
  Future<T> synchronized<T>(FutureOr<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (!_locked) {
      _locked = true;
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waiters.isEmpty) {
      _locked = false;
      return;
    }

    final next = _waiters.removeFirst();
    next.complete();
  }
}

/// Condition-like signal primitive for async wait/notify patterns.
///
/// `signal()` advances an internal sequence; `waitForNext()` resolves after a
/// later signal event, similar to a pthread condition wait + predicate loop.
final class UdtAsyncSignal {
  int _sequence = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// Current signal sequence number.
  int get sequence => _sequence;

  /// Wakes all current waiters and advances the signal sequence.
  void signal() {
    _sequence += 1;
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }

  /// Waits until the sequence has advanced beyond [observedSequence].
  Future<void> waitForNext(int observedSequence, {Duration? timeout}) async {
    if (_sequence > observedSequence) {
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    if (timeout == null) {
      return completer.future;
    }

    await completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(completer);
      },
    );
  }
}

/// Serial worker-loop adapter to replace one-off worker-thread loops.
///
/// Tasks execute in enqueue order and never overlap, making behavior easy to
/// test deterministically without real threads or sockets.
final class UdtSerialExecutor {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  bool get isClosed => _closed;

  Future<T> schedule<T>(FutureOr<T> Function() action) {
    if (_closed) {
      throw StateError('executor is closed');
    }

    final completer = Completer<T>();
    _tail = _tail.then<void>((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  /// Prevents new tasks and resolves when all queued tasks finish.
  Future<void> close() async {
    _closed = true;
    await _tail;
  }
}
