import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

final class _FakeOptionTarget implements UdtSocketOptionTarget {
  final Map<UdtSocketOptionKey, Object> applied =
      <UdtSocketOptionKey, Object>{};
  final Set<UdtSocketOptionKey> failKeys;

  _FakeOptionTarget({this.failKeys = const <UdtSocketOptionKey>{}});

  Future<void> _record(UdtSocketOptionKey key, Object value) async {
    if (failKeys.contains(key)) {
      throw UnsupportedError('unsupported $key');
    }
    applied[key] = value;
  }

  @override
  Future<void> setIpv6Only(bool enabled) =>
      _record(UdtSocketOptionKey.ipv6Only, enabled);

  @override
  Future<void> setReceiveBufferBytes(int bytes) =>
      _record(UdtSocketOptionKey.receiveBufferBytes, bytes);

  @override
  Future<void> setReuseAddress(bool enabled) =>
      _record(UdtSocketOptionKey.reuseAddress, enabled);

  @override
  Future<void> setReusePort(bool enabled) =>
      _record(UdtSocketOptionKey.reusePort, enabled);

  @override
  Future<void> setSendBufferBytes(int bytes) =>
      _record(UdtSocketOptionKey.sendBufferBytes, bytes);
}

void main() {
  test('applier marks all successful option applications as applied', () async {
    const planner = UdtSocketOptionPlanner(platformOverride: 'linux');
    final options = planner.plan(mode: UdtIpMode.ipv4Only);
    final target = _FakeOptionTarget();

    const applier = UdtSocketOptionApplier();
    final report = await applier.apply(target, options);

    expect(report.hasRequiredFailure, isFalse);
    expect(
      report.results.every(
        (result) => result.status == UdtSocketOptionApplyStatus.applied,
      ),
      isTrue,
    );
    expect(target.applied[UdtSocketOptionKey.reuseAddress], isTrue);
  });

  test('optional failures become skippedUnsupported', () async {
    const planner = UdtSocketOptionPlanner(platformOverride: 'linux');
    final options = planner.plan(mode: UdtIpMode.dualStack);
    final target = _FakeOptionTarget(failKeys: {UdtSocketOptionKey.reusePort});

    const applier = UdtSocketOptionApplier();
    final report = await applier.apply(target, options);

    final reusePort = report.results.singleWhere(
      (result) => result.key == UdtSocketOptionKey.reusePort,
    );
    expect(reusePort.status, UdtSocketOptionApplyStatus.skippedUnsupported);
    expect(report.hasRequiredFailure, isFalse);
  });

  test('required failures become failedRequired', () async {
    const planner = UdtSocketOptionPlanner(platformOverride: 'linux');
    final options = planner.plan(mode: UdtIpMode.ipv6Only);
    final target = _FakeOptionTarget(failKeys: {UdtSocketOptionKey.ipv6Only});

    const applier = UdtSocketOptionApplier();
    final report = await applier.apply(target, options);

    final ipv6Only = report.results.singleWhere(
      (result) => result.key == UdtSocketOptionKey.ipv6Only,
    );
    expect(ipv6Only.status, UdtSocketOptionApplyStatus.failedRequired);
    expect(ipv6Only.error, isNotNull);
    expect(report.hasRequiredFailure, isTrue);
  });
}
