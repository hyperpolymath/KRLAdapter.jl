# `benchmark/` — KRLAdapter.jl benchmark suite

Run with `julia --project=. benchmark/benchmarks.jl` from the repo root.

## Purpose

Establish baseline timings for the adapter layer so future changes can be
measured against them. Six Sigma classification is deferred until a stable
baseline exists across releases.

## Baseline (2026-04-05, Julia 1.12.5)

| Operation | min | median |
|---|---|---|
| `trefoil_ir()` | 3.6μs | 4.1μs |
| `pd_to_ir(trefoil.pd)` | 3.5μs | 4.2μs |
| `ir_to_pd(trefoil_ir)` | 0.1μs | 0.1μs |
| `alexander(trefoil)` | 4.1μs | 4.9μs |
| `jones(trefoil)` | 97μs | 136μs |
| `determinant(trefoil)` | 3.7μs | 6.2μs |
| `mirror(trefoil)` | 1.9μs | 2.0μs |
| `compose(a, b)` | 2.5μs | 2.9μs |
| `tensor(a, b)` | 2.7μs | 3.1μs |
| `store_ir!(trefoil)` | 412μs | 450μs |
| `fetch_ir(existing)` | 189μs | 213μs |
| `query_ir(crossing=3)` | 3,118μs | 4,531μs |

## Interpretation

- **Pure TangleIR operations (compose/tensor/mirror):** ~2-5μs. Cheap.
- **IR↔PD conversion:** ~4μs each way. Negligible adapter overhead.
- **Invariant computation:** dominated by KnotTheory's compute (Jones 136μs), not adapter overhead (~5μs for adapter-wrap).
- **Skein persistence:** dominant cost is SQLite (store 450μs, query 4.5ms). Adapter serialisation is ~50μs at most.

## Future work

- Benchmark on varying crossing counts (not just trefoil)
- Benchmark IR roundtrip under concurrent access
- Compare fetch_ir warm vs. cold cache
- Once 3+ baselines exist across releases, apply Six Sigma classification per
  CRG blitz definition
