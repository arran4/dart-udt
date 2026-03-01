# UDT to Dart Port TODO (Cross-Platform)

## 1. Foundation and architecture
- [x] Define package scope for pure Dart vs optional `dart:ffi` acceleration.
- [x] Document API parity targets with `udt.h` and unsupported legacy APIs.
- [x] Decide minimum Dart SDK and supported platforms (Linux/macOS/Windows/Android/iOS/Web where possible).
- [x] Establish semantic versioning and stability gates before first pub.dev release.

## 2. Source decomposition (from C++ modules)
- [x] Map these modules into Dart libraries: `api`, `core`, `channel`, `epoll`, `queue`, `buffer`, `packet`, `window`, `cache`, `list`, `ccc`, `md5`, `common`.
- [x] Replace pointer-heavy data structures with typed Dart classes/records.
- [x] Define memory/packet layout adapters using `ByteData` and `Uint8List`.
- [x] Create deterministic serialization/deserialization tests for packet headers and control messages (handshake/ACK/NAK/KEEPALIVE/ACK2/message-drop wrappers covered).
- [x] Add initial pure-Dart packet header codec (`UdtPacketHeader`) using `ByteData` and deterministic tests as first protocol building block.
- [x] Add typed deterministic wrappers/tests for all upstream control packet variants in `CPacket::pack` (handshake, keep-alive, ACK, NAK, congestion warning, shutdown, ACK-2, message-drop, error signal, user-defined).
- [x] Port upstream `md5.h`/`md5.cpp` into pure-Dart incremental hashing (`UdtMd5`) with deterministic RFC1321 test vectors and no external dependencies.
- [x] Port upstream `list.h`/`list.cpp` sender/receiver loss-list behavior into typed pure-Dart interval models (`UdtSndLossList`, `UdtRcvLossList`) with deterministic no-socket tests.
- [x] Port upstream `window.h`/`window.cpp` ACK/timing window behavior into pure-Dart typed models (`UdtAckWindow`, `UdtPacketTimeWindow`) with injectable fake-clock deterministic tests.
- [x] Port upstream `cache.h`/`cache.cpp` cache/info behavior into pure-Dart typed models (`UdtLruCache`, `UdtInfoBlock`) with deterministic no-network tests.
- [x] Port upstream `CSndBuffer` behavior from `buffer.h`/`buffer.cpp` into pure-Dart typed models (`UdtSendBuffer`) with deterministic chunking/ACK/TTL tests.
- [x] Port upstream `CRcvBuffer` behavior from `buffer.h`/`buffer.cpp` into pure-Dart typed receive-message buffering models with deterministic no-network tests.
- [x] Port upstream `CIPAddress` helpers from `common.h` into pure-Dart typed conversion/comparison helpers (`UdtIpAddress`) with deterministic IPv4/IPv6 tests.
- [x] Port upstream `CTimer` event/tick/sleep fallback behavior from `common.h`/`common.cpp` into pure-Dart deterministic helpers (`UdtTimer`) with fake-clock tests.

## 3. Concurrency and eventing
- [x] Port threading/locking model to Dart isolates and async primitives.
- [x] Model timers, retransmission, ACK/NAK handling with deterministic fake clocks for tests.
- [x] Provide poll/epoll-style API abstraction mapped to `RawDatagramSocket` event streams.

## 4. Networking and platform compatibility
- [ ] Implement IPv4/IPv6 behavior parity and dual-stack test matrix.
  - [x] Add deterministic dual-stack planning matrix generator for Linux/macOS/Windows (`buildUdtDualStackMatrix`) with no-socket tests.
  - [ ] Wire matrix expectations into socket-layer integration tests once live bind/connect modules are ported.
- [ ] Handle socket options per-platform (buffer sizes, reuse flags) with graceful degradation.
  - [x] Add deterministic per-platform socket-option planner (`UdtSocketOptionPlanner`) for pre-bind compatibility policy.
  - [ ] Apply planned options to live sockets in upcoming socket-layer modules with graceful fallback logging.
- [ ] Validate MTU/path-MTU assumptions across Linux/macOS/Windows.
- [ ] Define mobile constraints (backgrounding, power/network transitions).

## 5. Reliability, congestion control, and performance
- [x] Port congestion control base (`CCC`) and verify algorithmic equivalence with trace fixtures.
  - [x] Port upstream `CCC` base callback/configuration surface (`setACKTimer`, `setACKInterval`, `setRTO`, `setUserParam`, and injectable custom control-message send path) as a pure-Dart wrapper with deterministic unit tests.
  - [x] Port upstream default `CUDTCC` algorithm behavior (`onACK`/`onLoss`/`onTimeout`) with deterministic parity tests (rate-control interval, slow-start, loss decrease, timeout branches) that avoid real socket I/O.
- [ ] Build reproducible latency/loss simulation tests (delay, reordering, jitter, drop).
- [ ] Add benchmarks: throughput, CPU, memory, connection setup latency.
- [ ] Compare against upstream UDT behavior on identical network simulation scenarios.

## 6. Testing strategy (full coverage goal)
- [ ] Unit tests for each ported module with branch coverage targets.
- [x] Golden protocol tests from captured upstream packet traces.
- [ ] Integration tests: loopback client/server file transfer with integrity checks.
- [ ] Cross-platform CI matrix: Linux, macOS, Windows (and optional Android/iOS emulation).
- [x] Fuzz/property tests for packet parser and state machine transitions.
- [ ] Long-running soak tests for stability and resource leaks.
- [x] Add deterministic protocol codec tests that avoid real network/file resources.
- [x] Expand deterministic unit tests for currently ported pure-Dart modules (`epoll`, timer model, codec wrappers) to cover error and concurrency branches without socket/file I/O.

## 7. Tooling, docs, and pub.dev readiness
- [x] Enable strict lints, formatting, and static analysis in CI.
- [x] Generate API docs (`dart doc`) with migration notes from C++ API.
- [x] Add examples (`example/`) for client/server usage.
- [x] Provide platform support table and known limitations in README.
- [x] Validate pub score inputs: license, topics, screenshots/badges, example quality.
- [ ] Publish as pre-release first (`-dev`), gather feedback, then stable release.

- [x] Add explicit upstream-source removal guardrail + per-file translation status tracker (`docs/translation_status.md`) to ensure commented references are only retired after full pure-Dart replacement + deterministic tests.
- [ ] Final cleanup pass: retire or relocate all temporary migration/reference files once corresponding modules reach stable parity.
