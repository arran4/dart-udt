import 'dart:io';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _FakeEntry implements UdtCacheEntry<_FakeEntry> {
  _FakeEntry(this.key, this.value, {this.releaseCounter});

  @override
  final int key;
  final int value;
  final List<int>? releaseCounter;

  @override
  _FakeEntry clone() => _FakeEntry(key, value, releaseCounter: releaseCounter);

  @override
  void release() {
    releaseCounter?.add(value);
  }

  @override
  bool sameKey(_FakeEntry other) => key == other.key;
}

void main() {
  group('UdtLruCache', () {
    test('update and lookup mirror CCache insert/find semantics', () {
      final cache = UdtLruCache<_FakeEntry>(size: 3);

      expect(cache.update(_FakeEntry(10, 100)), 0);
      expect(cache.update(_FakeEntry(20, 200)), 0);

      _FakeEntry? found;
      expect(
        cache.lookup(_FakeEntry(10, -1), (_FakeEntry value) => found = value),
        0,
      );
      expect(found, isNotNull);
      expect(found!.value, 100);
    });

    test('update existing key replaces entry and keeps cache size', () {
      final releases = <int>[];
      final cache = UdtLruCache<_FakeEntry>(size: 2);

      cache.update(_FakeEntry(1, 100, releaseCounter: releases));
      cache.update(_FakeEntry(1, 101, releaseCounter: releases));

      _FakeEntry? found;
      expect(
        cache.lookup(_FakeEntry(1, 0), (_FakeEntry value) => found = value),
        0,
      );
      expect(found!.value, 101);
      expect(cache.size, 1);
      expect(releases, [100]);
    });

    test('overflow evicts oldest entry and calls release', () {
      final releases = <int>[];
      final cache = UdtLruCache<_FakeEntry>(size: 2);

      cache.update(_FakeEntry(1, 10, releaseCounter: releases));
      cache.update(_FakeEntry(2, 20, releaseCounter: releases));
      cache.update(_FakeEntry(3, 30, releaseCounter: releases));

      expect(releases, [10]);
      expect(cache.size, 2);
      expect(cache.lookup(_FakeEntry(1, 0), (_FakeEntry _) {}), -1);
      expect(cache.lookup(_FakeEntry(2, 0), (_FakeEntry _) {}), 0);
    });

    test('setSizeLimit trims storage and invalid key lookup fails', () {
      final cache = UdtLruCache<_FakeEntry>(size: 4);
      cache.update(_FakeEntry(1, 1));
      cache.update(_FakeEntry(2, 2));
      cache.update(_FakeEntry(3, 3));
      cache.setSizeLimit(2);

      expect(cache.size, 2);
      expect(cache.lookup(_FakeEntry(-1, 0), (_FakeEntry _) {}), -1);
      expect(() => cache.setSizeLimit(0), throwsA(isA<ArgumentError>()));
    });
  });

  group('UdtInfoBlock', () {
    test('IPv4 key/equality follow first-word matching', () {
      final local = InternetAddress('127.0.0.1');
      final words = UdtInfoBlock.convertIpWords(local);
      final a = UdtInfoBlock(
        ipWords: words,
        ipVersion: InternetAddressType.IPv4,
        timestampMicros: 1,
        rtt: 2,
        bandwidth: 3,
        lossRate: 4,
        reorderDistance: 5,
        packetSendInterval: 1.0,
        congestionWindow: 16.0,
      );
      final b = UdtInfoBlock(
        ipWords: List<int>.from(words),
        ipVersion: InternetAddressType.IPv4,
        timestampMicros: 9,
        rtt: 9,
        bandwidth: 9,
        lossRate: 9,
        reorderDistance: 9,
        packetSendInterval: 9.0,
        congestionWindow: 9.0,
      );

      expect(a.sameKey(b), isTrue);
      expect(a.key, words.first);
      expect(a.clone().ipWords, words);
    });

    test('IPv6 key/equality and conversion are deterministic', () {
      final ipv6 = InternetAddress('2001:db8::1');
      final words = UdtInfoBlock.convertIpWords(ipv6);

      final a = UdtInfoBlock(
        ipWords: words,
        ipVersion: InternetAddressType.IPv6,
        timestampMicros: 1,
        rtt: 2,
        bandwidth: 3,
        lossRate: 4,
        reorderDistance: 5,
        packetSendInterval: 6,
        congestionWindow: 7,
      );

      final b = UdtInfoBlock(
        ipWords: [words[0], words[1], words[2], words[3] + 1],
        ipVersion: InternetAddressType.IPv6,
        timestampMicros: 1,
        rtt: 2,
        bandwidth: 3,
        lossRate: 4,
        reorderDistance: 5,
        packetSendInterval: 6,
        congestionWindow: 7,
      );

      expect(words, hasLength(4));
      expect(a.sameKey(b), isFalse);
      expect(a.key, words.reduce((int left, int right) => left + right));
    });
  });
}
