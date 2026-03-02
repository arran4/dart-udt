# Upstream-to-Dart Translation Status (Removal Guardrail)

This file exists to ensure upstream commented references are only removed once
functionality is fully translated/replaced in pure Dart.

## Policy

- Keep upstream `lib/src/upstream_udt_comment/*.dart` references intact until every
  listed behavior is represented by typed pure-Dart code plus deterministic tests.
- Only then replace the upstream scaffold with a short retired-pointer file.
- If translation is partial, keep the upstream scaffold and add TODO notes instead
  of deleting commented source blocks.

## File-level status

| Upstream scaffold | Dart replacement | Status | Deterministic test coverage |
|---|---|---|---|
| `packet_h.dart` / `packet_cpp.dart` | `lib/src/udt_port/protocol/` | In progress | Yes (codec/control tests) |
| `list_h.dart` / `list_cpp.dart` | `lib/src/udt_port/list/loss_list.dart` | Complete (retained reference file still present) | Yes |
| `window_h` / `window_cpp` (covered by upstream source map) | `lib/src/udt_port/window/window.dart` | Complete | Yes |
| `md5_h.dart` / `md5_cpp.dart` | `lib/src/udt_port/common/md5.dart` | Complete (retired scaffold) | Yes |
| `cache_h.dart` / `cache_cpp.dart` | `lib/src/udt_port/cache/cache.dart` | Complete (retired scaffold) | Yes |
| `buffer_h.dart` / `buffer_cpp.dart` | `lib/src/udt_port/buffer/send_buffer.dart`, `lib/src/udt_port/buffer/receive_buffer.dart` | Complete (retired scaffold) | Yes |
| `common_h.dart` / `common_cpp.dart` | `lib/src/udt_port/common/sequence_numbers.dart`, `ip_address.dart`, `timer.dart`, `core/threading.dart` | In progress | Yes (partial) |
| `epoll_h.dart` / `epoll_cpp.dart` | `lib/src/udt_port/epoll/poll.dart` | In progress | Yes |
| `ccc_h.dart` / `ccc_cpp.dart` | `lib/src/udt_port/ccc/congestion_control.dart` | In progress | Yes |
| `queue_h.dart` / `queue_cpp.dart` | `lib/src/udt_port/core/threading.dart`, `lib/src/udt_port/queue/queue_structures.dart` + future queue worker/socket modules | In progress | Yes (threading primitives + deterministic list/hash tests) |
| `api_h.dart` / `api_cpp.dart` | Planned socket/API modules + `network/platform_compatibility.dart`, `network/socket_option_application.dart`, `network/mobile_constraints.dart`, `network/mtu_planning.dart`, `network/transition_simulation.dart`, `network/compatibility_profile.dart`, `network/socket_runtime_plan.dart`, `network/socket_lifecycle.dart`, `network/socket_runtime_execution.dart`, `network/connectivity_recovery.dart`, `network/circuit_breaker.dart` | In progress | Partial |
| `core_h.dart` / `core_cpp.dart` | Planned connection/socket state modules | In progress | Partial |
| `channel_h.dart` / `channel_cpp.dart` | Planned channel/socket transport modules | In progress | No |

## Retirement checklist

Before replacing an upstream scaffold with a short retired-pointer file, confirm:

1. Public/observable behavior is represented by typed pure-Dart APIs.
2. Deterministic tests cover normal + branch/error paths.
3. `README.md`, `docs/migration.md`, and `TODO_PORT.md` are updated.
4. Any remaining gaps are explicit TODO items.
