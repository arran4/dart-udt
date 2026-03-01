# dart-udt

[![Pub Version](https://img.shields.io/pub/v/dart_udt?label=pub.dev)](https://pub.dev/packages/dart_udt)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/dart-%5E3.3.0-blue.svg)](https://dart.dev/)

Work-in-progress **pure Dart-first** port of the UDT (UDP-based Data Transfer) library.

## Scope and architecture

- Primary implementation target is pure Dart (`dart:async`, `dart:io`, `dart:typed_data`).
- Optional `dart:ffi` acceleration may be added in the future for hotspots, but is explicitly non-blocking for functional parity.
- Upstream modules are tracked with an explicit target mapping to keep the port line-by-line auditable (`UdtModule` + `dartTarget`).

## API parity target

- Goal: provide practical parity with core UDT socket/session behavior from `udt.h`.
- Non-goals for first release: legacy/deprecated APIs that conflict with Dart's async model or require platform-specific native hooks.
- Temporary measure: packet header serialization/deserialization is implemented first as a deterministic building block while higher-level transport state machines remain TODO.
- Migration notes for C++ users live in `docs/migration.md` and are generated alongside API docs with `dart doc`.

## Platform and SDK support target

- Minimum Dart SDK: `^3.3.0`.
- Planned platforms: Linux, macOS, Windows, Android, iOS.
- Web support is aspirational and likely subset-only due to missing raw UDP primitives in browsers.

## Versioning and stability

- Current package version is pre-release (`0.0.1-dev`).
- Stability gate before `1.0.0`: module-level tests, packet compatibility fixtures, and reliable client/server integration tests.

## Upstream source basis

The upstream UDT sources were cloned from:

- `https://git.code.sf.net/p/udt/git`

Reference copies of upstream `udt4/src/*.{h,cpp}` are tracked as commented `.dart` scaffolds under:

- `lib/src/upstream_udt_comment/`

As modules are fully ported (for example `window.h`/`window.cpp`), their commented scaffolds are retired to avoid stale duplicate implementations.

These files are **not executable Dart implementations**; they are preserved as line-by-line references while porting.

## Current status

- Package scaffold is present.
- Deterministic pure-Dart UDT packet header parsing/serialization is implemented.
- Deterministic pure-Dart `CHandShake` payload encoding/decoding is implemented as a `ByteData`-backed layout adapter.
- Deterministic pure-Dart control packet wrappers are implemented for handshake, keep-alive, ACK, NAK, congestion warning, shutdown, ACK-2, message drop request, error signal, and user-defined control packet forms.
- A typed `UdtPacket` container replaces pointer/alias-style packet ownership for header + payload composition.
- A starter TODO plan for cross-platform implementation and full testing exists in `TODO_PORT.md`.
- Deterministic ACK/NAK retransmission timer modeling is available via `UdtAckNakTimerModel` with an injectable fake clock (`UdtFakeClock`) for no-socket tests.
- Pure-Dart threading/locking primitives (`UdtAsyncMutex`, `UdtAsyncSignal`, `UdtSerialExecutor`) now model upstream mutex/condition/worker-loop behavior without pthreads.
- Incremental pure-Dart epoll abstraction (`UdtEpoll`) is available with a stream-based adapter for `RawDatagramSocket` readiness events and deterministic fake event-source tests.
- A pure-Dart `UdtCongestionControl` base wrapper now ports upstream `CCC` callback/configuration surface with injectable custom-control send behavior for deterministic tests.
- A pure-Dart `UdtDefaultCongestionControl` now ports upstream `CUDTCC` `init`/`onACK`/`onLoss`/`onTimeout` behavior with injectable clock/random hooks for deterministic no-socket tests.
- A pure-Dart incremental MD5 utility (`UdtMd5`) now ports upstream `md5.h`/`md5.cpp` behavior with deterministic RFC1321 vector tests and no external dependencies.
- Pure-Dart sequence/message/ACK wraparound helpers (`UdtSequenceNumber`, `UdtMessageNumber`, `UdtAckNumber`) now port upstream `common.h` arithmetic with deterministic corpus tests for parser round-trip invariants.
- Pure-Dart IP helpers (`UdtIpAddress`) now port upstream `CIPAddress` word-layout compare/convert behavior with deterministic IPv4/IPv6 no-network tests.
- Pure-Dart timer/event helpers (`UdtTimer`) now port upstream `CTimer` sleep/interrupt/tick/event fallback behavior with deterministic fake-clock tests.
- Deterministic networking-compatibility planners (`UdtSocketOptionPlanner`, `buildUdtDualStackMatrix`) now cover section-4 socket-option and dual-stack planning branches without real socket I/O.
- Deterministic socket-option application (`UdtSocketOptionApplier`) now covers required-vs-optional failure semantics before live socket wiring.
- Socket-option graceful degradation is now integration-tested through runtime planning/execution: optional failures degrade to non-blocking skips, while required failures block bind attempts deterministically.
- Deterministic MTU planner (`UdtMtuPlanner`) and mobile constraints policy (`UdtMobileConstraintsPolicy`) now cover section-4 path-MTU and background/power transition planning branches without live platform hooks.
- MTU/path-MTU assumptions are now validated by deterministic Linux/macOS/Windows × IPv4/IPv6 matrix tests, plus bounded and in-range path-MTU hint coverage.
- Deterministic transition simulation (`UdtNetworkTransitionSimulator`) now models background/network-change sequences for section-4 ACK/RTO policy tuning without device hooks.
- Deterministic latency/loss simulator (`UdtLatencyLossSimulator`) now covers delay/reorder/jitter/drop branches with reproducible seeded outcomes for no-socket tests.
- Upstream-style seeded network-simulation parity fixture now locks expected delay/reorder/drop trace output for identical scenarios to keep behavior auditable over time.
- Mobile constraints now include deterministic matrix coverage for foreground/background, Wi-Fi/cellular/unknown network types, battery-saver behavior, and cumulative transition timing.
- Deterministic compatibility profile builder (`UdtCompatibilityProfileBuilder`) now composes section-4 planners (options/MTU/mobile) into a typed handoff model for upcoming socket-layer integration.
- Deterministic runtime socket plan (`UdtSocketRuntimePlanner`) now turns compatibility profiles into typed bind-strategy + option-application reports before live socket wiring.
- Deterministic socket lifecycle coordinator (`UdtSocketLifecycleCoordinator`) now models bind/pause/resume/shutdown transitions from runtime plans without real sockets.
- Deterministic runtime bind executor (`UdtSocketRuntimeExecutor`) now validates primary/fallback bind attempts and blocking-failure short-circuit behavior before live socket APIs.
- Deterministic matrix integration harness (`UdtSocketMatrixIntegrationHarness`) now wires `buildUdtDualStackMatrix` expectations into socket-layer runtime planner/executor integration tests without live sockets.
- IPv4/IPv6 parity coverage now asserts dual-stack matrix families across planned bind + planned connect stages in deterministic integration tests.
- Deterministic connect planner/executor (`UdtSocketConnectPlanner`, `UdtSocketConnectExecutor`) now models IPv4/IPv6 endpoint connect ordering and fallback before live connect hooks.
- Deterministic connectivity recovery policy (`UdtConnectivityRecoveryPolicy`) now models retry backoff/reset/escalation thresholds across app/network states without live sockets.
- Deterministic circuit breaker (`UdtCircuitBreaker`) now models open/half-open/closed failure handling over recovery policy decisions without live sockets.
- Pure-Dart sender/receiver loss-list wrappers (`UdtSndLossList`, `UdtRcvLossList`) now port upstream `list.h`/`list.cpp` interval semantics with deterministic NAK payload and removal tests that avoid socket I/O.
- Pure-Dart ACK/timing windows (`UdtAckWindow`, `UdtPacketTimeWindow`) now port upstream `window.h`/`window.cpp` with deterministic fake-clock tests for RTT, receive-speed, and probe-bandwidth calculations.
- Pure-Dart cache/info wrappers (`UdtLruCache`, `UdtInfoBlock`) now port upstream `cache.h`/`cache.cpp` entry/key semantics with deterministic no-network tests.
- Pure-Dart sender-buffer wrapper (`UdtSendBuffer`) now ports upstream `CSndBuffer` chunking/ACK/TTL behavior with deterministic no-network tests.
- Pure-Dart receiver-buffer wrapper (`UdtReceiveBuffer`) now ports upstream `CRcvBuffer` circular buffering/message-scan behavior with deterministic no-network tests.

## Temporary measures tracked

- Control packet wrappers now cover every upstream `CPacket::pack` control type branch; semantic handling above deterministic encoding/decoding is still incremental in higher protocol layers.
- ACK/NAK timeout modeling currently targets deterministic unit tests first; full integration with live socket scheduling remains TODO.
- Threading helpers currently target isolate-free async primitives for deterministic tests; optional isolate-backed execution can be layered later if needed.
- Epoll abstraction currently focuses on UDT-socket ID readiness sets; parity for mixed local/system descriptor polling remains TODO.
- `CUDTCC` behavior now includes deterministic no-socket trace fixtures for ACK/loss/timeout transitions; broader live-network equivalence remains tracked in `TODO_PORT.md`.
- Upstream commented MD5/cache/buffer references were retired after full pure-Dart replacements (`lib/src/udt_port/common/md5.dart`, `lib/src/udt_port/cache/cache.dart`, `lib/src/udt_port/buffer/send_buffer.dart`, `lib/src/udt_port/buffer/receive_buffer.dart`) to keep expansion areas free of stale commented implementation blocks.
- Sender/receiver buffer semantics are now covered by pure-Dart `UdtSendBuffer`/`UdtReceiveBuffer`; integration with live socket scheduling remains incremental.
- Networking/platform compatibility currently uses deterministic planning/runtime helpers first (socket options, dual-stack matrix, MTU, mobile constraints, runtime bind plans, lifecycle coordination, bind execution, recovery backoff, circuit breaker); live socket application/bind/connect validation remains TODO.

## Example

- Run the deterministic control codec example (no network needed):
  - `dart run example/control_packet_codec.dart`
- Run the deterministic planning/simulation microbenchmark:
  - `dart run benchmark/network_planning_benchmark.dart`
- Run the deterministic network simulation sample:
  - `dart run example/network_simulation_trace.dart`


## Docs

- Generate API docs locally with: `dart doc`.
- C++ to Dart API migration notes: `docs/migration.md`.
- Source-removal guardrail and per-file translation tracking: `docs/translation_status.md`.
