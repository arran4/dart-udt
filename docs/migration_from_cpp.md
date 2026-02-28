# Migrating from upstream C++ UDT APIs

This port keeps upstream source references in `lib/src/upstream_udt_comment/` and
moves implementation to pure Dart typed wrappers.

## Module mapping

Use `UdtModule` + `dartTarget` for the canonical source-to-port map.

- Upstream `packet.h` / `packet.cpp` -> `lib/src/udt_port/protocol/`
- Upstream `epoll.h` / `epoll.cpp` -> `lib/src/udt_port/epoll/`
- Upstream lock/cond/worker-loop usage in `queue.h` / `queue.cpp` ->
  `lib/src/udt_port/core/threading.dart`
- Upstream `ccc.h` / `ccc.cpp` base `CCC` wrapper ->
  `lib/src/udt_port/ccc/congestion_control.dart`
- Upstream `md5.h` / `md5.cpp` hashing utility ->
  `lib/src/udt_port/common/md5.dart`
- Upstream sequence/message/ACK arithmetic in `common.h` (`CSeqNo`, `CMsgNo`,
  `CAckNo`) -> `lib/src/udt_port/common/sequence_numbers.dart`
- Upstream sender/receiver loss lists in `list.h` / `list.cpp` ->
  `lib/src/udt_port/list/loss_list.dart`

## API shape changes

- Pointer/alias packet ownership (`CPacket`) is replaced by immutable typed
  wrappers: `UdtPacketHeader`, `UdtPacket`, `UdtControlPacket`, and typed payload
  value objects.
- Binary payload layouts are encoded via explicit `ByteData` offsets to keep
  packet formats deterministic and auditable.
- Pthread primitives (`pthread_mutex_t`, `pthread_cond_t`, worker threads) are
  mapped to pure-Dart async primitives: `UdtAsyncMutex`, `UdtAsyncSignal`, and
  `UdtSerialExecutor`.
- Base congestion-control callback/configuration surface from `CCC` is mapped to
  `UdtCongestionControl` with injectable side effects (for example custom
  control-message send) to keep no-socket deterministic tests feasible.
- Upstream default congestion control `CUDTCC` is mapped to
  `UdtDefaultCongestionControl` (pure Dart), with injectable clock and seeded
  random providers so ACK/loss/timeout state transitions can be tested without
  socket I/O.

## Current limitations

- Socket-level parity, mixed local/system descriptor polling, and full
  congestion-control behavior are still tracked in `TODO_PORT.md`.
