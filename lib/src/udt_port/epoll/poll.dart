import 'dart:async';
import 'dart:io';

/// Mirrors UDT epoll bitmask flags (`UDT_EPOLL_IN|OUT|ERR`) with typed Dart.
enum UdtPollEvent {
  inEvent,
  outEvent,
  errEvent,
}

/// Normalized socket event emitted by poll event sources.
final class UdtSocketIoEvent {
  const UdtSocketIoEvent({required this.socketId, required this.event});

  final int socketId;
  final UdtPollEvent event;
}

/// Porting adapter for upstream `CEPoll` wait/readiness model.
///
/// An implementation can wrap synthetic test streams or real
/// `RawDatagramSocket` events.
abstract interface class UdtSocketEventSource {
  Stream<UdtSocketIoEvent> eventsFor(int socketId);
}

/// Poll readiness sets returned by [UdtEpoll.wait].
final class UdtPollReadySet {
  const UdtPollReadySet({
    required this.readSockets,
    required this.writeSockets,
    required this.errorSockets,
  });

  final Set<int> readSockets;
  final Set<int> writeSockets;
  final Set<int> errorSockets;

  bool get isEmpty =>
      readSockets.isEmpty && writeSockets.isEmpty && errorSockets.isEmpty;

  int get totalEvents =>
      readSockets.length + writeSockets.length + errorSockets.length;
}

/// Minimal pure-Dart poll/epoll abstraction for UDT-socket style IDs.
///
/// This models the control flow of upstream `CEPoll` incrementally while
/// adapting to async stream event sources in Dart.
final class UdtEpoll {
  UdtEpoll({required UdtSocketEventSource eventSource})
    : _eventSource = eventSource;

  final UdtSocketEventSource _eventSource;

  int _pollIdSeed = 0;
  final Map<int, _PollDescriptor> _polls = <int, _PollDescriptor>{};

  int create() {
    _pollIdSeed++;
    _polls[_pollIdSeed] = _PollDescriptor();
    return _pollIdSeed;
  }

  void close(int pollId) {
    final descriptor = _polls.remove(pollId);
    if (descriptor == null) {
      throw ArgumentError.value(pollId, 'pollId', 'Unknown pollId');
    }

    for (final subscription in descriptor.subscriptions.values) {
      unawaited(subscription.cancel());
    }
  }

  void addUdtSocket(
    int pollId,
    int socketId, {
    Set<UdtPollEvent>? events,
  }) {
    final descriptor = _lookup(pollId);
    final watchedEvents = events ?? UdtPollEvent.values.toSet();
    descriptor.watchedEventsBySocket[socketId] = watchedEvents;
    descriptor.subscriptions[socketId] ??= _eventSource.eventsFor(socketId).listen(
      (UdtSocketIoEvent event) {
        final watch = descriptor.watchedEventsBySocket[event.socketId];
        if (watch == null || !watch.contains(event.event)) {
          return;
        }

        switch (event.event) {
          case UdtPollEvent.inEvent:
            descriptor.readyReads.add(event.socketId);
          case UdtPollEvent.outEvent:
            descriptor.readyWrites.add(event.socketId);
          case UdtPollEvent.errEvent:
            descriptor.readyErrors.add(event.socketId);
        }

        descriptor.waiter?.complete();
      },
    );
  }

  Future<void> removeUdtSocket(int pollId, int socketId) async {
    final descriptor = _lookup(pollId);
    descriptor.watchedEventsBySocket.remove(socketId);
    descriptor.readyReads.remove(socketId);
    descriptor.readyWrites.remove(socketId);
    descriptor.readyErrors.remove(socketId);
    final subscription = descriptor.subscriptions.remove(socketId);
    await subscription?.cancel();
  }

  Future<UdtPollReadySet> wait(int pollId, {Duration? timeout}) async {
    final descriptor = _lookup(pollId);

    if (_hasReadyEvents(descriptor)) {
      return _drainReady(descriptor);
    }

    final completer = Completer<void>();
    descriptor.waiter = completer;
    try {
      if (timeout != null) {
        await completer.future.timeout(timeout, onTimeout: () {});
      } else {
        await completer.future;
      }
    } finally {
      if (identical(descriptor.waiter, completer)) {
        descriptor.waiter = null;
      }
    }

    return _drainReady(descriptor);
  }

  _PollDescriptor _lookup(int pollId) {
    final descriptor = _polls[pollId];
    if (descriptor == null) {
      throw ArgumentError.value(pollId, 'pollId', 'Unknown pollId');
    }
    return descriptor;
  }

  bool _hasReadyEvents(_PollDescriptor descriptor) {
    return descriptor.readyReads.isNotEmpty ||
        descriptor.readyWrites.isNotEmpty ||
        descriptor.readyErrors.isNotEmpty;
  }

  UdtPollReadySet _drainReady(_PollDescriptor descriptor) {
    final snapshot = UdtPollReadySet(
      readSockets: Set<int>.from(descriptor.readyReads),
      writeSockets: Set<int>.from(descriptor.readyWrites),
      errorSockets: Set<int>.from(descriptor.readyErrors),
    );
    descriptor.readyReads.clear();
    descriptor.readyWrites.clear();
    descriptor.readyErrors.clear();
    return snapshot;
  }
}

final class _PollDescriptor {
  final Map<int, Set<UdtPollEvent>> watchedEventsBySocket =
      <int, Set<UdtPollEvent>>{};
  final Map<int, StreamSubscription<UdtSocketIoEvent>> subscriptions =
      <int, StreamSubscription<UdtSocketIoEvent>>{};
  final Set<int> readyReads = <int>{};
  final Set<int> readyWrites = <int>{};
  final Set<int> readyErrors = <int>{};

  Completer<void>? waiter;
}

/// Adapts [RawDatagramSocket] event streams into [UdtSocketEventSource].
final class UdtRawDatagramEventSource implements UdtSocketEventSource {
  UdtRawDatagramEventSource({required Map<int, RawDatagramSocket> socketsById})
    : _socketsById = socketsById;

  final Map<int, RawDatagramSocket> _socketsById;

  @override
  Stream<UdtSocketIoEvent> eventsFor(int socketId) {
    final socket = _socketsById[socketId];
    if (socket == null) {
      throw ArgumentError.value(socketId, 'socketId', 'Socket not registered');
    }

    return socket
        .map<UdtSocketIoEvent?>(
          (RawSocketEvent event) => switch (event) {
            RawSocketEvent.read =>
              UdtSocketIoEvent(socketId: socketId, event: UdtPollEvent.inEvent),
            RawSocketEvent.write =>
              UdtSocketIoEvent(socketId: socketId, event: UdtPollEvent.outEvent),
            RawSocketEvent.closed || RawSocketEvent.readClosed => UdtSocketIoEvent(
              socketId: socketId,
              event: UdtPollEvent.errEvent,
            ),
          },
        )
        .whereType<UdtSocketIoEvent>();
  }
}
