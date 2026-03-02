import 'dart:typed_data';

/// UDT packet header representation with deterministic binary encoding.
///
/// This keeps parsing/serialization pure Dart and free from FFI requirements.
final class UdtPacketHeader {
  const UdtPacketHeader._({
    required this.isControl,
    required this.timestamp,
    required this.destinationSocketId,
    this.sequenceNumber,
    this.controlType,
    this.controlReserved,
    this.additionalInfo = 0,
  });

  factory UdtPacketHeader.data({
    required int sequenceNumber,
    required int timestamp,
    required int destinationSocketId,
  }) {
    _checkUint31(sequenceNumber, 'sequenceNumber');
    _checkUint32(timestamp, 'timestamp');
    _checkUint32(destinationSocketId, 'destinationSocketId');
    return UdtPacketHeader._(
      isControl: false,
      sequenceNumber: sequenceNumber,
      timestamp: timestamp,
      destinationSocketId: destinationSocketId,
    );
  }

  factory UdtPacketHeader.control({
    required int controlType,
    int controlReserved = 0,
    int additionalInfo = 0,
    required int timestamp,
    required int destinationSocketId,
  }) {
    _checkUint15(controlType, 'controlType');
    _checkUint16(controlReserved, 'controlReserved');
    _checkUint32(additionalInfo, 'additionalInfo');
    _checkUint32(timestamp, 'timestamp');
    _checkUint32(destinationSocketId, 'destinationSocketId');
    return UdtPacketHeader._(
      isControl: true,
      controlType: controlType,
      controlReserved: controlReserved,
      additionalInfo: additionalInfo,
      timestamp: timestamp,
      destinationSocketId: destinationSocketId,
    );
  }

  factory UdtPacketHeader.parse(Uint8List bytes) {
    if (bytes.lengthInBytes != byteLength) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes.lengthInBytes',
        'Expected exactly $byteLength bytes',
      );
    }

    final data = ByteData.sublistView(bytes);
    final word0 = data.getUint32(0, Endian.big);
    final isControl = (word0 & 0x80000000) != 0;
    final word1 = data.getUint32(4, Endian.big);
    final timestamp = data.getUint32(8, Endian.big);
    final destinationSocketId = data.getUint32(12, Endian.big);

    if (!isControl) {
      return UdtPacketHeader.data(
        sequenceNumber: word0,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      );
    }

    return UdtPacketHeader.control(
      controlType: (word0 >> 16) & 0x7FFF,
      controlReserved: word0 & 0xFFFF,
      additionalInfo: word1,
      timestamp: timestamp,
      destinationSocketId: destinationSocketId,
    );
  }

  static const int byteLength = 16;

  final bool isControl;
  final int? sequenceNumber;
  final int? controlType;
  final int? controlReserved;
  final int additionalInfo;
  final int timestamp;
  final int destinationSocketId;

  Uint8List toBytes() {
    final bytes = Uint8List(byteLength);
    final data = ByteData.sublistView(bytes);

    final word0 = switch (isControl) {
      false => sequenceNumber!,
      true =>
        0x80000000 |
            ((controlType! & 0x7FFF) << 16) |
            (controlReserved! & 0xFFFF),
    };

    data.setUint32(0, word0, Endian.big);
    data.setUint32(4, isControl ? additionalInfo : 0, Endian.big);
    data.setUint32(8, timestamp, Endian.big);
    data.setUint32(12, destinationSocketId, Endian.big);

    return bytes;
  }
}

void _checkUint32(int value, String name) {
  if (value < 0 || value > 0xFFFFFFFF) {
    throw ArgumentError.value(value, name, 'Must be in uint32 range');
  }
}

void _checkUint16(int value, String name) {
  if (value < 0 || value > 0xFFFF) {
    throw ArgumentError.value(value, name, 'Must be in uint16 range');
  }
}

void _checkUint15(int value, String name) {
  if (value < 0 || value > 0x7FFF) {
    throw ArgumentError.value(value, name, 'Must be in uint15 range');
  }
}

void _checkUint31(int value, String name) {
  if (value < 0 || value > 0x7FFFFFFF) {
    throw ArgumentError.value(value, name, 'Must be in uint31 range');
  }
}
