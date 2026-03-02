import 'planning/module_map.dart';

/// Entrypoint for the UDT port scaffolding.
class UdtPortScaffold {
  const UdtPortScaffold();

  /// Returns a short status message for the current project state.
  String status() =>
      'UDT Dart port scaffold generated from upstream C++ sources.';

  /// Canonical upstream-to-Dart module mapping targets.
  Map<UdtModule, String> moduleTargets() => {
        for (final module in UdtModule.values) module: module.dartTarget,
      };
}
