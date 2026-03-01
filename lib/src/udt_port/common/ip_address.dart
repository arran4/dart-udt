import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart IP helpers mirroring upstream `CIPAddress` from `common.h`.
final class UdtIpAddress {
  UdtIpAddress._();

  /// Equivalent to upstream `CIPAddress::ipcmp` over normalized word arrays.
  static bool compare(
    InternetAddress first,
    InternetAddress second,
  ) {
    if (first.type != second.type) {
      return false;
    }

    final left = toWords(first);
    final right = toWords(second);
    for (var i = 0; i < 4; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  /// Equivalent to upstream `CIPAddress::ntop` into fixed 4-word layout.
  static List<int> toWords(InternetAddress address) {
    final raw = Uint8List.fromList(address.rawAddress);
    final data = ByteData.sublistView(raw);
    if (address.type == InternetAddressType.IPv4) {
      return <int>[data.getUint32(0), 0, 0, 0];
    }

    return <int>[
      data.getUint32(0),
      data.getUint32(4),
      data.getUint32(8),
      data.getUint32(12),
    ];
  }

  /// Equivalent to upstream `CIPAddress::pton` from fixed-word layout.
  static InternetAddress fromWords(
    List<int> words, {
    required InternetAddressType type,
  }) {
    if (words.length != 4) {
      throw ArgumentError.value(words, 'words', 'must have exactly 4 words');
    }

    final byteLength = type == InternetAddressType.IPv4 ? 4 : 16;
    final bytes = Uint8List(byteLength);
    final data = ByteData.sublistView(bytes);

    data.setUint32(0, words[0]);
    if (type == InternetAddressType.IPv6) {
      data.setUint32(4, words[1]);
      data.setUint32(8, words[2]);
      data.setUint32(12, words[3]);
    }

    return InternetAddress.fromRawAddress(bytes, type: type);
  }
}
