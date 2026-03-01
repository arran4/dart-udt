import 'dart:typed_data';

/// Pure Dart representation of the `CHandShake` structure from upstream
/// `packet.h`, encoded as 12 x 32-bit network-order words.
final class UdtHandshake {
  const UdtHandshake({
    required this.version,
    required this.socketType,
    required this.initialSequenceNumber,
    required this.maximumSegmentSize,
    required this.flightFlagSize,
    required this.requestType,
    required this.socketId,
    required this.cookie,
    required this.peerIp,
  });

  static const int _peerIpWords = 4;
  static const int _scalarWords = 8;
  static const int wordSize = 4;
  static const int contentSize = (_scalarWords + _peerIpWords) * wordSize;

  final int version;
  final int socketType;
  final int initialSequenceNumber;
  final int maximumSegmentSize;
  final int flightFlagSize;
  final int requestType;
  final int socketId;
  final int cookie;
  final List<int> peerIp;

  Uint8List toBytes() {
    _checkInt32(version, 'version');
    _checkInt32(socketType, 'socketType');
    _checkInt32(initialSequenceNumber, 'initialSequenceNumber');
    _checkInt32(maximumSegmentSize, 'maximumSegmentSize');
    _checkInt32(flightFlagSize, 'flightFlagSize');
    _checkInt32(requestType, 'requestType');
    _checkInt32(socketId, 'socketId');
    _checkInt32(cookie, 'cookie');

    if (peerIp.length != _peerIpWords) {
      throw ArgumentError.value(peerIp.length, 'peerIp.length', 'Must be 4');
    }

    final bytes = Uint8List(contentSize);
    final data = ByteData.sublistView(bytes);

    data.setInt32(0, version, Endian.big);
    data.setInt32(4, socketType, Endian.big);
    data.setInt32(8, initialSequenceNumber, Endian.big);
    data.setInt32(12, maximumSegmentSize, Endian.big);
    data.setInt32(16, flightFlagSize, Endian.big);
    data.setInt32(20, requestType, Endian.big);
    data.setInt32(24, socketId, Endian.big);
    data.setInt32(28, cookie, Endian.big);

    for (var i = 0; i < _peerIpWords; i++) {
      _checkUint32(peerIp[i], 'peerIp[$i]');
      data.setUint32(32 + (i * wordSize), peerIp[i], Endian.big);
    }

    return bytes;
  }

  factory UdtHandshake.parse(Uint8List bytes) {
    if (bytes.lengthInBytes != contentSize) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes.lengthInBytes',
        'Expected exactly $contentSize bytes',
      );
    }

    final data = ByteData.sublistView(bytes);
    return UdtHandshake(
      version: data.getInt32(0, Endian.big),
      socketType: data.getInt32(4, Endian.big),
      initialSequenceNumber: data.getInt32(8, Endian.big),
      maximumSegmentSize: data.getInt32(12, Endian.big),
      flightFlagSize: data.getInt32(16, Endian.big),
      requestType: data.getInt32(20, Endian.big),
      socketId: data.getInt32(24, Endian.big),
      cookie: data.getInt32(28, Endian.big),
      peerIp: List<int>.generate(
        _peerIpWords,
        (i) => data.getUint32(32 + (i * wordSize), Endian.big),
        growable: false,
      ),
    );
  }
}

void _checkInt32(int value, String name) {
  if (value < -0x80000000 || value > 0x7FFFFFFF) {
    throw ArgumentError.value(value, name, 'Must be in int32 range');
  }
}

void _checkUint32(int value, String name) {
  if (value < 0 || value > 0xFFFFFFFF) {
    throw ArgumentError.value(value, name, 'Must be in uint32 range');
  }
}
