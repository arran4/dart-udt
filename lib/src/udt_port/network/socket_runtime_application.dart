import 'dart:io';

import 'socket_connectivity.dart';
import 'socket_lifecycle.dart';
import 'socket_runtime_execution.dart';
import 'socket_runtime_plan.dart';

final class UdtSocketRuntimeApplicationReport {
  const UdtSocketRuntimeApplicationReport({
    required this.execution,
    required this.connect,
    required this.logs,
  });

  final UdtSocketRuntimeExecutionReport execution;
  final UdtSocketConnectReport? connect;
  final List<String> logs;
}

/// Applies runtime bind/connect plans with explicit fallback logging.
///
/// This bridges deterministic runtime planning with upcoming live socket-layer
/// targets while preserving auditable no-network behavior in tests.
final class UdtSocketRuntimeApplier {
  const UdtSocketRuntimeApplier({
    UdtSocketRuntimeExecutor runtimeExecutor = const UdtSocketRuntimeExecutor(),
    UdtSocketConnectPlanner connectPlanner = const UdtSocketConnectPlanner(),
    UdtSocketConnectExecutor connectExecutor = const UdtSocketConnectExecutor(),
  }) : _runtimeExecutor = runtimeExecutor,
       _connectPlanner = connectPlanner,
       _connectExecutor = connectExecutor;

  final UdtSocketRuntimeExecutor _runtimeExecutor;
  final UdtSocketConnectPlanner _connectPlanner;
  final UdtSocketConnectExecutor _connectExecutor;

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
        execution: execution,
        connect: null,
        logs: logs,
      );
    }

    if (connectTarget == null || execution.selectedPlan == null) {
      log('bind succeeded: connect phase not requested.');
      return UdtSocketRuntimeApplicationReport(
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
      execution: execution,
      connect: connect,
      logs: logs,
    );
  }
}

/// Live runtime target backed by `RawDatagramSocket.bind`.
final class UdtRawDatagramRuntimeTarget implements UdtSocketRuntimeTarget {
  UdtRawDatagramRuntimeTarget({
    this.localPort = 0,
    this.ipv4BindAddress = InternetAddress.anyIPv4,
    this.ipv6BindAddress = InternetAddress.anyIPv6,
  });

  final int localPort;
  final InternetAddress ipv4BindAddress;
  final InternetAddress ipv6BindAddress;

  RawDatagramSocket? _socket;

  RawDatagramSocket? get socket => _socket;

  @override
  Future<void> bind(UdtBindFamily family, {required bool dualStack}) async {
    final address = family == UdtBindFamily.ipv4 ? ipv4BindAddress : ipv6BindAddress;
    _socket = await RawDatagramSocket.bind(
      address,
      localPort,
      reuseAddress: true,
      reusePort: false,
    );
  }

  @override
  Future<void> close() async {
    _socket?.close();
    _socket = null;
  }
}
