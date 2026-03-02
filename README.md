# dart_udt

[![Pub Version](https://img.shields.io/pub/v/dart_udt?label=pub.dev)](https://pub.dev/packages/dart_udt)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/dart-%5E3.3.0-blue.svg)](https://dart.dev/)

Pure-Dart-first, incremental port of UDT (UDP-based Data Transfer).

> Status: **pre-release** (`0.0.1-dev`). The package already provides deterministic protocol, planner, and runtime-adapter building blocks, while full end-to-end UDT socket/session parity is still in progress.

## Why this package

- Keep UDT behavior auditable while porting from upstream C++ (`lib/src/upstream_udt_comment/`).
- Prioritize deterministic, no-network tests for protocol/state logic.
- Provide typed Dart APIs (`class`, `enum`, `Uint8List`, `ByteData`) instead of pointer-style abstractions.

## What is usable today

- Packet/header/control codecs (`UdtPacket`, `UdtPacketHeader`, `UdtControlPacket`, `UdtHandshake`).
- Core deterministic helpers (sequence numbers, timer model, IP helpers, MD5, loss/window/cache/buffer models).
- Congestion-control base/default deterministic behavior models.
- Networking compatibility planners/simulators (socket options, dual-stack, MTU, mobile constraints, transition simulation).
- Runtime planning/execution adapters including `UdtSocketRuntimeApplier.applyProfile` and `UdtRawDatagramRuntimeTarget`.

See detailed mapping in `docs/migration.md` and port status in `TODO_PORT.md` + `docs/translation_status.md`.

## Install

```yaml
dependencies:
  dart_udt: ^0.0.1-dev
```

## Quickstart (pub-suitable, no real network I/O required)

Run:

```bash
dart run example/pub_quickstart.dart
```

This example demonstrates:

1. Building + parsing a control packet codec path.
2. Building a compatibility profile and runtime plan.
3. Running deterministic impairment simulation output.

## Other examples

- Deterministic control codec only:
  - `dart run example/control_packet_codec.dart`
- Deterministic network impairment trace:
  - `dart run example/network_simulation_trace.dart`

## Development

```bash
dart format .
dart analyze
dart test
```

## Current limitations

- Full socket/session parity with upstream UDT is still in progress.
- Mixed local/system descriptor epoll parity is pending.
- Some live `RawDatagramSocket` option setters are best-effort and platform-limited by `dart:io` capabilities.

## Documentation

- Migration guide: `docs/migration.md`
- Translation guardrail/status: `docs/translation_status.md`
- Trace-fixture corpus governance: `docs/upstream_trace_fixture_corpus.md`
- Port backlog and completion tracking: `TODO_PORT.md`
