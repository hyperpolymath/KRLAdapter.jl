# `src/adapters/` — thin wrappers over community libraries

This directory is the ONLY place in KRLAdapter.jl that talks to KnotTheory.jl
or Skein.jl. The community libraries themselves are never modified.

## Files

| File | Wraps | Public API |
|---|---|---|
| `knottheory.jl` | `KnotTheory.jl` | `pd_to_ir`, `ir_to_pd`, `alexander`, `jones`, `determinant`, `signature`, `simplify`, `trefoil_ir`, `figure_eight_ir`, `unknot_ir` |
| `skein.jl` | `Skein.jl` (via its `KnotTheoryExt` extension) | `store_ir!`, `fetch_ir`, `query_ir` |

## Design rule

If you need a capability KnotTheory.jl or Skein.jl doesn't expose:

1. **First:** check if it really belongs upstream. If it's a general knot-theory or persistence concern that other community users would benefit from, file an upstream issue.
2. **Otherwise:** add the wrapper HERE. Never upstream in the community lib.

## Conversion pipeline

```
TangleIR ─── ir_to_pd ───▶ KnotTheory.PlanarDiagram ───▶ invariant / Reidemeister
                                      │
                                      └─▶ Skein.store! (PD-first path via KnotTheoryExt)
                                                │
                                                └─▶ returns String id
                                                    │
Skein.fetch_knot → record → Skein.to_planardiagram ─┘
                                      │
                                      └── pd_to_ir ──▶ TangleIR (with preserved UUID from metadata)
```

## Metadata conventions for Skein storage

When storing a TangleIR, the adapter writes these metadata keys (on the Skein record):

| Key | Value |
|---|---|
| `krl_ir_uuid` | `string(ir.id)` — lets us reconstruct the UUID on fetch |
| `krl_provenance` | `string(ir.metadata.provenance)` |
| `krl_source_text` | `ir.metadata.source_text` (if present) |
| `tag_0`, `tag_1`, … | user-supplied tags, indexed by position |

`fetch_ir` reads these back to reconstruct the original TangleIR with its
original UUID.

## Reserved namespaces

The `krl_*` metadata-key prefix is reserved for KRLAdapter. A future
`src/adapters/verisim.jl` (Phase 4 of `verisim-modular-experiment`) may
reuse this namespace to encode VerisimCore identity + provenance claims
alongside the Skein storage.
