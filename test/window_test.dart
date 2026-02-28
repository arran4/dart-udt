import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  group('UdtAckWindow', () {
    test('stores and acknowledges with deterministic RTT', () {
      final clock = UdtFakeClock(initialMicros: 1000);
      final window = UdtAckWindow(clock: clock, size: 4);

      window.store(10, 100);
      clock.advanceMicros(55);
      final acknowledged = window.acknowledge(10);

      expect(acknowledged, isNotNull);
      expect(acknowledged!.ackNumber, 100);
      expect(acknowledged.rttMicros, 55);
    });

    test('returns null once record is overwritten in circular buffer', () {
      final clock = UdtFakeClock();
      final window = UdtAckWindow(clock: clock, size: 2);

      window.store(1, 10);
      window.store(2, 20);
      window.store(3, 30);

      expect(window.acknowledge(1), isNull);
      expect(window.acknowledge(3), isNotNull);
    });
  });

  group('UdtPacketTimeWindow', () {
    test('tracks minimum packet send interval', () {
      final clock = UdtFakeClock();
      final window = UdtPacketTimeWindow(clock: clock);

      window.onPacketSent(1000);
      window.onPacketSent(1400);
      window.onPacketSent(2000);

      expect(window.minPacketSendIntervalMicros, 400);
    });

    test('derives packet receive speed from deterministic arrivals', () {
      final clock = UdtFakeClock();
      final window = UdtPacketTimeWindow(clock: clock, arrivalWindowSize: 8);

      for (var i = 0; i < 8; i++) {
        clock.advanceMicros(1000);
        window.onPacketArrival();
      }

      expect(window.getPacketReceiveSpeedPacketsPerSecond(), 1000);
    });

    test('derives probe-based bandwidth from deterministic probe pairs', () {
      final clock = UdtFakeClock();
      final window = UdtPacketTimeWindow(clock: clock, probeWindowSize: 8);

      for (var i = 0; i < 8; i++) {
        window.probe1Arrival();
        clock.advanceMicros(500);
        window.probe2Arrival();
      }

      expect(window.getBandwidthPacketsPerSecond(), 2000);
    });
  });
}
