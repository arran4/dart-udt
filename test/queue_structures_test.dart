import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  group('UdtReceiveUserList', () {
    test('insert appends and remove unlinks', () {
      final list = UdtReceiveUserList<String>();

      list.insert(socketId: 11, value: 'a', timestampMicros: 10);
      list.insert(socketId: 22, value: 'b', timestampMicros: 20);

      expect(list.socketOrder, <int>[11, 22]);
      expect(list.head?.socketId, 11);
      expect(list.tail?.socketId, 22);

      list.remove(11);
      expect(list.socketOrder, <int>[22]);
      expect(list.head?.socketId, 22);
      expect(list.tail?.socketId, 22);
    });

    test('update refreshes timestamp and moves node to tail', () {
      final list = UdtReceiveUserList<String>();

      list.insert(socketId: 1, value: 'one', timestampMicros: 100);
      list.insert(socketId: 2, value: 'two', timestampMicros: 200);
      list.insert(socketId: 3, value: 'three', timestampMicros: 300);

      list.update(2, timestampMicros: 999);

      expect(list.socketOrder, <int>[1, 3, 2]);
      expect(list.tail?.socketId, 2);
      expect(list.tail?.timestampMicros, 999);
    });

    test('duplicate insert and missing update/remove are no-op', () {
      final list = UdtReceiveUserList<String>();

      list.insert(socketId: 7, value: 'first', timestampMicros: 1);
      list.insert(socketId: 7, value: 'duplicate', timestampMicros: 2);
      list.update(99, timestampMicros: 5);
      list.remove(99);

      expect(list.length, 1);
      expect(list.head?.value, 'first');
    });
  });

  group('UdtSocketHash', () {
    test('requires init before operations', () {
      final hash = UdtSocketHash<String>();

      expect(() => hash.lookup(1), throwsStateError);
      expect(() => hash.insert(1, 'x'), throwsStateError);
      expect(() => hash.remove(1), throwsStateError);
    });

    test('supports chained collisions and remove of middle/head nodes', () {
      final hash = UdtSocketHash<String>()..init(4);

      hash.insert(4, 'a');
      hash.insert(8, 'b');
      hash.insert(12, 'c');

      expect(hash.lookup(4), 'a');
      expect(hash.lookup(8), 'b');
      expect(hash.lookup(12), 'c');

      hash.remove(8);
      expect(hash.lookup(8), isNull);
      expect(hash.lookup(4), 'a');
      expect(hash.lookup(12), 'c');

      hash.remove(12);
      expect(hash.lookup(12), isNull);
      expect(hash.lookup(4), 'a');

      hash.remove(4);
      expect(hash.lookup(4), isNull);
    });

    test('rejects non-positive init size', () {
      final hash = UdtSocketHash<int>();
      expect(() => hash.init(0), throwsArgumentError);
    });
  });
}
