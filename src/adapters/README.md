# `src/adapters/` — thin wrappers over community libraries

This directory is the ONLY place in KRLAdapter.jl that talks to KnotTheory.jl
or Skein.jl. The community libraries themselves are never modified.

## Files

| File | Wraps | Public API |
|---|---|---|
| `knottheory.jl` | `KnotTheory.jl` | `pd_to_ir`, `ir_to_pd`, `alexander`, `jones`, `determinant`, `signature`, `simplify`, `trefoil_ir`, `figure_eight_ir`, `unknot_ir` |
| `skein.jl` | `Skein.jl` (via its `KnotTheoryExt` extension) | `store_ir!`, `fetch_ir`, `query_ir` |
| `tangle.jl` | `tangle/` compiler (Tangle language, OCaml) | `pdv1_blob_to_ir`, `tangle_entries_to_ir` |

## Design rule

If you need a capability KnotTheory.jl or Skein.jl doesn't expose:

1. **First:** check if it really belongs upstream. If it's a general knot-theory or persistence concern that other community users would benefit from, file an upstream issue.
2. **Otherwise:** add the wrapper HERE. Never upstream in the community lib.

## Conversion pipeline

```
                        KRL source (via tangle/ compiler)
                                       │
                                 pdv1_blob_to_ir (text parse)
                                       │
                                       ▼
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

### Tangle bridge format

The OCaml Tangle compiler emits a `pdv1|x=...|c=...` text blob via
`Compositional.pdv1_blob_of_pd` (see `tangle/compiler/lib/compositional.ml`).

Format: `pdv1|x=a,b,c,d,s;a,b,c,d,s;...|c=arc,arc;arc,arc;...`

- `x=` section: crossings as `(arc1, arc2, arc3, arc4, sign)` 5-tuples, semicolon-separated
- `c=` section: components as comma-separated arc indices, components semicolon-separated

`pdv1_blob_to_ir` parses this into a `TangleIR` with `provenance = :imported`
and the raw blob preserved in `metadata.extra[:raw_blob]`.

**Round-trip through Skein:** verified working for trefoil + alternating-
sign diagrams (see `test/tangle_bridge_test.jl`). Tangle's arc convention
is compatible with KnotTheory's PD format for data-level round-trip
(arcs, signs, components all preserved, UUID preserved via metadata).

**Correctness caveat (not a data limitation, a semantic one):** invariant
computation on a tangle-sourced IR will give correct knot invariants only
if Tangle's compiler emitted a canonically-correct PD code. Hand-written
or malformed pdv1 blobs may parse successfully but encode invalid diagrams
whose KnotTheory-computed invariants are meaningless. End-to-end semantic
validation (tangle source → blob → IR → invariants match expected knot)
is future work — requires running Tangle's compiler in-process.

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

The `:source` key in `metadata.extra` is reserved for identifying where
a `TangleIR` came from:
- `:knottheory_pd` — from `pd_to_ir` (KnotTheory's `PlanarDiagram`)
- `:skein_fetch` — reconstructed via `fetch_ir`
- `:tangle_pdv1` — parsed from a Tangle `pdv1|...` blob
- `:tangle_entries` — from Tangle's 5-tuple entries directly
