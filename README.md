# dart-udt

Scaffold for porting the UDT C++ implementation to a cross-platform Dart library.

## Upstream source basis

The upstream UDT sources were cloned from:

- `https://git.code.sf.net/p/udt/git`

Reference copies of upstream `udt4/src/*.{h,cpp}` have been renamed to `.dart` files and fully commented out under:

- `lib/src/upstream_udt_comment/`

These files are **not executable Dart implementations**; they are preserved as line-by-line references while porting.

## Current status

- Basic package scaffold is present.
- A starter TODO plan for cross-platform implementation and full testing exists in `TODO_PORT.md`.
- No production UDT protocol functionality is implemented yet.
