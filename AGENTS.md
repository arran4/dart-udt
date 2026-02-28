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
