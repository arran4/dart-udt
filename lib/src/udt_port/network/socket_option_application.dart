import 'platform_compatibility.dart';

/// Target abstraction for applying socket options without binding to concrete
/// `dart:io` socket types in deterministic tests.
abstract interface class UdtSocketOptionTarget {
  Future<void> setReceiveBufferBytes(int bytes);
  Future<void> setSendBufferBytes(int bytes);
  Future<void> setReuseAddress(bool enabled);
  Future<void> setReusePort(bool enabled);
  Future<void> setIpv6Only(bool enabled);
}

enum UdtSocketOptionApplyStatus { applied, skippedUnsupported, failedRequired }

final class UdtSocketOptionApplyResult {
  const UdtSocketOptionApplyResult({
    required this.key,
    required this.value,
    required this.status,
    required this.reason,
    this.error,
  });

  final UdtSocketOptionKey key;
  final Object value;
  final UdtSocketOptionApplyStatus status;
  final String reason;
  final Object? error;
}

final class UdtSocketOptionApplicationReport {
  const UdtSocketOptionApplicationReport(this.results);

  final List<UdtSocketOptionApplyResult> results;

  bool get hasRequiredFailure => results.any(
    (result) => result.status == UdtSocketOptionApplyStatus.failedRequired,
  );
}

/// Applies planned options with graceful-degradation semantics.
///
/// Optional options become `skippedUnsupported` on failure; required options
/// become `failedRequired` and are surfaced in the final report.
final class UdtSocketOptionApplier {
  const UdtSocketOptionApplier();

  Future<UdtSocketOptionApplicationReport> apply(
    UdtSocketOptionTarget target,
    List<UdtSocketOptionRecommendation> recommendations,
  ) async {
    final results = <UdtSocketOptionApplyResult>[];

    for (final option in recommendations) {
      try {
        await _applyOne(target, option);
        results.add(
          UdtSocketOptionApplyResult(
            key: option.key,
            value: option.value,
            status: UdtSocketOptionApplyStatus.applied,
            reason: option.reason,
          ),
        );
      } catch (error) {
        results.add(
          UdtSocketOptionApplyResult(
            key: option.key,
            value: option.value,
            status: option.required
                ? UdtSocketOptionApplyStatus.failedRequired
                : UdtSocketOptionApplyStatus.skippedUnsupported,
            reason: option.reason,
            error: error,
          ),
        );
      }
    }

    return UdtSocketOptionApplicationReport(results);
  }

  Future<void> _applyOne(
    UdtSocketOptionTarget target,
    UdtSocketOptionRecommendation option,
  ) {
    return switch (option.key) {
      UdtSocketOptionKey.receiveBufferBytes => target.setReceiveBufferBytes(
        option.value as int,
      ),
      UdtSocketOptionKey.sendBufferBytes => target.setSendBufferBytes(
        option.value as int,
      ),
      UdtSocketOptionKey.reuseAddress => target.setReuseAddress(
        option.value as bool,
      ),
      UdtSocketOptionKey.reusePort => target.setReusePort(option.value as bool),
      UdtSocketOptionKey.ipv6Only => target.setIpv6Only(option.value as bool),
    };
  }
}
