import 'dart:typed_data';

import 'packet_header.dart';

/// Typed Dart packet container replacing upstream pointer/alias C++ layout.
final class UdtPacket {
  UdtPacket({required this.header, Uint8List? payload})
      : payload = payload ?? Uint8List(0);

  final UdtPacketHeader header;
  final Uint8List payload;

  int get payloadLength => payload.lengthInBytes;

  Uint8List toBytes() {
    final bytes = Uint8List(UdtPacketHeader.byteLength + payloadLength);
    bytes.setRange(0, UdtPacketHeader.byteLength, header.toBytes());
    bytes.setRange(UdtPacketHeader.byteLength, bytes.lengthInBytes, payload);
    return bytes;
  }

  factory UdtPacket.parse(Uint8List bytes) {
    if (bytes.lengthInBytes < UdtPacketHeader.byteLength) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes.lengthInBytes',
        'Must be at least ${UdtPacketHeader.byteLength} bytes',
      );
    }

    final headerBytes = Uint8List.sublistView(
      bytes,
      0,
      UdtPacketHeader.byteLength,
    );
    final payload = Uint8List.sublistView(bytes, UdtPacketHeader.byteLength);
    return UdtPacket(
      header: UdtPacketHeader.parse(headerBytes),
      payload: payload,
    );
  }
}
