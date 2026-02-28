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
- [ ] Create deterministic serialization/deserialization tests for packet headers and control messages (handshake complete; ACK/NAK/KEEPALIVE/etc. pending).
- [x] Add initial pure-Dart packet header codec (`UdtPacketHeader`) using `ByteData` and deterministic tests as first protocol building block.

## 3. Concurrency and eventing
- [ ] Port threading/locking model to Dart isolates and async primitives.
- [ ] Model timers, retransmission, ACK/NAK handling with deterministic fake clocks for tests.
- [ ] Provide poll/epoll-style API abstraction mapped to `RawDatagramSocket` event streams.

## 4. Networking and platform compatibility
- [ ] Implement IPv4/IPv6 behavior parity and dual-stack test matrix.
- [ ] Handle socket options per-platform (buffer sizes, reuse flags) with graceful degradation.
- [ ] Validate MTU/path-MTU assumptions across Linux/macOS/Windows.
- [ ] Define mobile constraints (backgrounding, power/network transitions).

## 5. Reliability, congestion control, and performance
- [ ] Port congestion control base (`CCC`) and verify algorithmic equivalence with trace fixtures.
- [ ] Build reproducible latency/loss simulation tests (delay, reordering, jitter, drop).
- [ ] Add benchmarks: throughput, CPU, memory, connection setup latency.
- [ ] Compare against upstream UDT behavior on identical network simulation scenarios.

## 6. Testing strategy (full coverage goal)
- [ ] Unit tests for each ported module with branch coverage targets.
- [ ] Golden protocol tests from captured upstream packet traces.
- [ ] Integration tests: loopback client/server file transfer with integrity checks.
- [ ] Cross-platform CI matrix: Linux, macOS, Windows (and optional Android/iOS emulation).
- [ ] Fuzz/property tests for packet parser and state machine transitions.
- [ ] Long-running soak tests for stability and resource leaks.
- [x] Add deterministic protocol codec tests that avoid real network/file resources.

## 7. Tooling, docs, and pub.dev readiness
- [ ] Enable strict lints, formatting, and static analysis in CI.
- [ ] Generate API docs (`dart doc`) with migration notes from C++ API.
- [ ] Add examples (`example/`) for client/server usage.
- [x] Provide platform support table and known limitations in README.
- [ ] Validate pub score inputs: license, topics, screenshots/badges, example quality.
- [ ] Publish as pre-release first (`-dev`), gather feedback, then stable release.
