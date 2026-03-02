import '../common/sequence_numbers.dart';

/// Pure-Dart port of upstream sender/receiver loss lists from `list.h/.cpp`.
///
/// The original C++ used fixed node arrays and pointer links. This Dart port
/// keeps the same observable list operations with typed interval containers.
final class UdtSndLossList {
  final List<_SeqInterval> _intervals = <_SeqInterval>[];

  int get lossLength => _intervals.fold<int>(
        0,
        (int sum, _SeqInterval interval) =>
            sum +
            UdtSequenceNumber.lengthInclusive(interval.start, interval.end),
      );

  /// Inserts [seqno1, seqno2] and returns number of newly-added sequence IDs.
  int insert(int seqno1, int seqno2) {
    final normalized = _normalize(seqno1, seqno2);
    final before = lossLength;
    _insertInterval(normalized);
    return lossLength - before;
  }

  /// Removes all sequence numbers <= [seqno] in current sequence order.
  void remove(int seqno) {
    while (_intervals.isNotEmpty) {
      final first = _intervals.first;
      if (_compare(first.start, seqno) > 0) {
        return;
      }

      if (_compare(first.end, seqno) <= 0) {
        _intervals.removeAt(0);
        continue;
      }

      first.start = UdtSequenceNumber.increment(seqno);
      return;
    }
  }

  /// Returns and removes the first lost sequence number, or `-1` if empty.
  int getLostSeq() {
    if (_intervals.isEmpty) {
      return -1;
    }

    final first = _intervals.first;
    final value = first.start;
    if (first.start == first.end) {
      _intervals.removeAt(0);
    } else {
      first.start = UdtSequenceNumber.increment(first.start);
    }
    return value;
  }

  void _insertInterval(_SeqInterval incoming) {
    if (_intervals.isEmpty) {
      _intervals.add(incoming);
      return;
    }

    var inserted = false;
    for (var i = 0; i < _intervals.length; i++) {
      final current = _intervals[i];
      if (!inserted && _compare(incoming.start, current.start) < 0) {
        _intervals.insert(i, incoming);
        inserted = true;
        break;
      }
    }
    if (!inserted) {
      _intervals.add(incoming);
    }

    _coalesce();
  }

  void _coalesce() {
    var i = 0;
    while (i < _intervals.length - 1) {
      final current = _intervals[i];
      final next = _intervals[i + 1];
      final adjacent = UdtSequenceNumber.increment(current.end) == next.start;
      final overlaps = _contains(current.start, current.end, next.start);
      if (adjacent || overlaps) {
        if (_compare(next.end, current.end) > 0) {
          current.end = next.end;
        }
        _intervals.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }
}

/// Pure-Dart port of upstream `CRcvLossList`.
final class UdtRcvLossList {
  final List<_SeqInterval> _intervals = <_SeqInterval>[];

  int get lossLength => _intervals.fold<int>(
        0,
        (int sum, _SeqInterval interval) =>
            sum +
            UdtSequenceNumber.lengthInclusive(interval.start, interval.end),
      );

  int get firstLostSeq => _intervals.isEmpty ? -1 : _intervals.first.start;

  void insert(int seqno1, int seqno2) {
    final interval = _normalize(seqno1, seqno2);
    if (_intervals.isEmpty) {
      _intervals.add(interval);
      return;
    }

    _intervals.add(interval);
    _intervals.sort(
      (_SeqInterval left, _SeqInterval right) =>
          _compare(left.start, right.start),
    );
    _coalesce();
  }

  bool remove(int seqno) {
    for (var i = 0; i < _intervals.length; i++) {
      final interval = _intervals[i];
      if (!_contains(interval.start, interval.end, seqno)) {
        continue;
      }

      if (interval.start == interval.end) {
        _intervals.removeAt(i);
        return true;
      }

      if (interval.start == seqno) {
        interval.start = UdtSequenceNumber.increment(interval.start);
        return true;
      }

      if (interval.end == seqno) {
        interval.end = UdtSequenceNumber.decrement(interval.end);
        return true;
      }

      final tail = _SeqInterval(
        UdtSequenceNumber.increment(seqno),
        interval.end,
      );
      interval.end = UdtSequenceNumber.decrement(seqno);
      _intervals.insert(i + 1, tail);
      return true;
    }

    return false;
  }

  bool removeRange(int seqno1, int seqno2) {
    var removed = false;
    var value = seqno1;
    while (true) {
      removed = remove(value) || removed;
      if (value == seqno2) {
        break;
      }
      value = UdtSequenceNumber.increment(value);
    }
    return removed;
  }

  bool find(int seqno1, int seqno2) {
    for (final interval in _intervals) {
      if (_contains(seqno1, seqno2, interval.start) ||
          _contains(interval.start, interval.end, seqno1)) {
        return true;
      }
    }
    return false;
  }

  /// Encoded NAK payload layout from upstream: range starts with high-bit set.
  List<int> getLossArray({required int limit}) {
    final result = <int>[];
    for (final interval in _intervals) {
      if (result.length >= limit - 1) {
        break;
      }

      if (interval.start == interval.end) {
        result.add(interval.start);
      } else {
        result.add(interval.start | 0x80000000);
        result.add(interval.end);
      }
    }
    return result;
  }

  void _coalesce() {
    var i = 0;
    while (i < _intervals.length - 1) {
      final current = _intervals[i];
      final next = _intervals[i + 1];
      final adjacent = UdtSequenceNumber.increment(current.end) == next.start;
      final overlaps = _contains(current.start, current.end, next.start);
      if (adjacent || overlaps) {
        if (_compare(next.end, current.end) > 0) {
          current.end = next.end;
        }
        _intervals.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }
}

int _compare(int first, int second) => UdtSequenceNumber.compare(first, second);

_SeqInterval _normalize(int seqno1, int seqno2) {
  if (_compare(seqno1, seqno2) <= 0) {
    return _SeqInterval(seqno1, seqno2);
  }

  return _SeqInterval(seqno2, seqno1);
}

bool _contains(int start, int end, int value) {
  final length = UdtSequenceNumber.offset(start, end);
  final offset = UdtSequenceNumber.offset(start, value);
  return offset >= 0 && offset <= length;
}

final class _SeqInterval {
  _SeqInterval(this.start, this.end);

  int start;
  int end;
}
