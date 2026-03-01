import 'dart:io';
import 'dart:typed_data';

/// Base cache-entry contract mirroring upstream `CCacheItem` semantics.
abstract interface class UdtCacheEntry<T extends UdtCacheEntry<T>> {
  /// Returns a deterministic hash key used for cache-bucket selection.
  int get key;

  /// Key-equality matcher (upstream `operator==` compares key fields only).
  bool sameKey(T other);

  /// Deep clone of this entry (upstream `clone`).
  T clone();

  /// Releases shared resources, if any (upstream `release`).
  void release() {}
}

/// Pure-Dart LRU cache port for upstream `CCache<T>` in `cache.h`.
final class UdtLruCache<T extends UdtCacheEntry<T>> {
  UdtLruCache({int size = 1024})
    : _maxSize = size,
      _hashSize = size * 3 {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }
  }

  int _maxSize;
  int _hashSize;

  final List<T> _storage = <T>[];

  int get size => _storage.length;

  int lookup(T probe, void Function(T value) onFound) {
    final bucket = _normalizeKey(probe.key);
    if (bucket == null) {
      return -1;
    }

    for (final item in _storage) {
      if (_normalizeKey(item.key) == bucket && probe.sameKey(item)) {
        onFound(item.clone());
        return 0;
      }
    }

    return -1;
  }

  int update(T data) {
    final bucket = _normalizeKey(data.key);
    if (bucket == null) {
      return -1;
    }

    for (var i = 0; i < _storage.length; i++) {
      final item = _storage[i];
      if (_normalizeKey(item.key) == bucket && data.sameKey(item)) {
        item.release();
        _storage.removeAt(i);
        _storage.insert(0, data.clone());
        return 0;
      }
    }

    _storage.insert(0, data.clone());

    if (_storage.length > _maxSize) {
      final removed = _storage.removeLast();
      removed.release();
    }

    return 0;
  }

  void setSizeLimit(int size) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }

    _maxSize = size;
    _hashSize = size * 3;

    while (_storage.length > _maxSize) {
      final removed = _storage.removeLast();
      removed.release();
    }
  }

  void clear() {
    for (final entry in _storage) {
      entry.release();
    }
    _storage.clear();
  }

  int? _normalizeKey(int key) {
    if (key < 0) {
      return null;
    }

    if (key >= _maxSize) {
      return key % _hashSize;
    }

    return key;
  }
}

/// Typed equivalent of upstream `CInfoBlock` in `cache.h`/`cache.cpp`.
final class UdtInfoBlock implements UdtCacheEntry<UdtInfoBlock> {
  const UdtInfoBlock({
    required this.ipWords,
    required this.ipVersion,
    required this.timestampMicros,
    required this.rtt,
    required this.bandwidth,
    required this.lossRate,
    required this.reorderDistance,
    required this.packetSendInterval,
    required this.congestionWindow,
  }) : assert(ipWords.length == 4, 'ipWords must contain exactly 4 words');

  final List<int> ipWords;
  final InternetAddressType ipVersion;
  final int timestampMicros;
  final int rtt;
  final int bandwidth;
  final int lossRate;
  final int reorderDistance;
  final double packetSendInterval;
  final double congestionWindow;

  @override
  int get key {
    if (ipVersion == InternetAddressType.IPv4) {
      return ipWords[0];
    }

    return ipWords[0] + ipWords[1] + ipWords[2] + ipWords[3];
  }

  @override
  bool sameKey(UdtInfoBlock other) {
    if (ipVersion != other.ipVersion) {
      return false;
    }

    if (ipVersion == InternetAddressType.IPv4) {
      return ipWords[0] == other.ipWords[0];
    }

    for (var i = 0; i < 4; i++) {
      if (ipWords[i] != other.ipWords[i]) {
        return false;
      }
    }

    return true;
  }

  @override
  UdtInfoBlock clone() => UdtInfoBlock(
    ipWords: List<int>.from(ipWords),
    ipVersion: ipVersion,
    timestampMicros: timestampMicros,
    rtt: rtt,
    bandwidth: bandwidth,
    lossRate: lossRate,
    reorderDistance: reorderDistance,
    packetSendInterval: packetSendInterval,
    congestionWindow: congestionWindow,
  );

  /// Port of `CInfoBlock::convert` using deterministic word layout.
  static List<int> convertIpWords(InternetAddress address) {
    final raw = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final word = ByteData.sublistView(Uint8List.fromList(raw)).getUint32(0);
      return <int>[word, 0, 0, 0];
    }

    final bytes = Uint8List.fromList(raw);
    final data = ByteData.sublistView(bytes);
    return <int>[
      data.getUint32(0),
      data.getUint32(4),
      data.getUint32(8),
      data.getUint32(12),
    ];
  }
}
