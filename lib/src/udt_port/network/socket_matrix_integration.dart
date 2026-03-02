import 'dart:io';

import 'compatibility_profile.dart';
import 'mobile_constraints.dart';
import 'platform_compatibility.dart';
import 'socket_connectivity.dart';
import 'socket_lifecycle.dart';
import 'socket_option_application.dart';
import 'socket_runtime_execution.dart';
import 'socket_runtime_plan.dart';

/// Result of executing one deterministic dual-stack matrix row through the
/// socket runtime planner + executor pipeline.
final class UdtSocketMatrixIntegrationResult {
  const UdtSocketMatrixIntegrationResult({
    required this.row,
    required this.runtimePlan,
    required this.executionReport,
    required this.connectPlans,
    required this.connectReport,
  });

  final UdtDualStackMatrixRow row;
  final UdtSocketRuntimePlan runtimePlan;
  final UdtSocketRuntimeExecutionReport executionReport;
  final List<UdtConnectPlan> connectPlans;
  final UdtSocketConnectReport connectReport;

  Set<InternetAddressType> get plannedBindFamilies => {
    for (final plan in runtimePlan.bindPlans)
      switch (plan.family) {
        UdtBindFamily.ipv4 => InternetAddressType.IPv4,
        UdtBindFamily.ipv6 => InternetAddressType.IPv6,
      },
  };

  Set<InternetAddressType> get plannedConnectFamilies => {
    for (final plan in connectPlans) plan.addressType,
  };

  Set<InternetAddressType> get attemptedFamilies => {
    for (final attempt in executionReport.attempts)
      switch (attempt.plan.family) {
        UdtBindFamily.ipv4 => InternetAddressType.IPv4,
        UdtBindFamily.ipv6 => InternetAddressType.IPv6,
      },
  };

  InternetAddressType? get selectedFamily {
    final selected = executionReport.selectedPlan;
    if (selected == null) {
      return null;
    }
    return switch (selected.family) {
      UdtBindFamily.ipv4 => InternetAddressType.IPv4,
      UdtBindFamily.ipv6 => InternetAddressType.IPv6,
    };
  }
}

/// Deterministic harness that wires dual-stack matrix rows into socket-layer
/// runtime planning/execution without requiring live sockets.
final class UdtSocketMatrixIntegrationHarness {
  const UdtSocketMatrixIntegrationHarness({
    UdtCompatibilityProfileBuilder profileBuilder =
        const UdtCompatibilityProfileBuilder(),
    UdtSocketRuntimePlanner runtimePlanner = const UdtSocketRuntimePlanner(),
    UdtSocketRuntimeExecutor runtimeExecutor = const UdtSocketRuntimeExecutor(),
    UdtSocketConnectPlanner connectPlanner = const UdtSocketConnectPlanner(),
    UdtSocketConnectExecutor connectExecutor = const UdtSocketConnectExecutor(),
  }) : _profileBuilder = profileBuilder,
       _runtimePlanner = runtimePlanner,
       _runtimeExecutor = runtimeExecutor,
       _connectPlanner = connectPlanner,
       _connectExecutor = connectExecutor;

  final UdtCompatibilityProfileBuilder _profileBuilder;
  final UdtSocketRuntimePlanner _runtimePlanner;
  final UdtSocketRuntimeExecutor _runtimeExecutor;
  final UdtSocketConnectPlanner _connectPlanner;
  final UdtSocketConnectExecutor _connectExecutor;

  Future<UdtSocketMatrixIntegrationResult> executeRow({
    required UdtDualStackMatrixRow row,
    required UdtSocketOptionTarget optionTarget,
    required UdtSocketRuntimeTarget runtimeTarget,
    required UdtSocketConnectTarget connectTarget,
    UdtMobilePolicyInput mobileInput = const UdtMobilePolicyInput(
      appState: UdtMobileAppState.foreground,
      networkType: UdtMobileNetworkType.wifi,
      allowBackgroundNetwork: true,
      batterySaverEnabled: false,
    ),
  }) async {
    final profile = _profileBuilder.build(
      platform: row.platform,
      ipMode: row.mode,
      ipv6: row.mode != UdtIpMode.ipv4Only,
      mobileInput: mobileInput,
    );

    final runtimePlan = await _runtimePlanner.buildPlan(
      profile: profile,
      optionTarget: optionTarget,
    );

    final executionReport = await _runtimeExecutor.executeBindPlan(
      target: runtimeTarget,
      runtimePlan: runtimePlan,
    );

    final connectPlans = executionReport.selectedPlan == null
        ? const <UdtConnectPlan>[]
        : _connectPlanner.planFromBind(executionReport.selectedPlan!);

    final connectReport = connectPlans.isEmpty
        ? const UdtSocketConnectReport(attempts: [], selectedPlan: null)
        : await _connectExecutor.execute(
            target: connectTarget,
            plans: connectPlans,
          );

    return UdtSocketMatrixIntegrationResult(
      row: row,
      runtimePlan: runtimePlan,
      executionReport: executionReport,
      connectPlans: connectPlans,
      connectReport: connectReport,
    );
  }
}
