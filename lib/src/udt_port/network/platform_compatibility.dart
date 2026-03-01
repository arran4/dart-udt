import 'dart:io';

/// Supported UDT address-family targets for deterministic compatibility planning.
enum UdtIpMode { ipv4Only, ipv6Only, dualStack }

/// Typed socket-option keys used by [UdtSocketOptionPlanner].
enum UdtSocketOptionKey {
  receiveBufferBytes,
  sendBufferBytes,
  reuseAddress,
  reusePort,
  ipv6Only,
}

/// Deterministic socket option recommendation.
final class UdtSocketOptionRecommendation {
  const UdtSocketOptionRecommendation({
    required this.key,
    required this.value,
    required this.required,
    required this.reason,
  });

  final UdtSocketOptionKey key;
  final Object value;

  /// Whether failure to apply this option should be considered fatal.
  final bool required;

  /// Human-readable rationale for migration/debug output.
  final String reason;
}

/// Cross-platform socket-option planner for upcoming networking port tasks.
///
/// This intentionally avoids real socket I/O so tests can stay deterministic.
final class UdtSocketOptionPlanner {
  const UdtSocketOptionPlanner({String? platformOverride})
    : _platformOverride = platformOverride;

  final String? _platformOverride;

  String get _platform =>
      (_platformOverride ?? Platform.operatingSystem).toLowerCase();

  List<UdtSocketOptionRecommendation> plan({
    required UdtIpMode mode,
    int receiveBufferBytes = 1 << 20,
    int sendBufferBytes = 1 << 20,
  }) {
    if (receiveBufferBytes <= 0) {
      throw ArgumentError.value(
        receiveBufferBytes,
        'receiveBufferBytes',
        'must be > 0',
      );
    }
    if (sendBufferBytes <= 0) {
      throw ArgumentError.value(
        sendBufferBytes,
        'sendBufferBytes',
        'must be > 0',
      );
    }

    final isLinux = _platform == 'linux';
    final isMac = _platform == 'macos';
    final isWindows = _platform == 'windows';

    final recommendations = <UdtSocketOptionRecommendation>[
      UdtSocketOptionRecommendation(
        key: UdtSocketOptionKey.receiveBufferBytes,
        value: receiveBufferBytes,
        required: false,
        reason: 'Improve receive throughput while allowing graceful fallback.',
      ),
      UdtSocketOptionRecommendation(
        key: UdtSocketOptionKey.sendBufferBytes,
        value: sendBufferBytes,
        required: false,
        reason: 'Improve send throughput while allowing graceful fallback.',
      ),
      UdtSocketOptionRecommendation(
        key: UdtSocketOptionKey.reuseAddress,
        value: true,
        required: false,
        reason: 'Enable faster deterministic bind/rebind loops in tests/apps.',
      ),
      UdtSocketOptionRecommendation(
        key: UdtSocketOptionKey.reusePort,
        value: isLinux || isMac,
        required: false,
        reason:
            'Available on Linux/macOS; keep optional for compatibility parity.',
      ),
    ];

    if (mode == UdtIpMode.ipv6Only || mode == UdtIpMode.dualStack) {
      recommendations.add(
        UdtSocketOptionRecommendation(
          key: UdtSocketOptionKey.ipv6Only,
          value: mode == UdtIpMode.ipv6Only,
          required: mode == UdtIpMode.ipv6Only,
          reason: mode == UdtIpMode.ipv6Only
              ? 'IPv6-only listener requested.'
              : 'Dual-stack requested (disable IPv6-only when supported).',
        ),
      );
    }

    if (isWindows && mode == UdtIpMode.dualStack) {
      recommendations.add(
        const UdtSocketOptionRecommendation(
          key: UdtSocketOptionKey.ipv6Only,
          value: false,
          required: false,
          reason:
              'Windows dual-stack may vary by version; keep this best-effort.',
        ),
      );
    }

    return recommendations;
  }
}

/// Deterministic matrix rows for section-4 dual-stack planning and CI docs.
final class UdtDualStackMatrixRow {
  const UdtDualStackMatrixRow({
    required this.platform,
    required this.mode,
    required this.expectedBindFamilies,
    required this.notes,
  });

  final String platform;
  final UdtIpMode mode;
  final Set<InternetAddressType> expectedBindFamilies;
  final String notes;
}

/// Generates deterministic dual-stack planning matrix without network access.
List<UdtDualStackMatrixRow> buildUdtDualStackMatrix() {
  const platforms = <String>['linux', 'macos', 'windows'];
  const modes = <UdtIpMode>[
    UdtIpMode.ipv4Only,
    UdtIpMode.ipv6Only,
    UdtIpMode.dualStack,
  ];

  final rows = <UdtDualStackMatrixRow>[];
  for (final platform in platforms) {
    for (final mode in modes) {
      rows.add(
        UdtDualStackMatrixRow(
          platform: platform,
          mode: mode,
          expectedBindFamilies: switch (mode) {
            UdtIpMode.ipv4Only => {InternetAddressType.IPv4},
            UdtIpMode.ipv6Only => {InternetAddressType.IPv6},
            UdtIpMode.dualStack => {
              InternetAddressType.IPv4,
              InternetAddressType.IPv6,
            },
          },
          notes: mode == UdtIpMode.dualStack && platform == 'windows'
              ? 'Validate dual-stack defaults per Windows version.'
              : 'Deterministic planning baseline.',
        ),
      );
    }
  }

  return rows;
}
