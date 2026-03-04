import 'dart:collection';

/// Typed linked-list node model equivalent to upstream `CRNode`.
final class UdtReceiveNode<T> {
  UdtReceiveNode({
    required this.socketId,
    required this.value,
    required this.timestampMicros,
  });

  final int socketId;
  final T value;
  int timestampMicros;
  bool onList = false;
}

/// Pure-Dart port of upstream `CRcvUList` ordering behavior.
///
/// - `insert` appends to the tail.
/// - `remove` unlinks if present.
/// - `update` refreshes timestamp and moves node to tail.
final class UdtReceiveUserList<T> {
  final Queue<UdtReceiveNode<T>> _nodes = Queue<UdtReceiveNode<T>>();
  final Map<int, UdtReceiveNode<T>> _bySocketId = <int, UdtReceiveNode<T>>{};

  bool get isEmpty => _nodes.isEmpty;
  int get length => _nodes.length;

  UdtReceiveNode<T>? get head => _nodes.isEmpty ? null : _nodes.first;
  UdtReceiveNode<T>? get tail => _nodes.isEmpty ? null : _nodes.last;

  List<int>? _cachedSocketOrder;

  List<int> get socketOrder =>
      _cachedSocketOrder ??= _nodes.map((node) => node.socketId).toList();

  void insert({
    required int socketId,
    required T value,
    required int timestampMicros,
  }) {
    if (_bySocketId.containsKey(socketId)) {
      return;
    }

    final node = UdtReceiveNode<T>(
      socketId: socketId,
      value: value,
      timestampMicros: timestampMicros,
    );
    node.onList = true;
    _nodes.addLast(node);
    _bySocketId[socketId] = node;
    _cachedSocketOrder = null;
  }

  void remove(int socketId) {
    final node = _bySocketId.remove(socketId);
    if (node == null || !node.onList) {
      return;
    }

    node.onList = false;
    _nodes.remove(node);
    _cachedSocketOrder = null;
  }

  void update(int socketId, {required int timestampMicros}) {
    final node = _bySocketId[socketId];
    if (node == null || !node.onList) {
      return;
    }

    node.timestampMicros = timestampMicros;

    if (_nodes.isNotEmpty && identical(_nodes.last, node)) {
      return;
    }

    _nodes.remove(node);
    _nodes.addLast(node);
    _cachedSocketOrder = null;
  }
}

/// Bucket entry equivalent to upstream `CHash::CBucket`.
final class UdtHashBucket<T> {
  UdtHashBucket({required this.socketId, required this.value, this.next});

  final int socketId;
  final T value;
  UdtHashBucket<T>? next;
}

/// Pure-Dart hash-table port of upstream `CHash`.
///
/// Uses an explicit bucket chain instead of a plain `Map` so collision behavior
/// remains auditable against upstream `% hash-size` logic.
final class UdtSocketHash<T> {
  UdtSocketHash();

  late List<UdtHashBucket<T>?> _buckets;
  var _hashSize = 0;

  int get hashSize => _hashSize;

  void init(int size) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be > 0');
    }

    _hashSize = size;
    _buckets = List<UdtHashBucket<T>?>.filled(size, null);
  }

  T? lookup(int socketId) {
    _ensureInitialized();

    var bucket = _buckets[_index(socketId)];
    while (bucket != null) {
      if (bucket.socketId == socketId) {
        return bucket.value;
      }
      bucket = bucket.next;
    }

    return null;
  }

  void insert(int socketId, T value) {
    _ensureInitialized();

    final index = _index(socketId);
    final head = _buckets[index];
    final node = UdtHashBucket<T>(socketId: socketId, value: value, next: head);
    _buckets[index] = node;
  }

  void remove(int socketId) {
    _ensureInitialized();

    final index = _index(socketId);
    UdtHashBucket<T>? bucket = _buckets[index];
    UdtHashBucket<T>? previous;

    while (bucket != null) {
      if (bucket.socketId == socketId) {
        if (previous == null) {
          _buckets[index] = bucket.next;
        } else {
          previous.next = bucket.next;
        }
        return;
      }

      previous = bucket;
      bucket = bucket.next;
    }
  }

  int _index(int socketId) {
    final positive = socketId >= 0 ? socketId : -socketId;
    return positive % _hashSize;
  }

  void _ensureInitialized() {
    if (_hashSize == 0) {
      throw StateError('hash table is not initialized');
    }
  }
}
