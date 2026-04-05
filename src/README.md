# `src/` — KRLAdapter.jl source

## What lives here

| File | Purpose |
|---|---|
| `KRLAdapter.jl` | Module entry point. `include`s everything below. |
| `ir.jl` | Defines `TangleIR`, `Port`, `CrossingIR`, `TangleMetadata`. UUIDs, provenance, port-based boundaries. |
| `operations.jl` | Pure-IR operations: `compose`, `tensor`, `close_tangle`, `mirror`. No KnotTheory or Skein calls. |
| `adapters/` | Thin wrappers over community libs — see [adapters/README.md](adapters/README.md) |

## Module graph

```
KRLAdapter
├── ir              (no dependencies except UUIDs + Dates)
├── operations      (depends on ir)
└── adapters
    ├── knottheory  (depends on ir; imports KnotTheory)
    └── skein       (depends on ir; imports Skein + KnotTheory via extension path)
```

## Naming conventions

- IR types end in `IR` (`TangleIR`, `CrossingIR`). Library types do not (`Port`, `TangleMetadata`).
- Adapter functions use the community-facing name unqualified (`alexander`, `jones`, `determinant`) or with the target's clarity (`pd_to_ir`, `ir_to_pd`, `store_ir!`, `fetch_ir`, `query_ir`).
- Internal helpers start with `_` (see `operations.jl`'s `_renumber_arcs`).

## Invariants enforced here (not elsewhere)

- `TangleIR` always has a fresh UUID (via the convenience constructor).
- `TangleMetadata` defaults to `provenance = :user`; derivations must override to `:derived` / `:rewritten` / `:imported`.
- Tensor and compose shift `b`'s arc indices above `a`'s maximum so indices don't collide.
- `close_tangle` and `compose` reject mismatched port counts at runtime with `ArgumentError`.

## Do not add here

- Invariant algorithms (those belong in KnotTheory.jl)
- Storage schemas (those belong in Skein.jl)
- Quandle presentations (those belong in QuandleDB)
- KRL surface-language parsing (that belongs in `tangle/` / TanglePL)
