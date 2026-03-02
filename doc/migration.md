# Migrating from upstream C++ UDT APIs

This port keeps upstream source references in `lib/src/upstream_udt_comment/` and
moves implementation to pure Dart typed wrappers.

## Module mapping

Use `UdtModule` + `dartTarget` for the canonical source-to-port map.

- Upstream `packet.h` / `packet.cpp` -> `lib/src/udt_port/protocol/`
- Upstream `epoll.h` / `epoll.cpp` -> `lib/src/udt_port/epoll/`
- Upstream lock/cond/worker-loop usage in `queue.h` / `queue.cpp` ->
  `lib/src/udt_port/core/threading.dart`
- Upstream receive-user list and socket hash helpers in `queue.h` / `queue.cpp` (`CRcvUList`, `CHash`) ->
  `lib/src/udt_port/queue/queue_structures.dart`
- Upstream `ccc.h` / `ccc.cpp` base `CCC` wrapper ->
  `lib/src/udt_port/ccc/congestion_control.dart`
- Upstream `md5.h` / `md5.cpp` hashing utility ->
  `lib/src/udt_port/common/md5.dart`
- Upstream sequence/message/ACK arithmetic in `common.h` (`CSeqNo`, `CMsgNo`,
  `CAckNo`) -> `lib/src/udt_port/common/sequence_numbers.dart`
- Upstream IP helpers in `common.h` (`CIPAddress`) ->
  `lib/src/udt_port/common/ip_address.dart`
- Upstream timer/event helpers in `common.h` / `common.cpp` (`CTimer`) ->
  `lib/src/udt_port/common/timer.dart`
- Upstream sender/receiver loss lists in `list.h` / `list.cpp` ->
  `lib/src/udt_port/list/loss_list.dart`
- Upstream ACK/timing windows in `window.h` / `window.cpp` ->
  `lib/src/udt_port/window/window.dart`
- Upstream cache entries/helpers in `cache.h` / `cache.cpp` ->
  `lib/src/udt_port/cache/cache.dart`
- Upstream sender buffer in `buffer.h` / `buffer.cpp` (`CSndBuffer`) ->
  `lib/src/udt_port/buffer/send_buffer.dart`
- Upstream receiver buffer in `buffer.h` / `buffer.cpp` (`CRcvBuffer`) ->
  `lib/src/udt_port/buffer/receive_buffer.dart`
- Upstream networking/platform compatibility branches in `api.cpp`/socket setup paths ->
  `lib/src/udt_port/network/platform_compatibility.dart`
- Upstream socket-option apply/degrade behavior in socket setup paths ->
  `lib/src/udt_port/network/socket_option_application.dart`
- Upstream mobile/backgrounding and path-MTU compatibility concerns in socket/runtime paths ->
  `lib/src/udt_port/network/mobile_constraints.dart`, `lib/src/udt_port/network/mtu_planning.dart`,
  `lib/src/udt_port/network/transition_simulation.dart`,
  `lib/src/udt_port/network/latency_loss_simulation.dart`,
  `lib/src/udt_port/network/compatibility_profile.dart`,
  `lib/src/udt_port/network/socket_runtime_plan.dart`,
  `lib/src/udt_port/network/socket_lifecycle.dart`,
  `lib/src/udt_port/network/socket_runtime_execution.dart`,
  `lib/src/udt_port/network/socket_runtime_application.dart`,
  `lib/src/udt_port/network/socket_connectivity.dart`,
  `lib/src/udt_port/network/socket_matrix_integration.dart`,
  `lib/src/udt_port/network/connectivity_recovery.dart`,
  `lib/src/udt_port/network/circuit_breaker.dart`

- Live bind/connect adapter boundary now uses `UdtRawDatagramRuntimeTarget`
  (implements runtime-target + connect-target + socket-option-target interfaces)
  so `UdtSocketRuntimeApplier.applyProfile` can execute option planning and
  bind/connect fallback flow through one typed runtime adapter.
- Runtime socket-option bridge verification now includes deterministic runtime-target
  tests for required vs optional apply results using
  `test/socket_runtime_live_option_bridge_test.dart`.

## API shape changes

- Pointer/alias packet ownership (`CPacket`) is replaced by immutable typed
  wrappers: `UdtPacketHeader`, `UdtPacket`, `UdtControlPacket`, and typed payload
  value objects.
- Binary payload layouts are encoded via explicit `ByteData` offsets to keep
  packet formats deterministic and auditable.
- Pthread primitives (`pthread_mutex_t`, `pthread_cond_t`, worker threads) are
  mapped to pure-Dart async primitives: `UdtAsyncMutex`, `UdtAsyncSignal`, and
  `UdtSerialExecutor`.
- Queue list/hash pointer structures (`CRNode`, `CHash::CBucket`) are mapped
  to typed wrappers (`UdtReceiveNode`/`UdtReceiveUserList`, `UdtSocketHash`)
  with explicit ordering/collision behavior for deterministic tests.
- Base congestion-control callback/configuration surface from `CCC` is mapped to
  `UdtCongestionControl` with injectable side effects (for example custom
  control-message send) to keep no-socket deterministic tests feasible.
- Upstream default congestion control `CUDTCC` is mapped to
  `UdtDefaultCongestionControl` (pure Dart), with injectable clock and seeded
  random providers so ACK/loss/timeout state transitions and deterministic trace fixtures can be tested without
  socket I/O.

## Current limitations

- Socket-level parity and mixed local/system descriptor polling are still tracked
  in `TODO_PORT.md`.


## Deterministic simulation examples

- `example/network_simulation_trace.dart` demonstrates seeded delay/reorder/drop trace generation for reproducible no-socket parity checks.
- Network impairment parity fixture corpus/version notes:
  `doc/upstream_trace_fixture_corpus.md`.
