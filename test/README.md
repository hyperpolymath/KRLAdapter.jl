# `test/` — KRLAdapter.jl test suite

Run with `julia --project=. -e 'using Pkg; Pkg.test()'` from the repo root.

## Files

| File | Purpose | Size |
|---|---|---|
| `runtests.jl` | Entry point. `include`s every test file below. | - |
| `ir_test.jl` | Unit tests for `TangleIR`, `Port`, `CrossingIR`, `TangleMetadata` | ~15 assertions |
| `operations_test.jl` | Unit tests for `compose`, `tensor`, `close_tangle`, `mirror` | ~15 assertions |
| `adapter_roundtrip.jl` | E2E: trefoil → Jones → Skein → fetch → verify UUID + invariants | ~24 assertions |
| `property_test.jl` | 11 algebraic properties × 100 iterations each | ~1,100 assertions |
| `fuzz_smoke.jl` | 5 fuzz loops × 200–500 iterations on random well-formed input | ~4,000 assertions |

## Total count

5,405 passing assertions as of 2026-04-05. Runs in ~20s cold, ~2s warm.

## What each test category covers

- **`ir_test.jl`**: type construction, UUID allocation, default metadata, closed-diagram detection.
- **`operations_test.jl`**: mirror flips signs, mirror is involution, tensor arc shifting, compose port discipline, close_tangle clears ports.
- **`adapter_roundtrip.jl`**: the end-to-end integration that matters most — can we round-trip a real knot through Skein with invariants + UUID preserved?
- **`property_test.jl`**: invariants that should hold for *any* well-formed TangleIR — not example-based. Uses deterministic seeds (SEED=20260405 + offsets) for reproducibility.
- **`fuzz_smoke.jl`**: cheap random-input coverage. Not a replacement for proper fuzzing, but catches crashes on edge-case inputs.

## Adding tests

1. Pick the right file for the category:
   - Single-function unit → `ir_test.jl` or `operations_test.jl`
   - Algebraic invariant → `property_test.jl` (wrap in `@testset`, seed your RNG)
   - Integration → `adapter_roundtrip.jl`
   - Crash safety → `fuzz_smoke.jl`
2. Don't add Skein or KnotTheory to `Project.toml`'s runtime deps — they're already in `[extras]`.
3. Keep seeds reproducible. The convention is `SEED + offset` per testset.
