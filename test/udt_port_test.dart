import 'dart:async';
import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('status reports scaffold state', () {
    const scaffold = UdtPortScaffold();
    expect(scaffold.status(), contains('scaffold'));
  });

  test('module map includes canonical packet target', () {
    const scaffold = UdtPortScaffold();
    expect(
      scaffold.moduleTargets()[UdtModule.packet],
      equals('lib/src/udt_port/protocol/'),
    );
  });

  test('data packet header round-trips with deterministic bytes', () {
    final header = UdtPacketHeader.data(
      sequenceNumber: 0x01234567,
      timestamp: 0x89ABCDEF,
      destinationSocketId: 0x10203040,
    );

    final bytes = header.toBytes();
    expect(
      bytes,
      Uint8List.fromList([
        0x01,
        0x23,
        0x45,
        0x67,
        0x00,
        0x00,
        0x00,
        0x00,
        0x89,
        0xAB,
        0xCD,
        0xEF,
        0x10,
        0x20,
        0x30,
        0x40,
      ]),
    );

    final reparsed = UdtPacketHeader.parse(bytes);
    expect(reparsed.isControl, isFalse);
    expect(reparsed.sequenceNumber, equals(0x01234567));
    expect(reparsed.timestamp, equals(0x89ABCDEF));
    expect(reparsed.destinationSocketId, equals(0x10203040));
  });

  test('control packet header round-trips with deterministic bytes', () {
    final header = UdtPacketHeader.control(
      controlType: 0x1234,
      controlReserved: 0xABCD,
      additionalInfo: 0x10203040,
      timestamp: 0x55667788,
      destinationSocketId: 0xDEADBEEF,
    );

    final bytes = header.toBytes();
    expect(
      bytes,
      Uint8List.fromList([
        0x92,
        0x34,
        0xAB,
        0xCD,
        0x10,
        0x20,
        0x30,
        0x40,
        0x55,
        0x66,
        0x77,
        0x88,
        0xDE,
        0xAD,
        0xBE,
        0xEF,
      ]),
    );

    final reparsed = UdtPacketHeader.parse(bytes);
    expect(reparsed.isControl, isTrue);
    expect(reparsed.controlType, equals(0x1234));
    expect(reparsed.controlReserved, equals(0xABCD));
    expect(reparsed.additionalInfo, equals(0x10203040));
    expect(reparsed.timestamp, equals(0x55667788));
    expect(reparsed.destinationSocketId, equals(0xDEADBEEF));
  });

  test('typed packet container round-trips header and payload', () {
    final packet = UdtPacket(
      header: UdtPacketHeader.data(
        sequenceNumber: 0x01020304,
        timestamp: 0x11223344,
        destinationSocketId: 0x55667788,
      ),
      payload: Uint8List.fromList([1, 2, 3, 4]),
    );

    final reparsed = UdtPacket.parse(packet.toBytes());
    expect(reparsed.header.sequenceNumber, equals(0x01020304));
    expect(reparsed.header.timestamp, equals(0x11223344));
    expect(reparsed.header.destinationSocketId, equals(0x55667788));
    expect(reparsed.payload, Uint8List.fromList([1, 2, 3, 4]));
  });

  test('handshake round-trips with deterministic byte layout', () {
    final handshake = UdtHandshake(
      version: 4,
      socketType: 1,
      initialSequenceNumber: 0x12345678,
      maximumSegmentSize: 1500,
      flightFlagSize: 25600,
      requestType: -1,
      socketId: 42,
      cookie: 0x10203040,
      peerIp: const [0x0A000001, 0, 0, 0],
    );

    final bytes = handshake.toBytes();
    expect(bytes.lengthInBytes, equals(UdtHandshake.contentSize));
    expect(
      bytes,
      Uint8List.fromList([
        0x00, 0x00, 0x00, 0x04,
        0x00, 0x00, 0x00, 0x01,
        0x12, 0x34, 0x56, 0x78,
        0x00, 0x00, 0x05, 0xDC,
        0x00, 0x00, 0x64, 0x00,
        0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x00, 0x00, 0x2A,
        0x10, 0x20, 0x30, 0x40,
        0x0A, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]),
    );

    final reparsed = UdtHandshake.parse(bytes);
    expect(reparsed.version, equals(4));
    expect(reparsed.socketType, equals(1));
    expect(reparsed.initialSequenceNumber, equals(0x12345678));
    expect(reparsed.maximumSegmentSize, equals(1500));
    expect(reparsed.flightFlagSize, equals(25600));
    expect(reparsed.requestType, equals(-1));
    expect(reparsed.socketId, equals(42));
    expect(reparsed.cookie, equals(0x10203040));
    expect(reparsed.peerIp, equals(const [0x0A000001, 0, 0, 0]));
  });

  test('control handshake packet round-trips through typed wrapper', () {
    final handshake = UdtHandshake(
      version: 5,
      socketType: 2,
      initialSequenceNumber: 0x11111111,
      maximumSegmentSize: 1400,
      flightFlagSize: 8192,
      requestType: 1,
      socketId: 300,
      cookie: 0x7F7F7F7F,
      peerIp: const [0x7F000001, 0, 0, 0],
    );
    final controlPacket = UdtControlPacket.handshake(
      handshake: handshake,
      timestamp: 100,
      destinationSocketId: 200,
    );

    final reparsed = UdtControlPacket.parse(
      UdtPacket.parse(controlPacket.toPacket().toBytes()),
    );

    expect(reparsed.type, equals(UdtControlType.handshake));
    expect(reparsed.parseHandshake().socketId, equals(300));
  });

  test('ACK control packet keeps sequence and optional metrics', () {
    final packet = UdtControlPacket.ack(
      ackSequenceNumber: 77,
      info: const UdtAckControlInfo(
        receivedSequenceNumber: 1200,
        optionalMetrics: [50, 7, 4096, 64, 900],
      ),
      timestamp: 10,
      destinationSocketId: 11,
    );

    final reparsed = UdtControlPacket.parse(UdtPacket.parse(packet.toPacket().toBytes()));
    expect(reparsed.type, equals(UdtControlType.ack));
    expect(reparsed.header.additionalInfo, equals(77));
    expect(reparsed.parseAckControlInfo().receivedSequenceNumber, equals(1200));
    expect(reparsed.parseAckControlInfo().optionalMetrics, equals([50, 7, 4096, 64, 900]));
  });

  test('keep-alive and ACK2 control packets carry no payload bytes', () {
    final keepAlive = UdtControlPacket.keepAlive(
      timestamp: 12,
      destinationSocketId: 13,
    );
    final ack2 = UdtControlPacket.ack2(
      ackSequenceNumber: 99,
      timestamp: 14,
      destinationSocketId: 15,
    );

    expect(keepAlive.controlInformation, isEmpty);
    expect(ack2.controlInformation, isEmpty);
    expect(ack2.header.additionalInfo, equals(99));
  });

  test('congestion warning and shutdown packets are typed zero-payload controls', () {
    final congestion = UdtControlPacket.congestionWarning(
      timestamp: 31,
      destinationSocketId: 32,
    );
    final shutdown = UdtControlPacket.shutdown(
      timestamp: 33,
      destinationSocketId: 34,
    );

    final reparsedCongestion = UdtControlPacket.parse(
      UdtPacket.parse(congestion.toPacket().toBytes()),
    );
    final reparsedShutdown = UdtControlPacket.parse(
      UdtPacket.parse(shutdown.toPacket().toBytes()),
    );

    expect(reparsedCongestion.type, equals(UdtControlType.congestionWarning));
    expect(reparsedCongestion.controlInformation, isEmpty);
    expect(reparsedShutdown.type, equals(UdtControlType.shutdown));
    expect(reparsedShutdown.controlInformation, isEmpty);
  });

  test('NAK and message drop request control payloads are deterministic', () {
    final nak = UdtControlPacket.nak(
      lossList: [0x10000001, 0x00000042],
      timestamp: 21,
      destinationSocketId: 22,
    );
    final drop = UdtControlPacket.messageDropRequest(
      messageId: 123,
      info: const UdtMessageDropRequestControlInfo(
        firstSequenceNumber: 500,
        lastSequenceNumber: 700,
      ),
      timestamp: 23,
      destinationSocketId: 24,
    );

    final reparsedNak = UdtControlPacket.parse(UdtPacket.parse(nak.toPacket().toBytes()));
    final reparsedDrop = UdtControlPacket.parse(UdtPacket.parse(drop.toPacket().toBytes()));

    expect(reparsedNak.parseNakLossList(), equals([0x10000001, 0x00000042]));
    expect(reparsedDrop.header.additionalInfo, equals(123));
    expect(reparsedDrop.parseMessageDropRequest().firstSequenceNumber, equals(500));
    expect(reparsedDrop.parseMessageDropRequest().lastSequenceNumber, equals(700));
  });

  test('error signal and user-defined control wrappers preserve header fields', () {
    final errorSignal = UdtControlPacket.errorSignal(
      errorType: 404,
      timestamp: 41,
      destinationSocketId: 42,
    );
    final userDefined = UdtControlPacket.userDefined(
      extendedType: 0xBEEF,
      timestamp: 43,
      destinationSocketId: 44,
      controlInformation: Uint8List.fromList([9, 8, 7, 6]),
    );

    final reparsedErrorSignal = UdtControlPacket.parse(
      UdtPacket.parse(errorSignal.toPacket().toBytes()),
    );
    final reparsedUserDefined = UdtControlPacket.parse(
      UdtPacket.parse(userDefined.toPacket().toBytes()),
    );

    expect(reparsedErrorSignal.type, equals(UdtControlType.errorSignal));
    expect(reparsedErrorSignal.parseErrorSignalType(), equals(404));
    expect(reparsedErrorSignal.controlInformation, isEmpty);
    expect(reparsedUserDefined.type, equals(UdtControlType.userDefined));
    expect(reparsedUserDefined.parseUserDefinedExtendedType(), equals(0xBEEF));
    expect(reparsedUserDefined.controlInformation, equals([9, 8, 7, 6]));
  });

  test('invalid payload size throws', () {
    expect(
      () => UdtPacketHeader.parse(Uint8List(8)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('invalid handshake size throws', () {
    expect(
      () => UdtHandshake.parse(Uint8List(8)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('invalid ACK payload throws', () {
    expect(
      () => UdtAckControlInfo.parse(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('invalid user-defined extended type throws', () {
    expect(
      () => UdtControlPacket.userDefined(
        extendedType: 0x10000,
        timestamp: 1,
        destinationSocketId: 2,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('ACK/NAK timer model supports deterministic fake clock timeouts', () {
    final clock = UdtFakeClock();
    final model = UdtAckNakTimerModel(
      clock: clock,
      retransmissionTimeoutMicros: 100,
    );

    model.onPacketSent(10);
    model.onPacketSent(11);
    clock.advanceMicros(99);
    expect(model.collectTimedOutSequences(), isEmpty);

    clock.advanceMicros(1);
    expect(model.collectTimedOutSequences(), equals([10, 11]));

    model.onAckReceived(10);
    expect(model.collectTimedOutSequences(), equals([11]));
  });

  test('NAK path marks known lost packets as immediately retransmittable', () {
    final clock = UdtFakeClock(initialMicros: 1000);
    final model = UdtAckNakTimerModel(
      clock: clock,
      retransmissionTimeoutMicros: 50,
    );

    model.onPacketSent(20);
    model.onPacketSent(30);

    final dueNow = model.onNakReceived([30, 40]);
    expect(dueNow, equals([30]));
    expect(model.collectTimedOutSequences(), equals([30]));
  });

  test('timer model rejects non-positive retransmission timeout', () {
    expect(
      () => UdtAckNakTimerModel(
        clock: UdtFakeClock(),
        retransmissionTimeoutMicros: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('fake clock rejects negative advancement', () {
    final clock = UdtFakeClock();
    expect(() => clock.advanceMicros(-1), throwsA(isA<ArgumentError>()));
  });

  test('CCC constructor rejects non-positive syn interval', () {
    expect(
      () => UdtCongestionControl(synIntervalMillis: 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('CCC setACKTimer caps at SYN interval and keeps small values', () {
    final ccc = UdtCongestionControl(synIntervalMillis: 10);

    ccc.setAckTimer(3);
    expect(ccc.ackPeriodMillis, equals(3));

    ccc.setAckTimer(20);
    expect(ccc.ackPeriodMillis, equals(10));
  });

  test('CCC custom message sender is injectable and deterministic', () {
    UdtControlPacket? sent;
    final ccc = UdtCongestionControl(
      customMessageSender: (packet) => sent = packet,
    );

    final userDefined = UdtControlPacket.userDefined(
      extendedType: 0x1111,
      timestamp: 7,
      destinationSocketId: 8,
      controlInformation: Uint8List.fromList([1, 2]),
    );

    ccc.sendCustomMessage(userDefined);

    expect(sent, isNotNull);
    expect(sent!.type, equals(UdtControlType.userDefined));
    expect(sent!.parseUserDefinedExtendedType(), equals(0x1111));
    expect(sent!.controlInformation, equals([1, 2]));
  });

  test('CCC RTO and user-param setters preserve base-state parity', () {
    final ccc = UdtCongestionControl();

    ccc.setRto(2500);
    expect(ccc.hasUserDefinedRto, isTrue);
    expect(ccc.retransmissionTimeoutMicros, equals(2500));

    final input = Uint8List.fromList([4, 5, 6]);
    ccc.setUserParam(input);
    input[0] = 9;

    expect(ccc.userParam, equals([4, 5, 6]));
  });

  _epollTests();
}


final class _FakeSocketEventSource implements UdtSocketEventSource {
  final Map<int, StreamController<UdtSocketIoEvent>> _controllers =
      <int, StreamController<UdtSocketIoEvent>>{};

  @override
  Stream<UdtSocketIoEvent> eventsFor(int socketId) {
    return _controllers.putIfAbsent(
      socketId,
      () => StreamController<UdtSocketIoEvent>.broadcast(sync: true),
    ).stream;
  }

  void emit(int socketId, UdtPollEvent event) {
    final controller = _controllers[socketId];
    if (controller == null) {
      throw StateError('socket $socketId not registered');
    }
    controller.add(UdtSocketIoEvent(socketId: socketId, event: event));
  }

  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}

void _epollTests() {
  test('epoll wait returns watched ready socket sets and drains snapshot', () async {
    final source = _FakeSocketEventSource();
    addTearDown(source.close);

    final epoll = UdtEpoll(eventSource: source);
    final pollId = epoll.create();

    epoll.addUdtSocket(pollId, 10, events: {UdtPollEvent.inEvent});
    epoll.addUdtSocket(pollId, 20, events: {UdtPollEvent.outEvent});

    source.emit(10, UdtPollEvent.inEvent);
    source.emit(20, UdtPollEvent.outEvent);
    source.emit(10, UdtPollEvent.errEvent); // ignored (not watched)

    final ready = await epoll.wait(pollId, timeout: const Duration(milliseconds: 1));
    expect(ready.readSockets, equals(<int>{10}));
    expect(ready.writeSockets, equals(<int>{20}));
    expect(ready.errorSockets, isEmpty);

    final drained = await epoll.wait(
      pollId,
      timeout: const Duration(milliseconds: 1),
    );
    expect(drained.isEmpty, isTrue);
  });

  test('epoll rejects concurrent wait calls on same poll id', () async {
    final source = _FakeSocketEventSource();
    addTearDown(source.close);

    final epoll = UdtEpoll(eventSource: source);
    final pollId = epoll.create();
    epoll.addUdtSocket(pollId, 40);

    final firstWait = epoll.wait(pollId, timeout: const Duration(milliseconds: 10));
    await Future<void>.delayed(Duration.zero);

    expect(
      () => epoll.wait(pollId, timeout: const Duration(milliseconds: 1)),
      throwsA(isA<StateError>()),
    );

    source.emit(40, UdtPollEvent.inEvent);
    final ready = await firstWait;
    expect(ready.readSockets, equals(<int>{40}));
  });

  test('epoll close and unknown poll id paths throw deterministically', () async {
    final source = _FakeSocketEventSource();
    addTearDown(source.close);

    final epoll = UdtEpoll(eventSource: source);
    final pollId = epoll.create();
    epoll.addUdtSocket(pollId, 50);

    epoll.close(pollId);

    expect(() => epoll.close(pollId), throwsA(isA<ArgumentError>()));
    expect(
      () => epoll.wait(pollId, timeout: const Duration(milliseconds: 1)),
      throwsA(isA<ArgumentError>()),
    );
    expect(() => epoll.addUdtSocket(pollId, 50), throwsA(isA<ArgumentError>()));
    await expectLater(
      epoll.removeUdtSocket(pollId, 50),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('epoll remove stops reporting events for removed sockets', () async {
    final source = _FakeSocketEventSource();
    addTearDown(source.close);

    final epoll = UdtEpoll(eventSource: source);
    final pollId = epoll.create();
    epoll.addUdtSocket(pollId, 30);

    await epoll.removeUdtSocket(pollId, 30);
    source.emit(30, UdtPollEvent.inEvent);

    final ready = await epoll.wait(pollId, timeout: const Duration(milliseconds: 1));
    expect(ready.isEmpty, isTrue);
  });
}
