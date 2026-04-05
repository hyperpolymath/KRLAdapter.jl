# KRLAdapter.jl — Examples

Runnable examples demonstrating the adapter's public API.

Each example is self-contained: activate the project and run with Julia.

```bash
cd KRLAdapter.jl
julia --project=. examples/01-trefoil-roundtrip.jl
```

## Index

- `01-trefoil-roundtrip.jl` — build trefoil, compute Jones, store in Skein, fetch back, verify UUID preserved
- `02-mirror-invariants.jl` — mirror a knot, verify determinant is mirror-invariant
- `03-compositional-operations.jl` — compose/tensor/close_tangle/mirror on TangleIR
- `04-query-by-invariant.jl` — populate a Skein DB and query by crossing number / determinant
