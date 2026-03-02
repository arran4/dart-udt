import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('sequence number helpers preserve wraparound behavior', () {
    expect(UdtSequenceNumber.increment(UdtSequenceNumber.maxValue), equals(0));
    expect(UdtSequenceNumber.decrement(0), equals(UdtSequenceNumber.maxValue));
    expect(
      UdtSequenceNumber.lengthInclusive(UdtSequenceNumber.maxValue, 2),
      equals(4),
    );
    expect(UdtSequenceNumber.offset(UdtSequenceNumber.maxValue, 1), equals(2));
  });

  test('ack and message helpers mirror upstream maxima', () {
    expect(UdtAckNumber.increment(UdtAckNumber.maxValue), equals(0));
    expect(UdtMessageNumber.increment(UdtMessageNumber.maxValue), equals(0));
    expect(
      UdtMessageNumber.lengthInclusive(UdtMessageNumber.maxValue, 1),
      equals(3),
    );
  });

  test('deterministic generated values include edge values', () {
    final values = generateDeterministicUdtValues(
      seed: 7,
      count: 12,
      max: UdtSequenceNumber.maxValue,
    ).toList();

    expect(values, contains(0));
    expect(values, contains(UdtSequenceNumber.maxValue));
    expect(values, contains(UdtSequenceNumber.maxValue ~/ 2));
  });

  test('packet header parse/serialize survives deterministic corpus', () {
    final corpus = generateDeterministicUdtValues(
      seed: 99,
      count: 64,
      max: 0x7FFFFFFF,
    ).toList();

    for (var i = 0; i + 4 < corpus.length; i += 5) {
      final dataHeader = UdtPacketHeader.data(
        sequenceNumber: corpus[i],
        timestamp: corpus[i + 1],
        destinationSocketId: corpus[i + 2],
      );
      final dataReparsed = UdtPacketHeader.parse(dataHeader.toBytes());
      expect(dataReparsed.sequenceNumber, equals(corpus[i]));
      expect(dataReparsed.timestamp, equals(corpus[i + 1]));
      expect(dataReparsed.destinationSocketId, equals(corpus[i + 2]));

      final controlHeader = UdtPacketHeader.control(
        controlType: corpus[i + 3] & 0x7FFF,
        controlReserved: corpus[i + 4] & 0xFFFF,
        additionalInfo: corpus[i + 1],
        timestamp: corpus[i + 2],
        destinationSocketId: corpus[i + 3],
      );
      final controlReparsed = UdtPacketHeader.parse(controlHeader.toBytes());
      expect(controlReparsed.controlType, equals(corpus[i + 3] & 0x7FFF));
      expect(controlReparsed.controlReserved, equals(corpus[i + 4] & 0xFFFF));
      expect(controlReparsed.additionalInfo, equals(corpus[i + 1]));
    }
  });
}
