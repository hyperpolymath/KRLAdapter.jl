# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
VerisimCore adapter — STUB for Phase 4 of the verisim-modular-experiment.

This adapter is intentionally a *stub*. It declares the interface surface
KRLAdapter.jl expects to present to a slim VerisimCore (Core = {Semantic,
Provenance, Temporal} per Phase 1 of the experiment), but does not yet
wire a concrete VerisimCore implementation.

When Phase 3 of the experiment produces a working reference VerisimCore,
the user of KRLAdapter.jl imports it and re-defines these methods on their
concrete core type (or — preferred — wires via a Julia package extension).

## Phase 4 readiness

This stub encodes the "keep the interface slot open" commitment recorded
in memory:verisim-modular-experiment-krladapter-link.md. The KRL stack is
Core-only (Semantic + Provenance + Temporal needs map cleanly to TangleIR
tags, provenance metadata, and UUID/timestamps respectively).

Federable shapes NOT expected by this adapter: Vector, Tensor, Spatial,
Document (Graph conditional).

## Error behaviour

Each function throws `VerisimCoreNotWiredError` until a concrete VerisimCore
type's methods are defined by a downstream user or extension package.
"""

export AbstractVerisimCore, VerisimCoreNotWiredError
export store_ir_verisim!, fetch_ir_verisim, query_ir_verisim, prove_consonance
export ConsonanceVerdict

"""
    AbstractVerisimCore

Marker supertype for concrete VerisimCore implementations. Phase 3 of the
verisim-modular-experiment will provide the first concrete subtype.
Downstream users subtype this to provide their own core.
"""
abstract type AbstractVerisimCore end

"""
    VerisimCoreNotWiredError

Thrown by every stub method when called without a concrete VerisimCore
implementation registered. Includes a pointer to the experiment docs.
"""
struct VerisimCoreNotWiredError <: Exception
    method_name::String
end

function Base.showerror(io::IO, e::VerisimCoreNotWiredError)
    print(io, "VerisimCoreNotWiredError: $(e.method_name) called without a concrete ",
          "AbstractVerisimCore subtype's method defined.\n\n")
    print(io, "This is a stub for Phase 4 of verisim-modular-experiment.\n")
    print(io, "To wire up, either:\n")
    print(io, "  1. Subtype AbstractVerisimCore and define the 4 stub methods, OR\n")
    print(io, "  2. Load a VerisimCore implementation package that does so.\n\n")
    print(io, "See: nextgen-databases/verisim-modular-experiment/ for status.")
end

"""
    ConsonanceVerdict

Result of a `prove_consonance` call. Phase 2 of the experiment specifies
the consonance claim structure; this is a placeholder shape.

# Fields
- `consonant::Bool`: whether the two IRs are treated as equivalent under VCL
- `witness::Union{String,Nothing}`: optional evidence/proof-sketch (if the
  core provides one)
- `reason::String`: human-readable rationale
"""
struct ConsonanceVerdict
    consonant::Bool
    witness::Union{String,Nothing}
    reason::String
end

# ----------------------------------------------------------------------
# Stub methods — concrete cores define these for their subtype
# ----------------------------------------------------------------------

"""
    store_ir_verisim!(core::AbstractVerisimCore, ir::TangleIR; name=nothing, tags=String[]) -> UUID

Persist a `TangleIR` to VerisimCore's identity + provenance layer.

## Expected semantics (Phase 4 hypothesis)
- Identity: the TangleIR's UUID is preserved in the core's identity layer.
- Provenance: the IR's `metadata.provenance` + any `:parent_id` in
  `metadata.extra` feed the core's provenance chain.
- Temporal: the core assigns/records first-seen-at and last-updated-at timestamps.
- Tags: semantic annotations written to the core's Semantic shape.

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Override for your concrete core type.
"""
function store_ir_verisim!(::AbstractVerisimCore, ::TangleIR;
        name::Union{String,Nothing} = nothing,
        tags::Vector{String} = String[])
    throw(VerisimCoreNotWiredError("store_ir_verisim!"))
end

"""
    fetch_ir_verisim(core::AbstractVerisimCore, id::UUID) -> Union{TangleIR,Nothing}

Retrieve a previously-stored `TangleIR` by its UUID, reconstructing metadata
from the core's Semantic + Provenance + Temporal layers.

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Override for your concrete core type.
"""
function fetch_ir_verisim(::AbstractVerisimCore, ::UUID)
    throw(VerisimCoreNotWiredError("fetch_ir_verisim"))
end

"""
    query_ir_verisim(core::AbstractVerisimCore; predicates...) -> Vector{UUID}

Query VerisimCore for IRs matching the given predicates. Predicates are
VCL-shaped filters on Semantic tags, Provenance chain entries, or Temporal
ranges.

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Override for your concrete core type.
"""
function query_ir_verisim(::AbstractVerisimCore; kwargs...)
    throw(VerisimCoreNotWiredError("query_ir_verisim"))
end

"""
    prove_consonance(core::AbstractVerisimCore, ir1::TangleIR, ir2::TangleIR) -> ConsonanceVerdict

Ask VerisimCore whether two IRs should be treated as consonant under VCL's
constraint-language semantics. Consonance is finer-grained than equality —
two IRs may be consonant despite having different UUIDs, tags, or
provenance chains, if VCL's proof apparatus can establish the equivalence.

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Override for your concrete core type.
"""
function prove_consonance(::AbstractVerisimCore, ::TangleIR, ::TangleIR)
    throw(VerisimCoreNotWiredError("prove_consonance"))
end
