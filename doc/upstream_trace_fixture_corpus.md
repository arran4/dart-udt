# Upstream Trace-Fixture Corpus Versioning Notes

This note tracks deterministic network-impairment parity fixtures so long-term
behavior drift is auditable.

## Corpus ID

- **Corpus name:** `udt_latency_loss_seeded_trace`
- **Corpus version:** `v1`
- **Primary test:** `test/upstream_network_simulation_parity_test.dart`
- **Runnable sample:** `example/network_simulation_trace.dart`

## Provenance

- **Model:** `UdtLatencyLossSimulator`
- **Random source:** `UdtSeededRandomSource(2024)`
- **Config:**
  - `lossRate = 0.2`
  - `reorderRate = 0.35`
  - `maxJitterMillis = 12`
- **Inputs:** 8 packets with sequence `1..8`, each with `baseDelayMillis = 10`
- **Expected outputs:** tuple list in `test/upstream_network_simulation_parity_test.dart`
  (`(sequence, dropped, reordered, delayMillis)`).

## Change policy

When fixture behavior must change:

1. Add a new corpus version (for example `v2`) and keep `v1` documented.
2. Record *why* behavior changed (bug fix, intended algorithm alignment, etc.).
3. Update both test and runnable sample references.
4. Include before/after output snapshots in the PR description.

## Compatibility intent

The corpus is deterministic and no-network. Its purpose is branch-level parity
stability for impairment simulation behavior rather than live-socket throughput
performance claims.
