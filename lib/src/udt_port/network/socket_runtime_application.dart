import 'dart:io';

import 'compatibility_profile.dart';
import 'socket_connectivity.dart';
import 'socket_lifecycle.dart';
import 'socket_option_application.dart';
import 'socket_runtime_execution.dart';
import 'socket_runtime_plan.dart';

final class UdtSocketRuntimeApplicationReport {
  const UdtSocketRuntimeApplicationReport({
    required this.runtimePlan,
    required this.execution,
    required this.connect,
    required this.logs,
  });

  final UdtSocketRuntimePlan runtimePlan;
  final UdtSocketRuntimeExecutionReport execution;
  final UdtSocketConnectReport? connect;
  final List<String> logs;
}

/// Applies runtime bind/connect plans with explicit fallback logging.
///
/// This bridges deterministic runtime planning with live socket-layer targets
/// while preserving auditable no-network behavior in tests.
final class UdtSocketRuntimeApplier {
  const UdtSocketRuntimeApplier({
    UdtSocketRuntimePlanner runtimePlanner = const UdtSocketRuntimePlanner(),
    UdtSocketRuntimeExecutor runtimeExecutor = const UdtSocketRuntimeExecutor(),
    UdtSocketConnectPlanner connectPlanner = const UdtSocketConnectPlanner(),
    UdtSocketConnectExecutor connectExecutor = const UdtSocketConnectExecutor(),
  }) : _runtimePlanner = runtimePlanner,
       _runtimeExecutor = runtimeExecutor,
       _connectPlanner = connectPlanner,
       _connectExecutor = connectExecutor;

  final UdtSocketRuntimePlanner _runtimePlanner;
  final UdtSocketRuntimeExecutor _runtimeExecutor;
  final UdtSocketConnectPlanner _connectPlanner;
  final UdtSocketConnectExecutor _connectExecutor;

  /// Builds runtime plan and applies bind/connect in one flow.
  Future<UdtSocketRuntimeApplicationReport> applyProfile({
    required UdtCompatibilityProfile profile,
    required UdtSocketRuntimeTarget runtimeTarget,
    required UdtSocketOptionTarget optionTarget,
    UdtSocketConnectTarget? connectTarget,
    void Function(String message)? onLog,
  }) async {
    final runtimePlan = await _runtimePlanner.buildPlan(
      profile: profile,
      optionTarget: optionTarget,
    );

    return apply(
      runtimePlan: runtimePlan,
      runtimeTarget: runtimeTarget,
      connectTarget: connectTarget,
      onLog: onLog,
    );
  }

  Future<UdtSocketRuntimeApplicationReport> apply({
    required UdtSocketRuntimePlan runtimePlan,
    required UdtSocketRuntimeTarget runtimeTarget,
    UdtSocketConnectTarget? connectTarget,
    void Function(String message)? onLog,
  }) async {
    final logs = <String>[];

    void log(String message) {
      logs.add(message);
      onLog?.call(message);
    }

    final execution = await _runtimeExecutor.executeBindPlan(
      target: runtimeTarget,
      runtimePlan: runtimePlan,
    );

    for (final attempt in execution.attempts) {
      if (!attempt.success) {
        log(
          'bind fallback: family=${attempt.plan.family.name} '
          'dualStack=${attempt.plan.dualStack} error=${attempt.error}',
        );
      }
    }

    if (!execution.isBound) {
      log('bind failed: no runtime bind plan succeeded.');
      return UdtSocketRuntimeApplicationReport(
        runtimePlan: runtimePlan,
        execution: execution,
        connect: null,
        logs: logs,
      );
    }

    if (connectTarget == null || execution.selectedPlan == null) {
      log('bind succeeded: connect phase not requested.');
      return UdtSocketRuntimeApplicationReport(
        runtimePlan: runtimePlan,
        execution: execution,
        connect: null,
        logs: logs,
      );
    }

    final connectPlans = _connectPlanner.planFromBind(execution.selectedPlan!);
    final connect = await _connectExecutor.execute(
      target: connectTarget,
      plans: connectPlans,
    );

    for (final attempt in connect.attempts) {
      if (!attempt.success) {
        log(
          'connect fallback: family=${attempt.plan.family.name} '
          'error=${attempt.error}',
        );
      }
    }

    if (!connect.isConnected) {
      log('connect failed: no connect plan succeeded.');
    }

    return UdtSocketRuntimeApplicationReport(
      runtimePlan: runtimePlan,
      execution: execution,
      connect: connect,
      logs: logs,
    );
  }
}

/// Live runtime target backed by `RawDatagramSocket.bind` + `connect`.
///
/// This target also implements [UdtSocketOptionTarget] so runtime plans can be
/// built and then applied through one shared socket adapter boundary.
final class UdtRawDatagramRuntimeTarget
    implements
        UdtSocketRuntimeTarget,
        UdtSocketConnectTarget,
        UdtSocketOptionTarget {
  UdtRawDatagramRuntimeTarget({
    this.localPort = 0,
    this.ipv4BindAddress = InternetAddress.anyIPv4,
    this.ipv6BindAddress = InternetAddress.anyIPv6,
    this.ipv4RemoteAddress,
    this.ipv6RemoteAddress,
    this.remotePort = 0,
    this.supportsReceiveSendBufferSizing = false,
    this.supportsIpv6OnlyOption = true,
  });

  final int localPort;
  final InternetAddress ipv4BindAddress;
  final InternetAddress ipv6BindAddress;

  final InternetAddress? ipv4RemoteAddress;
  final InternetAddress? ipv6RemoteAddress;
  final int remotePort;

  final bool supportsReceiveSendBufferSizing;
  final bool supportsIpv6OnlyOption;

  bool _reuseAddress = true;
  bool _reusePort = false;
  bool? _ipv6Only;

  RawDatagramSocket? _socket;

  RawDatagramSocket? get socket => _socket;

  @override
  Future<void> setReceiveBufferBytes(int bytes) async {
    if (!supportsReceiveSendBufferSizing) {
      throw UnsupportedError(
        'RawDatagramSocket receive buffer size is not configurable via dart:io.',
      );
    }
  }

  @override
  Future<void> setSendBufferBytes(int bytes) async {
    if (!supportsReceiveSendBufferSizing) {
      throw UnsupportedError(
        'RawDatagramSocket send buffer size is not configurable via dart:io.',
      );
    }
  }

  @override
  Future<void> setReuseAddress(bool enabled) async {
    _reuseAddress = enabled;
  }

  @override
  Future<void> setReusePort(bool enabled) async {
    _reusePort = enabled;
  }

  @override
  Future<void> setIpv6Only(bool enabled) async {
    if (!supportsIpv6OnlyOption) {
      throw UnsupportedError(
        'RawDatagramSocket IPv6-only option is unavailable on this target.',
      );
    }

    _ipv6Only = enabled;
  }

  @override
  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {
    final address = family == UdtBindFamily.ipv4
        ? ipv4BindAddress
        : ipv6BindAddress;
    final ipv6Only = family == UdtBindFamily.ipv6
        ? (_ipv6Only ?? !dualStack)
        : false;

    _socket = await RawDatagramSocket.bind(
      address,
      localPort,
      reuseAddress: _reuseAddress,
      reusePort: _reusePort,
      v6Only: ipv6Only,
    );
  }

  @override
  Future<void> connect(UdtEndpointFamily family) async {
    final activeSocket = _socket;
    if (activeSocket == null) {
      throw StateError('connect requires a bound socket');
    }

    final remoteAddress = switch (family) {
      UdtEndpointFamily.ipv4 => ipv4RemoteAddress,
      UdtEndpointFamily.ipv6 => ipv6RemoteAddress,
    };

    if (remoteAddress == null || remotePort <= 0) {
      throw StateError(
        'missing remote endpoint for ${family.name}: '
        'address=$remoteAddress port=$remotePort',
      );
    }

    activeSocket.connect(remoteAddress, remotePort);
  }

  @override
  Future<void> close() async {
    _socket?.close();
    _socket = null;
  }
}
