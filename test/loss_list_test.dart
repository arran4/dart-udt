import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  group('UdtSndLossList', () {
    test('insert coalesces overlaps and tracks added size', () {
      final list = UdtSndLossList();

      expect(list.insert(3, 5), 3);
      expect(list.insert(5, 7), 2);
      expect(list.insert(4, 6), 0);
      expect(list.lossLength, 5);
    });

    test('remove trims prefix and getLostSeq drains in order', () {
      final list = UdtSndLossList();
      list.insert(10, 12);
      list.insert(20, 20);

      list.remove(10);
      expect(list.lossLength, 3);
      expect(list.getLostSeq(), 11);
      expect(list.getLostSeq(), 12);
      expect(list.getLostSeq(), 20);
      expect(list.getLostSeq(), -1);
    });
  });

  group('UdtRcvLossList', () {
    test('insert/remove/find maintain interval semantics', () {
      final list = UdtRcvLossList();
      list.insert(100, 103);
      list.insert(106, 108);

      expect(list.lossLength, 7);
      expect(list.find(102, 102), isTrue);
      expect(list.remove(103), isTrue);
      expect(list.remove(107), isTrue);
      expect(list.remove(999), isFalse);
      expect(list.lossLength, 5);
      expect(list.find(107, 107), isFalse);
      expect(list.firstLostSeq, 100);
    });

    test('removeRange and getLossArray encode upstream nak layout', () {
      final list = UdtRcvLossList();
      list.insert(50, 55);
      list.insert(60, 60);

      expect(list.removeRange(52, 53), isTrue);
      expect(list.lossLength, 5);
      expect(
        list.getLossArray(limit: 8),
        <int>[50 | 0x80000000, 51, 54 | 0x80000000, 55, 60],
      );
    });
  });
}
