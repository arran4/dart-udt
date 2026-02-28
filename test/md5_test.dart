import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  String toHex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  test('md5 hash matches RFC1321 vectors', () {
    final cases = <String, String>{
      '': 'd41d8cd98f00b204e9800998ecf8427e',
      'a': '0cc175b9c0f1b6a831c399e269772661',
      'abc': '900150983cd24fb0d6963f7d28e17f72',
      'message digest': 'f96b697d7cb7938d525a2f31aaf161d0',
      'abcdefghijklmnopqrstuvwxyz': 'c3fcd3d76192e4007dfb496cca67e13b',
    };

    for (final entry in cases.entries) {
      final digest = UdtMd5.hash(Uint8List.fromList(utf8.encode(entry.key)));
      expect(toHex(digest), equals(entry.value), reason: 'input: ${entry.key}');
    }
  });

  test('md5 append supports incremental chunking', () {
    final md5 = UdtMd5();
    md5.append(Uint8List.fromList(utf8.encode('abc')));
    md5.append(Uint8List.fromList(utf8.encode('defghijklmnopqrstuvwxyz')));

    expect(toHex(md5.finish()), equals('c3fcd3d76192e4007dfb496cca67e13b'));
  });

  test('finish resets state for reuse', () {
    final md5 = UdtMd5();
    md5.append(Uint8List.fromList(utf8.encode('abc')));
    expect(toHex(md5.finish()), equals('900150983cd24fb0d6963f7d28e17f72'));

    md5.append(Uint8List.fromList(utf8.encode('a')));
    expect(toHex(md5.finish()), equals('0cc175b9c0f1b6a831c399e269772661'));
  });
}
