import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('default congestion control init mirrors CUDTCC defaults', () {
    var now = 0;
    final cc = UdtDefaultCongestionControl(nowMicros: () => now);

    cc.setSendCurrentSequenceNumber(1000);
    cc.init();

    expect(cc.congestionWindowSize, equals(16.0));
    expect(cc.packetSendPeriodMicros, equals(1.0));
    expect(cc.ackPeriodMillis, equals(cc.synIntervalMillis));
  });

  test('onAck in slow start increases window after rate-control interval', () {
    var now = 0;
    final cc = UdtDefaultCongestionControl(nowMicros: () => now);

    cc.setSendCurrentSequenceNumber(10);
    cc.setMaxCongestionWindowSize(1000);
    cc.init();

    now = cc.synIntervalMillis * 1000;
    cc.onAck(14);

    expect(cc.congestionWindowSize, equals(21.0));
    expect(cc.packetSendPeriodMicros, equals(1.0));
  });

  test('onLoss leaves slow start and applies deterministic decrease branches', () {
    var now = 0;
    final cc = UdtDefaultCongestionControl(
      nowMicros: () => now,
      seededRandomFraction: (_) => 0.0,
    );

    cc
      ..setSendCurrentSequenceNumber(50)
      ..setRoundTripTimeMicros(100)
      ..setReceiveRate(0)
      ..setMaxCongestionWindowSize(1000);
    cc.init();

    cc.onLoss([80]);
    final afterFirstLoss = cc.packetSendPeriodMicros;
    expect(afterFirstLoss, greaterThan(1.0));

    cc.setSendCurrentSequenceNumber(60);
    cc.onLoss([40]);

    expect(cc.packetSendPeriodMicros, greaterThan(afterFirstLoss));
  });

  test('onTimeout in slow start sets period from receive rate', () {
    var now = 0;
    final cc = UdtDefaultCongestionControl(nowMicros: () => now);

    cc
      ..setSendCurrentSequenceNumber(1)
      ..setReceiveRate(2000);
    cc.init();

    cc.onTimeout();

    expect(cc.packetSendPeriodMicros, closeTo(500.0, 0.0001));
  });

  test('onAck outside slow start performs rate increase when no loss reported', () {
    var now = 0;
    final cc = UdtDefaultCongestionControl(nowMicros: () => now);

    cc
      ..setSendCurrentSequenceNumber(100)
      ..setReceiveRate(2000)
      ..setMaximumSegmentSize(1500)
      ..setBandwidth(5000)
      ..setRoundTripTimeMicros(1000)
      ..setMaxCongestionWindowSize(1);
    cc.init();

    now = cc.synIntervalMillis * 1000;
    cc.onAck(101);
    final beforeIncrease = cc.packetSendPeriodMicros;

    now += cc.synIntervalMillis * 1000;
    cc.onAck(102);

    expect(cc.packetSendPeriodMicros, lessThan(beforeIncrease));
  });
}
