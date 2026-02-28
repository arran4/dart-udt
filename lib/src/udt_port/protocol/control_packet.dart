import 'dart:typed_data';

import 'handshake.dart';
import 'packet.dart';
import 'packet_header.dart';

/// UDT control packet type values mirrored from upstream `packet.cpp`.
enum UdtControlType {
  handshake(0),
  keepAlive(1),
  ack(2),
  nak(3),
  congestionWarning(4),
  shutdown(5),
  ack2(6),
  messageDropRequest(7),
  errorSignal(8),
  userDefined(0x7FFF);

  const UdtControlType(this.code);

  final int code;

  static UdtControlType fromCode(int code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    throw ArgumentError.value(code, 'code', 'Unsupported control type');
  }
}

/// Typed ACK payload for deterministic ACK packet encoding.
final class UdtAckControlInfo {
  const UdtAckControlInfo({
    required this.receivedSequenceNumber,
    this.optionalMetrics = const <int>[],
  });

  final int receivedSequenceNumber;

  /// Optional trailing ACK metrics words in upstream wire-order.
  final List<int> optionalMetrics;

  Uint8List toBytes() {
    _checkInt32(receivedSequenceNumber, 'receivedSequenceNumber');
    final bytes = Uint8List((1 + optionalMetrics.length) * 4);
    final data = ByteData.sublistView(bytes);
    data.setInt32(0, receivedSequenceNumber, Endian.big);
    for (var i = 0; i < optionalMetrics.length; i++) {
      _checkInt32(optionalMetrics[i], 'optionalMetrics[$i]');
      data.setInt32((i + 1) * 4, optionalMetrics[i], Endian.big);
    }
    return bytes;
  }

  factory UdtAckControlInfo.parse(Uint8List bytes) {
    if (bytes.lengthInBytes < 4 || bytes.lengthInBytes % 4 != 0) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes.lengthInBytes',
        'ACK control payload must be 4-byte aligned and include at least 1 word',
      );
    }

    final data = ByteData.sublistView(bytes);
    final receivedSequenceNumber = data.getInt32(0, Endian.big);
    final optionalMetrics = <int>[];
    for (var offset = 4; offset < bytes.lengthInBytes; offset += 4) {
      optionalMetrics.add(data.getInt32(offset, Endian.big));
    }

    return UdtAckControlInfo(
      receivedSequenceNumber: receivedSequenceNumber,
      optionalMetrics: optionalMetrics,
    );
  }
}

/// Typed Message Drop Request payload (first and last sequence numbers).
final class UdtMessageDropRequestControlInfo {
  const UdtMessageDropRequestControlInfo({
    required this.firstSequenceNumber,
    required this.lastSequenceNumber,
  });

  static const int byteLength = 8;

  final int firstSequenceNumber;
  final int lastSequenceNumber;

  Uint8List toBytes() {
    _checkInt32(firstSequenceNumber, 'firstSequenceNumber');
    _checkInt32(lastSequenceNumber, 'lastSequenceNumber');

    final bytes = Uint8List(byteLength);
    final data = ByteData.sublistView(bytes);
    data.setInt32(0, firstSequenceNumber, Endian.big);
    data.setInt32(4, lastSequenceNumber, Endian.big);
    return bytes;
  }

  factory UdtMessageDropRequestControlInfo.parse(Uint8List bytes) {
    if (bytes.lengthInBytes != byteLength) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes.lengthInBytes',
        'Message Drop Request payload must be exactly $byteLength bytes',
      );
    }

    final data = ByteData.sublistView(bytes);
    return UdtMessageDropRequestControlInfo(
      firstSequenceNumber: data.getInt32(0, Endian.big),
      lastSequenceNumber: data.getInt32(4, Endian.big),
    );
  }
}

/// Typed wrapper for UDT control packet header + control information field.
final class UdtControlPacket {
  UdtControlPacket._({required this.header, Uint8List? controlInformation})
    : controlInformation = controlInformation ?? Uint8List(0);

  factory UdtControlPacket.handshake({
    required UdtHandshake handshake,
    required int timestamp,
    required int destinationSocketId,
  }) {
    return UdtControlPacket._(
      header: UdtPacketHeader.control(
        controlType: UdtControlType.handshake.code,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      ),
      controlInformation: handshake.toBytes(),
    );
  }

  factory UdtControlPacket.keepAlive({
    required int timestamp,
    required int destinationSocketId,
  }) {
    return UdtControlPacket._(
      header: UdtPacketHeader.control(
        controlType: UdtControlType.keepAlive.code,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      ),
    );
  }

  factory UdtControlPacket.ack({
    required int ackSequenceNumber,
    required UdtAckControlInfo info,
    required int timestamp,
    required int destinationSocketId,
  }) {
    _checkInt32(ackSequenceNumber, 'ackSequenceNumber');
    return UdtControlPacket._(
      header: UdtPacketHeader.control(
        controlType: UdtControlType.ack.code,
        additionalInfo: ackSequenceNumber,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      ),
      controlInformation: info.toBytes(),
    );
  }

  factory UdtControlPacket.nak({
    required List<int> lossList,
    required int timestamp,
    required int destinationSocketId,
  }) {
    final payload = Uint8List(lossList.length * 4);
    final data = ByteData.sublistView(payload);
    for (var i = 0; i < lossList.length; i++) {
      _checkInt32(lossList[i], 'lossList[$i]');
      data.setInt32(i * 4, lossList[i], Endian.big);
    }

    return UdtControlPacket._(
      header: UdtPacketHeader.control(
        controlType: UdtControlType.nak.code,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      ),
      controlInformation: payload,
    );
  }

  factory UdtControlPacket.ack2({
    required int ackSequenceNumber,
    required int timestamp,
    required int destinationSocketId,
  }) {
    _checkInt32(ackSequenceNumber, 'ackSequenceNumber');
    return UdtControlPacket._(
      header: UdtPacketHeader.control(
        controlType: UdtControlType.ack2.code,
        additionalInfo: ackSequenceNumber,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      ),
    );
  }

  factory UdtControlPacket.messageDropRequest({
    required int messageId,
    required UdtMessageDropRequestControlInfo info,
    required int timestamp,
    required int destinationSocketId,
  }) {
    _checkInt32(messageId, 'messageId');
    return UdtControlPacket._(
      header: UdtPacketHeader.control(
        controlType: UdtControlType.messageDropRequest.code,
        additionalInfo: messageId,
        timestamp: timestamp,
        destinationSocketId: destinationSocketId,
      ),
      controlInformation: info.toBytes(),
    );
  }

  factory UdtControlPacket.parse(UdtPacket packet) {
    if (!packet.header.isControl) {
      throw ArgumentError('Expected control packet header');
    }
    return UdtControlPacket._(
      header: packet.header,
      controlInformation: Uint8List.fromList(packet.payload),
    );
  }

  final UdtPacketHeader header;
  final Uint8List controlInformation;

  UdtControlType get type => UdtControlType.fromCode(header.controlType!);

  UdtPacket toPacket() => UdtPacket(
    header: header,
    payload: Uint8List.fromList(controlInformation),
  );

  UdtHandshake parseHandshake() {
    _ensureType(UdtControlType.handshake);
    return UdtHandshake.parse(controlInformation);
  }

  UdtAckControlInfo parseAckControlInfo() {
    _ensureType(UdtControlType.ack);
    return UdtAckControlInfo.parse(controlInformation);
  }

  List<int> parseNakLossList() {
    _ensureType(UdtControlType.nak);
    if (controlInformation.lengthInBytes % 4 != 0) {
      throw ArgumentError.value(
        controlInformation.lengthInBytes,
        'controlInformation.lengthInBytes',
        'NAK payload must be 4-byte aligned',
      );
    }

    final data = ByteData.sublistView(controlInformation);
    final words = <int>[];
    for (var offset = 0; offset < controlInformation.lengthInBytes; offset += 4) {
      words.add(data.getInt32(offset, Endian.big));
    }
    return words;
  }

  UdtMessageDropRequestControlInfo parseMessageDropRequest() {
    _ensureType(UdtControlType.messageDropRequest);
    return UdtMessageDropRequestControlInfo.parse(controlInformation);
  }

  void _ensureType(UdtControlType expected) {
    if (type != expected) {
      throw StateError('Expected $expected control packet, got $type');
    }
  }
}

void _checkInt32(int value, String name) {
  if (value < -0x80000000 || value > 0x7FFFFFFF) {
    throw ArgumentError.value(value, name, 'Must be in int32 range');
  }
}
