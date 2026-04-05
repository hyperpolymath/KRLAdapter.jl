<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# TEST-NEEDS — KRLAdapter.jl

Honest accounting of what's tested, what isn't, and what should be.

## What's tested today (as of 2026-04-05)

**Total: 5,405 passing assertions.** Runs in ~20s cold, ~2s warm.

| Category | Status | Evidence |
|---|---|---|
| unit | ✓ | `test/ir_test.jl`, `test/operations_test.jl` — 27 assertions |
| E2E | ✓ | `test/adapter_roundtrip.jl` — trefoil build→invariants→store→fetch→verify (24 assertions) |
| property-based | ✓ | `test/property_test.jl` — 11 properties × 100 iterations each (~1,100 assertions) |
| fuzz (smoke) | ✓ | `test/fuzz_smoke.jl` — 5 fuzz loops × 200–500 iterations (~4,000 assertions) |
| build | ✓ | CI workflows present (14), Project.toml compat bounds set |
| execution | ✓ | tests exercise the full runtime path |
| contract | ○ | adapter roundtrip acts as de-facto contract test; no formal contract language |

## What's NOT tested (gaps)

| Category | Why missing | Priority |
|---|---|---|
| P2P | No distributed / inter-process surface to test | low (N/A for a library) |
| reflexive | No introspection APIs to test | low |
| lifecycle | Skein DB open/close is covered in roundtrip; no KRLAdapter-owned lifecycle | low |
| smoke (named) | Smoke covered implicitly; no explicit smoke test file | low |
| mutation | Would need `Mutation.jl` or hand-crafted mutation operators | medium |
| fuzz (deep) | Current fuzz is smoke-level; no structured corpus-based fuzzing | medium |
| regression (named) | No named regression-test suite distinct from unit tests | medium |
| chaos | No fault-injection harness; would need DB-error injection | medium |
| compatibility | Only Julia 1.10+ tested on one platform; no cross-version/cross-OS matrix | medium |
| proof-regression | Not applicable yet; no formal proofs for this package | low (until KRL matures) |

## Test invariants currently verified (property-based)

1. `mirror(mirror(ir)) == ir` sign-wise and arc-wise
2. `mirror(ir)` flips every crossing sign
3. `writhe(mirror(ir)) == -writhe(ir)`
4. `crossing_count(mirror(ir)) == crossing_count(ir)`
5. `tensor(a, b)` is additive in crossing count
6. `tensor(a, b)` renumbers `b`'s arcs above `a`'s max
7. `compose(a, b)` with matching ports sums crossings
8. `compose` throws ArgumentError on port-count mismatch
9. `close_tangle` with matching port counts empties ports
10. `close_tangle` throws on port-count mismatch
11. `mirror`/`tensor` record `:derived` provenance

## What would push toward grade C

Per READINESS.md, the path to C includes:
- ~1 week of dogfooding in real workflows
- Per-directory READMEs (not just root)
- Benchmark comparison against a baseline (baseline established 2026-04-05)
- TEST-NEEDS.md (this file ✓)
- EXPLAINME.adoc (added 2026-04-05 ✓)

Remaining for C after this iteration: dogfooding evidence + per-directory annotation.

## Evidence for what DOES work reliably

- Trefoil end-to-end roundtrip through Skein preserves IR UUID and Jones polynomial
- Mirror is provably an involution on TangleIR (property test, 100 iterations)
- Tensor's arc-renumbering invariant holds for random inputs (property test)
- Fuzz inputs (500 iterations, well-formed random) do not crash construction or operations

## Evidence for what HAS NOT BEEN verified

- Behaviour under malformed arc tuples with overlaps (no constructor validation — trusts caller)
- Behaviour with extremely large crossing counts (>50) — not stress-tested
- Concurrent use of `store_ir!` across two sessions (no concurrency test)
- Error recovery if Skein DB becomes corrupted mid-transaction
