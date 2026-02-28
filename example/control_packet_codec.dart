import 'package:dart_udt/dart_udt.dart';

void main() {
  final handshake = UdtHandshake(
    version: 5,
    socketType: 1,
    initialSequenceNumber: 1000,
    maximumSegmentSize: 1500,
    flightFlagSize: 25600,
    requestType: 1,
    socketId: 42,
    cookie: 0x10203040,
    peerIp: const [0x7F000001, 0, 0, 0],
  );

  final outboundControl = UdtControlPacket.handshake(
    handshake: handshake,
    timestamp: 10,
    destinationSocketId: 900,
  );

  final encodedBytes = outboundControl.toPacket().toBytes();
  final decoded = UdtControlPacket.parse(UdtPacket.parse(encodedBytes));

  print('Control type: ${decoded.type}');
  print('Decoded socket id: ${decoded.parseHandshake().socketId}');
}
