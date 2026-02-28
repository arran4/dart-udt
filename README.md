# dart-udt

Work-in-progress **pure Dart-first** port of the UDT (UDP-based Data Transfer) library.

## Scope and architecture

- Primary implementation target is pure Dart (`dart:async`, `dart:io`, `dart:typed_data`).
- Optional `dart:ffi` acceleration may be added in the future for hotspots, but is explicitly non-blocking for functional parity.
- Upstream modules are tracked with an explicit target mapping to keep the port line-by-line auditable (`UdtModule` + `dartTarget`).

## API parity target

- Goal: provide practical parity with core UDT socket/session behavior from `udt.h`.
- Non-goals for first release: legacy/deprecated APIs that conflict with Dart's async model or require platform-specific native hooks.
- Temporary measure: packet header serialization/deserialization is implemented first as a deterministic building block while higher-level transport state machines remain TODO.

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

Reference copies of upstream `udt4/src/*.{h,cpp}` have been renamed to `.dart` files and fully commented out under:

- `lib/src/upstream_udt_comment/`

These files are **not executable Dart implementations**; they are preserved as line-by-line references while porting.

## Current status

- Package scaffold is present.
- Deterministic pure-Dart UDT packet header parsing/serialization is implemented.
- Deterministic pure-Dart `CHandShake` payload encoding/decoding is implemented as a `ByteData`-backed layout adapter.
- Deterministic pure-Dart control packet wrappers are implemented for handshake, ACK, NAK, keep-alive, ACK-2, and message drop request payloads.
- A typed `UdtPacket` container replaces pointer/alias-style packet ownership for header + payload composition.
- A starter TODO plan for cross-platform implementation and full testing exists in `TODO_PORT.md`.

## Temporary measures tracked

- Control packet wrapper coverage exists for handshake/ACK/NAK/keep-alive/ACK-2/message-drop deterministic codecs, while congestion warning, shutdown, error signal, and user-defined control extensions still need dedicated typed wrappers.
