import 'dart:typed_data';

/// Pure-Dart MD5 implementation ported from upstream `md5.h`/`md5.cpp`
/// (original RFC1321-based implementation by L. Peter Deutsch).
final class UdtMd5 {
  UdtMd5() {
    reset();
  }

  static const int _blockSize = 64;
  static const int _digestSize = 16;

  final Uint8List _buffer = Uint8List(_blockSize);
  final Uint32List _state = Uint32List(4);
  int _bufferLength = 0;
  int _bitCountLow = 0;
  int _bitCountHigh = 0;

  void reset() {
    _bitCountLow = 0;
    _bitCountHigh = 0;
    _bufferLength = 0;

    _state[0] = 0x67452301;
    _state[1] = 0xEFCDAB89;
    _state[2] = 0x98BADCFE;
    _state[3] = 0x10325476;
  }

  void append(Uint8List data) {
    if (data.isEmpty) {
      return;
    }

    final bitLength = (data.length << 3) & 0xFFFFFFFF;
    _bitCountHigh = (_bitCountHigh + (data.length >> 29)) & 0xFFFFFFFF;
    _bitCountLow = (_bitCountLow + bitLength) & 0xFFFFFFFF;
    if (_bitCountLow < bitLength) {
      _bitCountHigh = (_bitCountHigh + 1) & 0xFFFFFFFF;
    }

    var inputOffset = 0;
    var remaining = data.length;

    if (_bufferLength > 0) {
      final toCopy = remaining < (_blockSize - _bufferLength)
          ? remaining
          : (_blockSize - _bufferLength);
      _buffer.setRange(
        _bufferLength,
        _bufferLength + toCopy,
        data,
        inputOffset,
      );
      _bufferLength += toCopy;
      inputOffset += toCopy;
      remaining -= toCopy;

      if (_bufferLength == _blockSize) {
        _processBlock(_buffer, 0);
        _bufferLength = 0;
      }
    }

    while (remaining >= _blockSize) {
      _processBlock(data, inputOffset);
      inputOffset += _blockSize;
      remaining -= _blockSize;
    }

    if (remaining > 0) {
      _buffer.setRange(0, remaining, data, inputOffset);
      _bufferLength = remaining;
    }
  }

  Uint8List finish() {
    final savedLow = _bitCountLow;
    final savedHigh = _bitCountHigh;

    final padLength = _bufferLength < 56
        ? 56 - _bufferLength
        : 120 - _bufferLength;
    final padding = Uint8List(padLength);
    padding[0] = 0x80;
    append(padding);

    final lengthBytes = Uint8List(8);
    final lengthData = ByteData.sublistView(lengthBytes);
    lengthData.setUint32(0, savedLow, Endian.little);
    lengthData.setUint32(4, savedHigh, Endian.little);
    append(lengthBytes);

    final digest = Uint8List(_digestSize);
    final digestData = ByteData.sublistView(digest);
    digestData.setUint32(0, _state[0], Endian.little);
    digestData.setUint32(4, _state[1], Endian.little);
    digestData.setUint32(8, _state[2], Endian.little);
    digestData.setUint32(12, _state[3], Endian.little);

    reset();
    return digest;
  }

  static Uint8List hash(Uint8List data) {
    final md5 = UdtMd5();
    md5.append(data);
    return md5.finish();
  }

  void _processBlock(Uint8List bytes, int offset) {
    final words = Uint32List(16);
    final blockData = ByteData.sublistView(bytes, offset, offset + _blockSize);
    for (var i = 0; i < 16; i++) {
      words[i] = blockData.getUint32(i * 4, Endian.little);
    }

    var a = _state[0];
    var b = _state[1];
    var c = _state[2];
    var d = _state[3];

    int ff(int x, int y, int z) => (x & y) | (~x & z);
    int gg(int x, int y, int z) => (x & z) | (y & ~z);
    int hh(int x, int y, int z) => x ^ y ^ z;
    int ii(int x, int y, int z) => y ^ (x | ~z);

    int rotateLeft(int value, int bits) =>
        ((value << bits) | (value >>> (32 - bits))) & 0xFFFFFFFF;

    int round(
      int aa,
      int bb,
      int cc,
      int dd,
      int x,
      int s,
      int t,
      int Function(int, int, int) fn,
    ) {
      final sum = (aa + fn(bb, cc, dd) + x + t) & 0xFFFFFFFF;
      return (rotateLeft(sum, s) + bb) & 0xFFFFFFFF;
    }

    a = round(a, b, c, d, words[0], 7, 0xD76AA478, ff);
    d = round(d, a, b, c, words[1], 12, 0xE8C7B756, ff);
    c = round(c, d, a, b, words[2], 17, 0x242070DB, ff);
    b = round(b, c, d, a, words[3], 22, 0xC1BDCEEE, ff);
    a = round(a, b, c, d, words[4], 7, 0xF57C0FAF, ff);
    d = round(d, a, b, c, words[5], 12, 0x4787C62A, ff);
    c = round(c, d, a, b, words[6], 17, 0xA8304613, ff);
    b = round(b, c, d, a, words[7], 22, 0xFD469501, ff);
    a = round(a, b, c, d, words[8], 7, 0x698098D8, ff);
    d = round(d, a, b, c, words[9], 12, 0x8B44F7AF, ff);
    c = round(c, d, a, b, words[10], 17, 0xFFFF5BB1, ff);
    b = round(b, c, d, a, words[11], 22, 0x895CD7BE, ff);
    a = round(a, b, c, d, words[12], 7, 0x6B901122, ff);
    d = round(d, a, b, c, words[13], 12, 0xFD987193, ff);
    c = round(c, d, a, b, words[14], 17, 0xA679438E, ff);
    b = round(b, c, d, a, words[15], 22, 0x49B40821, ff);

    a = round(a, b, c, d, words[1], 5, 0xF61E2562, gg);
    d = round(d, a, b, c, words[6], 9, 0xC040B340, gg);
    c = round(c, d, a, b, words[11], 14, 0x265E5A51, gg);
    b = round(b, c, d, a, words[0], 20, 0xE9B6C7AA, gg);
    a = round(a, b, c, d, words[5], 5, 0xD62F105D, gg);
    d = round(d, a, b, c, words[10], 9, 0x02441453, gg);
    c = round(c, d, a, b, words[15], 14, 0xD8A1E681, gg);
    b = round(b, c, d, a, words[4], 20, 0xE7D3FBC8, gg);
    a = round(a, b, c, d, words[9], 5, 0x21E1CDE6, gg);
    d = round(d, a, b, c, words[14], 9, 0xC33707D6, gg);
    c = round(c, d, a, b, words[3], 14, 0xF4D50D87, gg);
    b = round(b, c, d, a, words[8], 20, 0x455A14ED, gg);
    a = round(a, b, c, d, words[13], 5, 0xA9E3E905, gg);
    d = round(d, a, b, c, words[2], 9, 0xFCEFA3F8, gg);
    c = round(c, d, a, b, words[7], 14, 0x676F02D9, gg);
    b = round(b, c, d, a, words[12], 20, 0x8D2A4C8A, gg);

    a = round(a, b, c, d, words[5], 4, 0xFFFA3942, hh);
    d = round(d, a, b, c, words[8], 11, 0x8771F681, hh);
    c = round(c, d, a, b, words[11], 16, 0x6D9D6122, hh);
    b = round(b, c, d, a, words[14], 23, 0xFDE5380C, hh);
    a = round(a, b, c, d, words[1], 4, 0xA4BEEA44, hh);
    d = round(d, a, b, c, words[4], 11, 0x4BDECFA9, hh);
    c = round(c, d, a, b, words[7], 16, 0xF6BB4B60, hh);
    b = round(b, c, d, a, words[10], 23, 0xBEBFBC70, hh);
    a = round(a, b, c, d, words[13], 4, 0x289B7EC6, hh);
    d = round(d, a, b, c, words[0], 11, 0xEAA127FA, hh);
    c = round(c, d, a, b, words[3], 16, 0xD4EF3085, hh);
    b = round(b, c, d, a, words[6], 23, 0x04881D05, hh);
    a = round(a, b, c, d, words[9], 4, 0xD9D4D039, hh);
    d = round(d, a, b, c, words[12], 11, 0xE6DB99E5, hh);
    c = round(c, d, a, b, words[15], 16, 0x1FA27CF8, hh);
    b = round(b, c, d, a, words[2], 23, 0xC4AC5665, hh);

    a = round(a, b, c, d, words[0], 6, 0xF4292244, ii);
    d = round(d, a, b, c, words[7], 10, 0x432AFF97, ii);
    c = round(c, d, a, b, words[14], 15, 0xAB9423A7, ii);
    b = round(b, c, d, a, words[5], 21, 0xFC93A039, ii);
    a = round(a, b, c, d, words[12], 6, 0x655B59C3, ii);
    d = round(d, a, b, c, words[3], 10, 0x8F0CCC92, ii);
    c = round(c, d, a, b, words[10], 15, 0xFFEFF47D, ii);
    b = round(b, c, d, a, words[1], 21, 0x85845DD1, ii);
    a = round(a, b, c, d, words[8], 6, 0x6FA87E4F, ii);
    d = round(d, a, b, c, words[15], 10, 0xFE2CE6E0, ii);
    c = round(c, d, a, b, words[6], 15, 0xA3014314, ii);
    b = round(b, c, d, a, words[13], 21, 0x4E0811A1, ii);
    a = round(a, b, c, d, words[4], 6, 0xF7537E82, ii);
    d = round(d, a, b, c, words[11], 10, 0xBD3AF235, ii);
    c = round(c, d, a, b, words[2], 15, 0x2AD7D2BB, ii);
    b = round(b, c, d, a, words[9], 21, 0xEB86D391, ii);

    _state[0] = (_state[0] + a) & 0xFFFFFFFF;
    _state[1] = (_state[1] + b) & 0xFFFFFFFF;
    _state[2] = (_state[2] + c) & 0xFFFFFFFF;
    _state[3] = (_state[3] + d) & 0xFFFFFFFF;
  }
}
