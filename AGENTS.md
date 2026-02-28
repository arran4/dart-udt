# Agent notes for `dart-udt`

## Working conventions

- Keep the implementation pure Dart by default; only introduce FFI as a clearly optional follow-up.
- Port incrementally with line-by-line traceability to upstream reference files in `lib/src/upstream_udt_comment/`.
- Prefer typed Dart data models (`class`, `enum`, `Uint8List`, `ByteData`) over pointer-like abstractions.
- Any temporary scaffolding should be called out in `README.md` and tracked explicitly in `TODO_PORT.md`.

## Testing expectations

- Prioritize deterministic tests that do not require real network or file-system side effects.
- Build parsing/serialization and protocol-state tests so they can use fake clocks/mocks before live socket tests.
- Keep `dart analyze` and `dart test` passing before finalizing.

## Style

- Keep dependencies minimal; prefer in-house helpers for small needs.
- Run `dart format .` after changes.


## Porting notes discovered during implementation

- For protocol structs mirrored from upstream (for example `CHandShake` in `packet.h`), prefer explicit fixed-word constants and `ByteData` offsets over reflection/dynamic maps so binary layouts stay auditable and deterministic.
- When replacing upstream pointer/alias packet fields, prefer immutable typed wrappers (`UdtPacketHeader` + `Uint8List` payload in a typed container) to preserve ownership semantics without pointer abstractions.

- For control packet variants from upstream `CPacket::pack`, prefer a typed `UdtControlPacket` wrapper with dedicated payload value objects (for example ACK and message-drop payload classes) so deterministic tests can cover each variant without socket I/O.

## Additional implementation notes (session updates)

- Keep protocol-state timing logic injectable via a clock interface (`UdtProtocolClock`) with a fake clock implementation (`UdtFakeClock`) so ACK/NAK retransmission behavior can be tested deterministically without sockets.
- Maintain CI checks for `dart format --set-exit-if-changed .`, `dart analyze`, and `dart test` to enforce pure-Dart quality gates before merging.
- Keep runnable examples network-free where possible (codec/protocol-state examples) unless a TODO item explicitly requires live socket behavior.

- Control packet porting note: upstream `CPacket::pack` control variants are now all represented by typed constructors (`UdtControlPacket.*`), and tests should keep asserting branch-level parity on header fields and payload layout without socket I/O.

- Epoll porting milestone: keep the API centered on a pure-Dart `UdtEpoll` readiness model over typed socket IDs, with `UdtRawDatagramEventSource` as the adapter boundary; defer mixed local/system descriptor parity as explicit TODO until socket-layer modules are ported.

- Threading/locking parity note: when porting upstream `pthread_mutex_t`/`pthread_cond_t` sections (for example in `queue.h`/`queue.cpp`), prefer pure-Dart async wrappers (`UdtAsyncMutex`, `UdtAsyncSignal`, `UdtSerialExecutor`) and cover ordering/wakeup behavior with deterministic tests.
- Documentation note: keep `docs/migration_from_cpp.md` updated when public API wrappers are added so `dart doc` output has explicit C++ migration breadcrumbs.
- Epoll robustness note: guard `UdtEpoll.wait` to a single concurrent waiter per poll ID and only complete waiters once, then cover both paths with deterministic fake event-source tests.
