import 'dart:io';

import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('toWords and fromWords round-trip IPv4 deterministically', () {
    final ip = InternetAddress('10.20.30.40');

    final words = UdtIpAddress.toWords(ip);
    expect(words, hasLength(4));
    expect(words[1], 0);
    expect(words[2], 0);
    expect(words[3], 0);

    final restored = UdtIpAddress.fromWords(words, type: InternetAddressType.IPv4);
    expect(UdtIpAddress.compare(ip, restored), isTrue);
  });

  test('toWords and fromWords round-trip IPv6 deterministically', () {
    final ip = InternetAddress('2001:db8::1234');

    final words = UdtIpAddress.toWords(ip);
    expect(words, hasLength(4));

    final restored = UdtIpAddress.fromWords(words, type: InternetAddressType.IPv6);
    expect(UdtIpAddress.compare(ip, restored), isTrue);
  });

  test('compare returns false for different values or versions', () {
    final ipv4A = InternetAddress('127.0.0.1');
    final ipv4B = InternetAddress('127.0.0.2');
    final ipv6 = InternetAddress('::1');

    expect(UdtIpAddress.compare(ipv4A, ipv4A), isTrue);
    expect(UdtIpAddress.compare(ipv4A, ipv4B), isFalse);
    expect(UdtIpAddress.compare(ipv4A, ipv6), isFalse);
  });

  test('fromWords validates word count', () {
    expect(
      () => UdtIpAddress.fromWords([1, 2, 3], type: InternetAddressType.IPv4),
      throwsA(isA<ArgumentError>()),
    );
  });
}
