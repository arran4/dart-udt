import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('ack window returns data ack + RTT and advances tail', () {
    var now = 1000;
    final window = UdtAckWindow(size: 8, nowMicros: () => now);

    window.store(ackSeq: 10, dataAck: 100);
    now += 150;
    window.store(ackSeq: 11, dataAck: 110);

    now += 50;
    final result = window.acknowledge(10);

    expect(result, isNotNull);
    expect(result!.dataAck, equals(100));
    expect(result.rttMicros, equals(200));

    now += 10;
    final next = window.acknowledge(11);
    expect(next, isNotNull);
    expect(next!.dataAck, equals(110));
  });

  test('ack window returns null when ack entry has been overwritten', () {
    var now = 0;
    final window = UdtAckWindow(size: 2, nowMicros: () => now);

    window.store(ackSeq: 1, dataAck: 10);
    now += 1;
    window.store(ackSeq: 2, dataAck: 20);
    now += 1;
    window.store(ackSeq: 3, dataAck: 30);

    expect(window.acknowledge(1), isNull);
    final found = window.acknowledge(3);
    expect(found, isNotNull);
    expect(found!.dataAck, equals(30));
  });

  test('packet time window tracks minimum send interval', () {
    final window = UdtPacketTimeWindow();

    window.onPacketSent(100);
    window.onPacketSent(140);
    window.onPacketSent(170);

    expect(window.minimumPacketSendIntervalMicros, equals(30));
  });

  test('packet arrival/probe metrics produce deterministic speeds', () {
    final timeline = [
      0,
      100,
      200,
      300,
      400,
      500,
      600,
      700,
      800,
      900,
      1000,
      1100,
      1200,
      1300,
      1400,
      1500,
      1600,
      1700,
      1800,
      1900,
      2000,
      2100,
      2200,
      2300,
      2400,
      2500,
      2600,
      2700,
      2800,
      2900,
      3000,
      3100,
      3200,
    ];
    var i = 0;
    final window = UdtPacketTimeWindow(
      arrivalWindowSize: 4,
      probeWindowSize: 4,
      nowMicros: () => timeline[i++],
    );

    for (var n = 0; n < 8; n++) {
      window.onPacketArrival();
    }

    for (var n = 0; n < 4; n++) {
      window.onProbe1Arrival();
      window.onProbe2Arrival();
    }

    expect(window.packetReceiveSpeedPacketsPerSecond, equals(10000));
    expect(window.estimatedBandwidthPacketsPerSecond, equals(10000));
  });
}
