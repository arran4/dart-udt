import 'dart:math' as math;

/// Sequence-number helpers ported from upstream `common.h` (`CSeqNo`, `CAckNo`,
/// and `CMsgNo`) with explicit modular arithmetic.
final class UdtSequenceNumber {
  UdtSequenceNumber._();

  static const int maxValue = 0x7FFFFFFF;
  static const int threshold = 0x3FFFFFFF;

  static int compare(int first, int second) {
    final delta = first - second;
    return (delta.abs() < threshold) ? delta : -delta;
  }

  static int lengthInclusive(int first, int second) {
    return (first <= second)
        ? (second - first + 1)
        : (second - first + maxValue + 2);
  }

  static int offset(int first, int second) {
    final delta = second - first;
    if ((first - second).abs() < threshold) {
      return delta;
    }

    if (first < second) {
      return delta - maxValue - 1;
    }

    return delta + maxValue + 1;
  }

  static int increment(int value, [int step = 1]) {
    if (step < 0) {
      throw ArgumentError.value(step, 'step', 'Must be >= 0');
    }

    if (step == 0) {
      return value;
    }

    return (maxValue - value >= step)
        ? value + step
        : value - maxValue + step - 1;
  }

  static int decrement(int value) => (value == 0) ? maxValue : value - 1;
}

/// ACK sub-sequence helper (upstream `CAckNo`).
final class UdtAckNumber {
  UdtAckNumber._();

  static const int maxValue = 0x7FFFFFFF;

  static int increment(int value) => (value == maxValue) ? 0 : value + 1;
}

/// Message-number helpers from upstream `CMsgNo`.
final class UdtMessageNumber {
  UdtMessageNumber._();

  static const int maxValue = 0x1FFFFFFF;
  static const int threshold = 0x0FFFFFFF;

  static int compare(int first, int second) {
    final delta = first - second;
    return (delta.abs() < threshold) ? delta : -delta;
  }

  static int lengthInclusive(int first, int second) {
    return (first <= second)
        ? (second - first + 1)
        : (second - first + maxValue + 2);
  }

  static int offset(int first, int second) {
    final delta = second - first;
    if ((first - second).abs() < threshold) {
      return delta;
    }

    if (first < second) {
      return delta - maxValue - 1;
    }

    return delta + maxValue + 1;
  }

  static int increment(int value) => (value == maxValue) ? 0 : value + 1;
}

/// Deterministic helper used by tests to exercise wraparound properties without
/// external fuzzing dependencies.
Iterable<int> generateDeterministicUdtValues({
  required int seed,
  required int count,
  required int max,
}) sync* {
  var state = seed;
  for (var i = 0; i < count; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    yield state % (max + 1);
  }

  // Ensure edge values are always sampled.
  yield 0;
  yield max;
  yield math.max(0, max ~/ 2);
}
