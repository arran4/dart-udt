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
- Documentation note: keep `doc/migration.md` updated when public API wrappers are added so `dart doc` output has explicit C++ migration breadcrumbs.
- Epoll robustness note: guard `UdtEpoll.wait` to a single concurrent waiter per poll ID and only complete waiters once, then cover both paths with deterministic fake event-source tests.
- CCC base porting note: keep upstream `CCC` side effects injectable (for example custom control-message sending) so base callback/configuration parity can be tested deterministically without socket I/O.
- CUDTCC porting note: keep `UdtDefaultCongestionControl` clock and randomization hooks injectable so `init`/`onACK`/`onLoss`/`onTimeout` parity tests stay deterministic without network resources.

- MD5 porting note: upstream `md5.h`/`md5.cpp` are now represented by pure-Dart `UdtMd5` with deterministic RFC1321 vectors and incremental append/finalize tests; retire large commented MD5 scaffold blocks once replacement parity lands.

- Congestion-control parity note: keep deterministic `CUDTCC` trace-fixture tests for ACK/loss/timeout transitions so `ccc.cpp` branches remain auditable without socket I/O.

- Cache porting note: upstream `CCache`/`CInfoBlock` behavior should remain in typed pure-Dart wrappers (`UdtLruCache`, `UdtInfoBlock`) with deterministic no-network tests for key/equality/LRU semantics.

- Buffer porting note: keep upstream `CSndBuffer`/`CRcvBuffer` transitions explicit in typed wrappers; maintain deterministic no-network tests for sender (`UdtSendBuffer`) and receiver (`UdtReceiveBuffer`) branches before socket integration.

- CI note: keep `dart analyze` running on every push (all branches) while allowing heavier checks (`dart format --set-exit-if-changed .`, `dart test`, `dart doc`) to be conditional on event/ref as needed.

- Common/IP porting note: keep upstream `CIPAddress` compare/ntop/pton behavior represented by deterministic typed helpers (`UdtIpAddress`) with IPv4/IPv6 tests that avoid sockets.

- Timer porting note: keep upstream `CTimer` sleep/sleepto/interrupt/tick/event behavior injectable with fake clocks/signals (`UdtTimer`) so no-socket deterministic timing tests stay stable.

- Networking compatibility note: for section-4 parity, keep socket-option and dual-stack behavior first modeled as deterministic planners/matrices (`UdtSocketOptionPlanner`, `buildUdtDualStackMatrix`) before wiring live socket I/O.

- Source-retirement guardrail: only replace `lib/src/upstream_udt_comment/*` scaffolds after full behavior translation + deterministic tests are in place; track file-level status in `doc/translation_status.md`.

- Socket-option application note: keep required-vs-optional apply semantics explicit via a deterministic adapter (`UdtSocketOptionApplier`) before binding to live socket APIs.

- MTU/mobile compatibility note: keep section-4 path-MTU and mobile background/power/network transitions modeled with deterministic policies (`UdtMtuPlanner`, `UdtMobileConstraintsPolicy`) before live platform integration.

- Transition-simulation note: keep section-4 lifecycle/network-change behavior auditable with deterministic transition simulation (`UdtNetworkTransitionSimulator`) before live mobile hooks are added.

- Compatibility-profile note: keep section-4 planner outputs composable via a typed profile (`UdtCompatibilityProfileBuilder`) so upcoming live socket modules can consume deterministic decisions consistently.

- Runtime-plan note: keep section-4 bind/connect strategy explicit via deterministic runtime plans (`UdtSocketRuntimePlanner`) before live socket APIs are introduced.

- Lifecycle note: keep section-4 socket lifecycle behavior (bind/pause/resume/shutdown) modeled via deterministic coordination (`UdtSocketLifecycleCoordinator`) before live socket runtime hooks.

- Runtime-execution note: keep section-4 bind execution fallback behavior modeled deterministically (`UdtSocketRuntimeExecutor`) with explicit attempt reporting before live sockets.

- Recovery-policy note: keep section-4 retry/reset/escalation behavior deterministic (`UdtConnectivityRecoveryPolicy`) so failure handling can be validated before live sockets.

- Circuit-breaker note: keep section-4 failure gating deterministic (`UdtCircuitBreaker`) with explicit open/half-open/closed transitions before live socket runtime hooks.

- Queue-structure porting note: keep upstream `CRcvUList` and `CHash` behavior in typed pure-Dart wrappers (`UdtReceiveUserList`, `UdtSocketHash`) with deterministic collision/order tests before worker-thread/socket queue integration.

- Live-runtime adapter note: keep `UdtSocketRuntimeApplier.applyProfile` orchestrating option-plan build + bind/connect execution through a shared typed target (`UdtRawDatagramRuntimeTarget`) so connect fallback parity remains testable with deterministic fakes.

- Trace-fixture governance note: keep deterministic impairment corpus provenance/version details updated in `doc/upstream_trace_fixture_corpus.md` whenever seeded network parity fixtures change.

- Live socket-option bridge note: keep `UdtRawDatagramRuntimeTarget` option setters aligned with `UdtSocketOptionRecommendation` mapping and maintain deterministic runtime-target tests for optional-skip vs required-failure branches.

- Pub-readiness docs note: keep `README.md` centered on a runnable quickstart (`example/pub_quickstart.dart`) and clearly separate currently-shipping deterministic features from pending full UDT parity work.
