/// Mobile app lifecycle/network transition state for deterministic planning.
enum UdtMobileAppState { foreground, background }

enum UdtMobileNetworkType { wifi, cellular, unknown }

final class UdtMobilePolicyInput {
  const UdtMobilePolicyInput({
    required this.appState,
    required this.networkType,
    required this.allowBackgroundNetwork,
    required this.batterySaverEnabled,
  });

  final UdtMobileAppState appState;
  final UdtMobileNetworkType networkType;
  final bool allowBackgroundNetwork;
  final bool batterySaverEnabled;
}

final class UdtMobilePolicyDecision {
  const UdtMobilePolicyDecision({
    required this.shouldPauseSending,
    required this.shouldKeepReceiving,
    required this.ackIntervalMultiplier,
    required this.reason,
  });

  final bool shouldPauseSending;
  final bool shouldKeepReceiving;

  /// Multiplier for ACK cadence tuning during constrained states.
  final double ackIntervalMultiplier;
  final String reason;
}

/// Deterministic mobile constraints policy model for section-4 planning.
///
/// This intentionally avoids real platform hooks so behavior is testable
/// without device or network dependencies.
final class UdtMobileConstraintsPolicy {
  const UdtMobileConstraintsPolicy();

  UdtMobilePolicyDecision evaluate(UdtMobilePolicyInput input) {
    if (input.appState == UdtMobileAppState.foreground) {
      if (input.batterySaverEnabled &&
          input.networkType == UdtMobileNetworkType.cellular) {
        return const UdtMobilePolicyDecision(
          shouldPauseSending: false,
          shouldKeepReceiving: true,
          ackIntervalMultiplier: 1.5,
          reason: 'Foreground + battery saver + cellular: conserve uplink.',
        );
      }

      return const UdtMobilePolicyDecision(
        shouldPauseSending: false,
        shouldKeepReceiving: true,
        ackIntervalMultiplier: 1.0,
        reason: 'Foreground operation baseline.',
      );
    }

    if (!input.allowBackgroundNetwork) {
      return const UdtMobilePolicyDecision(
        shouldPauseSending: true,
        shouldKeepReceiving: false,
        ackIntervalMultiplier: 2.0,
        reason: 'Background networking disallowed by app policy.',
      );
    }

    if (input.networkType == UdtMobileNetworkType.cellular ||
        input.batterySaverEnabled) {
      return const UdtMobilePolicyDecision(
        shouldPauseSending: true,
        shouldKeepReceiving: true,
        ackIntervalMultiplier: 2.0,
        reason: 'Background constrained mode: receive-only, reduced ACK rate.',
      );
    }

    return const UdtMobilePolicyDecision(
      shouldPauseSending: false,
      shouldKeepReceiving: true,
      ackIntervalMultiplier: 1.25,
      reason: 'Background Wi-Fi allowed with moderate ACK throttling.',
    );
  }
}
