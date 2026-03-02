import 'package:dart_udt/dart_udt.dart';

void main() async {
  final handshake = UdtHandshake(
    version: 5,
    socketType: 1,
    initialSequenceNumber: 42,
    maximumSegmentSize: 1500,
    flightFlagSize: 25600,
    requestType: 1,
    socketId: 1001,
    cookie: 0xAABBCCDD,
    peerIp: const [0x7F000001, 0, 0, 0],
  );

  final packet = UdtControlPacket.handshake(
    handshake: handshake,
    timestamp: 123,
    destinationSocketId: 9001,
  ).toPacket();

  final reparsed = UdtControlPacket.parse(UdtPacket.parse(packet.toBytes()));
  print(
    'control=${reparsed.type} socketId=${reparsed.parseHandshake().socketId}',
  );

  const profileBuilder = UdtCompatibilityProfileBuilder();
  final profile = profileBuilder.build(
    platform: 'linux',
    ipMode: UdtIpMode.dualStack,
    ipv6: true,
    mobileInput: const UdtMobilePolicyInput(
      appState: UdtMobileAppState.foreground,
      networkType: UdtMobileNetworkType.wifi,
      allowBackgroundNetwork: true,
      batterySaverEnabled: false,
    ),
  );

  const planner = UdtSocketRuntimePlanner();
  final runtimePlan = await planner.buildPlan(
    profile: profile,
    optionTarget: _NoopSocketOptionTarget(),
  );
  print(
    'runtime bind plans=${runtimePlan.bindPlans.length} '
    'blockingFailure=${runtimePlan.hasBlockingFailure}',
  );

  const simulator = UdtLatencyLossSimulator(
    random: UdtSeededRandomSource(2024),
  );
  const config = UdtImpairmentConfig(
    lossRate: 0.2,
    reorderRate: 0.35,
    maxJitterMillis: 12,
  );
  final outcomes = simulator.simulate(
    config: config,
    packets: const [
      UdtImpairmentInput(sequence: 1, baseDelayMillis: 10),
      UdtImpairmentInput(sequence: 2, baseDelayMillis: 10),
      UdtImpairmentInput(sequence: 3, baseDelayMillis: 10),
    ],
  );
  for (final outcome in outcomes) {
    print(
      'seq=${outcome.sequence} drop=${outcome.dropped} '
      'reorder=${outcome.reordered} delay=${outcome.delayMillis}',
    );
  }
}

final class _NoopSocketOptionTarget implements UdtSocketOptionTarget {
  @override
  Future<void> setIpv6Only(bool enabled) async {}

  @override
  Future<void> setReceiveBufferBytes(int bytes) async {}

  @override
  Future<void> setReuseAddress(bool enabled) async {}

  @override
  Future<void> setReusePort(bool enabled) async {}

  @override
  Future<void> setSendBufferBytes(int bytes) async {}
}
