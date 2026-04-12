# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
VerisimCore adapter — Phase 4 dogfood wiring for the verisim-modular-experiment.

## Architecture

This file provides two layers:

1. **Abstract interface** (`AbstractVerisimCore`, the four stub methods):
   Framework code can program against these without depending on any
   concrete VerisimCore implementation.  The stubs remain for users who
   supply their own concrete core (e.g. a production VeriSimDB client).

2. **`LocalVerisimCore`** — concrete type backed by the Julia research
   prototype from `nextgen-databases/verisim-modular-experiment/`.
   Wraps a `Verisim.Store` + `Verisim.Manager` (Core = {Semantic,
   Temporal, Provenance}, as resolved in Phase 1).

## Phase 4 result (2026-04-12)

KRLAdapter.jl is a clean Core-only client.  The full TangleIR lifecycle
(create, rewrite, verify identity, attest, prove integrity + freshness,
consonance via tropical Bellman-Ford) works with an EMPTY federation
manager.  No Vector/Tensor/Spatial/Document/Graph shapes required.

See `docs/sessions/2026-04-05-krladapter-phase4-prep.adoc` in the
experiment repo for the Phase 4 prep notes and hypothesis.

## Prerequisite for `LocalVerisimCore`

The `Verisim` package must be loaded before constructing a
`LocalVerisimCore`:

    using Verisim            # loads VerisimCore, VCLProver etc. into Main
    core = LocalVerisimCore()

## Proof_bytes encoding

`_ir_to_proof_bytes` produces bytes compatible with TangleGraph's
`dt_codes_from_blob` reader:

    name (UTF-8) | 0x00 | Int64(n_dt) | Int64(c₁)…Int64(cₙ) | 0x00 | source_text

DT codes are read from `ir.metadata.extra[:dt_code]` (Vector{Int}) when
present; otherwise the field is empty and consonance checking will return
VerdictFail (acceptable — identity/provenance still work).
"""

using UUIDs

export AbstractVerisimCore, VerisimCoreNotWiredError
export store_ir_verisim!, fetch_ir_verisim, query_ir_verisim, prove_consonance
export ConsonanceVerdict
export LocalVerisimCore

# -----------------------------------------------------------------------
# Abstract interface
# -----------------------------------------------------------------------

"""
    AbstractVerisimCore

Marker supertype for concrete VerisimCore implementations.
Subtype this to supply your own core; or use `LocalVerisimCore` for the
research prototype from `nextgen-databases/verisim-modular-experiment`.
"""
abstract type AbstractVerisimCore end

"""
    VerisimCoreNotWiredError

Thrown by stub methods when no concrete `AbstractVerisimCore` method
is defined for the given type.  Includes a pointer to the experiment docs
and to `LocalVerisimCore`.
"""
struct VerisimCoreNotWiredError <: Exception
    method_name::String
end

function Base.showerror(io::IO, e::VerisimCoreNotWiredError)
    print(io, "VerisimCoreNotWiredError: $(e.method_name) called on a type ",
          "that has not overridden this method.\n\n")
    print(io, "To wire up, either:\n")
    print(io, "  1. Use LocalVerisimCore (requires `using Verisim` first), OR\n")
    print(io, "  2. Subtype AbstractVerisimCore and define the 4 methods.\n\n")
    print(io, "See: nextgen-databases/verisim-modular-experiment/ for experiment status.")
end

"""
    ConsonanceVerdict

Result of a `prove_consonance` call.

# Fields
- `consonant::Bool`: whether the two IRs are treated as consonant under VCL
- `witness::Union{String,Nothing}`: evidence or proof-sketch (core provides one on pass)
- `reason::String`: human-readable rationale
"""
struct ConsonanceVerdict
    consonant::Bool
    witness::Union{String,Nothing}
    reason::String
end

# -----------------------------------------------------------------------
# Stub methods — override for a concrete core type
# -----------------------------------------------------------------------

"""
    store_ir_verisim!(core::AbstractVerisimCore, ir::TangleIR;
                      name=nothing, tags=String[]) -> UUID

Persist a `TangleIR` to VerisimCore's identity + provenance layer.

## Expected semantics (Phase 4 confirmed)
- **Identity**: `ir.id` (UUID) maps to a VerisimCore OctadId.
- **Semantic**: type-URIs encode provenance + tags; proof_bytes encode
  tangle name, DT code (from `ir.metadata.extra[:dt_code]`), and source.
- **Temporal**: core assigns and records the insertion timestamp.
- **Provenance**: core builds a signed hash-chain entry for the actor.
- **Tags** (optional): merged into type-URIs for the Semantic shape.

Returns `ir.id` on success.

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Overridden by `LocalVerisimCore`.
"""
function store_ir_verisim!(::AbstractVerisimCore, ::TangleIR;
        name::Union{String,Nothing} = nothing,
        tags::Vector{String} = String[])
    throw(VerisimCoreNotWiredError("store_ir_verisim!"))
end

"""
    fetch_ir_verisim(core::AbstractVerisimCore, id::UUID) -> Union{TangleIR,Nothing}

Retrieve a previously-stored `TangleIR` by UUID.

Reconstructed TangleIR fields:
- `id` — preserved exactly.
- `metadata.provenance` — recovered from Semantic type-URIs.
- `metadata.tags` — recovered from Semantic type-URIs.
- `metadata.name` — recovered from proof_bytes name field.
- `metadata.source_text` — recovered from proof_bytes source field.
- `crossings` — empty (structural round-trip requires KnotTheory adapter).
- `metadata.extra[:dt_code]` — restored if DT code was stored.
- `ports_in`, `ports_out`, `components` — empty (not stored).

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Overridden by `LocalVerisimCore`.
"""
function fetch_ir_verisim(::AbstractVerisimCore, ::UUID)
    throw(VerisimCoreNotWiredError("fetch_ir_verisim"))
end

"""
    query_ir_verisim(core::AbstractVerisimCore; predicates...) -> Vector{UUID}

Query VerisimCore for IRs matching the given keyword predicates.

Supported predicates:
- `provenance::Symbol` — match `ir.metadata.provenance`
- `tags::Vector{String}` — all specified tags must be present
- `crossing_count::Int` — exact number of crossings (from type-URI)
- `name_prefix::String` — `ir.metadata.name` starts with this string
- `actor::String` — at least one provenance entry has this actor

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Overridden by `LocalVerisimCore`.
"""
function query_ir_verisim(::AbstractVerisimCore; kwargs...)
    throw(VerisimCoreNotWiredError("query_ir_verisim"))
end

"""
    prove_consonance(core::AbstractVerisimCore, ir1::TangleIR, ir2::TangleIR)
        -> ConsonanceVerdict

Ask VerisimCore whether two IRs are consonant under VCL semantics.

Both IRs must have been stored via `store_ir_verisim!` first.  Consonance
uses the tropical Bellman-Ford Reidemeister-move path search in
`VCLProver.prove(ProofConsonance(...))`.  Requires DT codes in
`ir.metadata.extra[:dt_code]` for non-trivial results.

## Stub behaviour
Throws `VerisimCoreNotWiredError`. Overridden by `LocalVerisimCore`.
"""
function prove_consonance(::AbstractVerisimCore, ::TangleIR, ::TangleIR)
    throw(VerisimCoreNotWiredError("prove_consonance"))
end

# -----------------------------------------------------------------------
# LocalVerisimCore — concrete implementation backed by Verisim package
# -----------------------------------------------------------------------

"""
    LocalVerisimCore

Concrete `AbstractVerisimCore` backed by the Julia reference implementation
in `nextgen-databases/verisim-modular-experiment/`.

Prerequisite: `using Verisim` must be evaluated before constructing.

# Fields (internal — do not access directly)
- `store` — `Main.VerisimCore.Store` (duck-typed; loaded by Verisim.__init__)
- `manager` — `Main.FederationManager.Manager` (no peers; Core-only operation)
"""
mutable struct LocalVerisimCore <: AbstractVerisimCore
    store::Any     # Main.VerisimCore.Store
    manager::Any   # Main.FederationManager.Manager
end

"""
    LocalVerisimCore()

Construct a fresh `LocalVerisimCore` with an empty in-memory store.

Requires `using Verisim` to have been evaluated first.  Throws an
informative error if the Verisim package has not been loaded.
"""
function LocalVerisimCore()
    isdefined(Main, :VerisimCore) || error(
        "LocalVerisimCore requires the Verisim package to be loaded first.\n" *
        "Add `using Verisim` before constructing a LocalVerisimCore.\n" *
        "Verisim lives at: nextgen-databases/verisim-modular-experiment/")
    LocalVerisimCore(Main.VerisimCore.Store(), Main.FederationManager.Manager())
end

# -----------------------------------------------------------------------
# Bridge helpers: UUID <-> OctadId
# -----------------------------------------------------------------------

"""
    _uuid_to_octad_id(id::UUID) -> OctadId

Map a KRLAdapter UUID (128-bit) to a VerisimCore OctadId (16 bytes).
Deterministic: UUID.value (UInt128) reinterpreted as little-endian bytes.
"""
function _uuid_to_octad_id(id::UUID)
    bytes = collect(reinterpret(UInt8, [id.value]))
    Main.VerisimCore.OctadId(bytes)
end

"""
    _octad_id_to_uuid(oid) -> UUID

Reverse of `_uuid_to_octad_id`.  Reconstructs a UUID from 16 OctadId bytes.
"""
function _octad_id_to_uuid(oid)
    val = reinterpret(UInt128, oid.bytes)[1]
    UUID(val)
end

# -----------------------------------------------------------------------
# Bridge helpers: TangleIR <-> SemanticBlob
# -----------------------------------------------------------------------

"""
    _ir_to_proof_bytes(ir::TangleIR) -> Vector{UInt8}

Encode a TangleIR's tangle structure into the proof_bytes format that
`TangleGraph.dt_codes_from_blob` (VCLProver's consonance decoder) reads:

    name (UTF-8) | 0x00 | Int64(n_dt) | Int64(c₁)…Int64(cₙ) | 0x00 | source_text

DT code is read from `ir.metadata.extra[:dt_code]` (Vector{Int}) when
present; otherwise n_dt = 0.
"""
function _ir_to_proof_bytes(ir::TangleIR)::Vector{UInt8}
    name   = something(ir.metadata.name, string(ir.id))
    dt     = get(ir.metadata.extra, :dt_code, Int[])
    source = something(ir.metadata.source_text, "")

    bytes = UInt8[]
    append!(bytes, collect(codeunits(name)))
    push!(bytes, 0x00)
    append!(bytes, reinterpret(UInt8, [Int64(length(dt))]))
    for c in dt
        append!(bytes, reinterpret(UInt8, [Int64(c)]))
    end
    push!(bytes, 0x00)
    append!(bytes, collect(codeunits(source)))
    bytes
end

"""
    _ir_to_semantic_blob(ir::TangleIR, extra_tags::Vector{String}) -> SemanticBlob

Build a VerisimCore SemanticBlob from a TangleIR.

type_uris encode:
- `"http://krl.hyperpolymath.org/#TangleIR"` — identity tag
- `"http://krl.hyperpolymath.org/#provenance/{prov}"` — provenance symbol
- `"http://krl.hyperpolymath.org/#crossings/{n}"` — crossing count (for query)
- `"http://krl.hyperpolymath.org/#tag/{t}"` — per metadata tag + extra_tags

proof_bytes follow the `dt_codes_from_blob`-compatible format.
"""
function _ir_to_semantic_blob(ir::TangleIR, extra_tags::Vector{String})
    type_uris = String[
        "http://krl.hyperpolymath.org/#TangleIR",
        "http://krl.hyperpolymath.org/#provenance/$(ir.metadata.provenance)",
        "http://krl.hyperpolymath.org/#crossings/$(length(ir.crossings))",
    ]
    for t in vcat(ir.metadata.tags, extra_tags)
        push!(type_uris, "http://krl.hyperpolymath.org/#tag/$(t)")
    end
    Main.VerisimCore.SemanticBlob(type_uris, _ir_to_proof_bytes(ir))
end

"""
    _name_from_proof_bytes(bytes::Vector{UInt8}) -> String

Extract the name field from proof_bytes (everything before the first
null byte).  Returns an empty string on failure.
"""
function _name_from_proof_bytes(bytes::Vector{UInt8})::String
    nul = findfirst(==(0x00), bytes)
    nul === nothing ? "" : String(bytes[1:nul-1])
end

"""
    _source_from_proof_bytes(bytes::Vector{UInt8}) -> String

Extract the source_text field from proof_bytes (after the DT-code block
and the second null byte).  Returns an empty string on failure.
"""
function _source_from_proof_bytes(bytes::Vector{UInt8})::String
    nul1 = findfirst(==(0x00), bytes)
    nul1 === nothing && return ""
    pos = nul1 + 1
    pos + 7 > length(bytes) && return ""
    n = Int(reinterpret(Int64, bytes[pos:pos+7])[1])
    pos += 8 + n * 8 + 1  # skip count + n values + second null
    pos > length(bytes) && return ""
    String(bytes[pos:end])
end

"""
    _type_uris_to_provenance(type_uris) -> Symbol

Recover provenance symbol from SemanticBlob type_uris.
Returns `:unknown` if not present.
"""
function _type_uris_to_provenance(type_uris::Vector{String})::Symbol
    prefix = "http://krl.hyperpolymath.org/#provenance/"
    for u in type_uris
        startswith(u, prefix) && return Symbol(u[length(prefix)+1:end])
    end
    :unknown
end

"""
    _type_uris_to_tags(type_uris) -> Vector{String}

Extract the `#tag/{t}` values from SemanticBlob type_uris.
"""
function _type_uris_to_tags(type_uris::Vector{String})::Vector{String}
    prefix = "http://krl.hyperpolymath.org/#tag/"
    [u[length(prefix)+1:end] for u in type_uris if startswith(u, prefix)]
end

"""
    _type_uris_to_crossing_count(type_uris) -> Union{Int,Nothing}

Extract the `#crossings/{n}` value from SemanticBlob type_uris.
"""
function _type_uris_to_crossing_count(type_uris::Vector{String})::Union{Int,Nothing}
    prefix = "http://krl.hyperpolymath.org/#crossings/"
    for u in type_uris
        startswith(u, prefix) && return tryparse(Int, u[length(prefix)+1:end])
    end
    nothing
end

"""
    _is_krl_octad(type_uris) -> Bool

Return true iff the type_uris carry the KRL TangleIR identity tag.
Used by `query_ir_verisim` to filter non-KRL octads.
"""
function _is_krl_octad(type_uris::Vector{String})::Bool
    "http://krl.hyperpolymath.org/#TangleIR" in type_uris
end

"""
    _octad_to_ir(oid, octad) -> Union{TangleIR, Nothing}

Reconstruct a TangleIR from a CoreOctad.

Recovered fields:
- `id` — from OctadId bytes (reversed from `_uuid_to_octad_id`)
- `metadata.provenance` — from Semantic type-URIs
- `metadata.tags` — from Semantic type-URIs
- `metadata.name` — from proof_bytes name field
- `metadata.source_text` — from proof_bytes source field
- `metadata.extra[:dt_code]` — DT code from proof_bytes if non-empty
- `metadata.extra[:provenance_chain_length]` — number of enrichment events
- `crossings`, `ports_in`, `ports_out`, `components` — empty
  (structural data is not stored; use KnotTheory adapter for round-trips)

Returns `nothing` if the octad does not carry a KRL TangleIR semantic blob.
"""
function _octad_to_ir(oid, octad)::Union{TangleIR, Nothing}
    octad.semantic === nothing && return nothing
    _is_krl_octad(octad.semantic.type_uris) || return nothing

    id_val = reinterpret(UInt128, oid.bytes)[1]
    id     = UUID(id_val)

    provenance = _type_uris_to_provenance(octad.semantic.type_uris)
    tags       = _type_uris_to_tags(octad.semantic.type_uris)
    name_str   = _name_from_proof_bytes(octad.semantic.proof_bytes)
    source_str = _source_from_proof_bytes(octad.semantic.proof_bytes)
    dt_raw     = Main.TangleGraph.dt_codes_from_blob(octad.semantic.proof_bytes)

    chain_len = octad.provenance === nothing ? 0 :
                length(octad.provenance.entries)

    extra = Dict{Symbol,Any}(:provenance_chain_length => chain_len)
    isempty(dt_raw) || (extra[:dt_code] = dt_raw)

    meta = TangleMetadata(
        isempty(name_str) ? nothing : name_str,
        isempty(source_str) ? nothing : source_str,
        tags,
        provenance,
        extra,
    )
    TangleIR(id, Port[], Port[], CrossingIR[], Vector{Int}[], meta)
end

# -----------------------------------------------------------------------
# LocalVerisimCore method implementations
# -----------------------------------------------------------------------

"""
    store_ir_verisim!(core::LocalVerisimCore, ir::TangleIR;
                      name=nothing, tags=String[]) -> UUID

Store a TangleIR in the Core.  If `name` is supplied and differs from
`ir.metadata.name`, the override name is used in proof_bytes and
type-URIs.  Returns `ir.id`.

The actor for the provenance chain entry is the string representation of
`ir.metadata.provenance` (e.g. `"user"`, `"rewritten"`, `"derived"`).
"""
function store_ir_verisim!(core::LocalVerisimCore, ir::TangleIR;
        name::Union{String,Nothing} = nothing,
        tags::Vector{String} = String[])::UUID
    # Apply name override by constructing a patched IR if needed.
    effective_ir = if name !== nothing && name != ir.metadata.name
        new_meta = TangleMetadata(
            name,
            ir.metadata.source_text,
            ir.metadata.tags,
            ir.metadata.provenance,
            ir.metadata.extra,
        )
        TangleIR(ir.id, ir.ports_in, ir.ports_out,
                 ir.crossings, ir.components, new_meta)
    else
        ir
    end

    oid   = _uuid_to_octad_id(effective_ir.id)
    blob  = _ir_to_semantic_blob(effective_ir, tags)
    actor = string(effective_ir.metadata.provenance)

    Main.VerisimCore.enrich!(core.store, oid, :semantic, blob, actor)
    effective_ir.id
end

"""
    fetch_ir_verisim(core::LocalVerisimCore, id::UUID) -> Union{TangleIR,Nothing}

Retrieve a stored TangleIR by UUID.  Returns `nothing` if not found.
See `_octad_to_ir` for which fields are recovered.
"""
function fetch_ir_verisim(core::LocalVerisimCore, id::UUID)::Union{TangleIR,Nothing}
    oid   = _uuid_to_octad_id(id)
    octad = Main.VerisimCore.get_core(core.store, oid)
    octad === nothing && return nothing
    _octad_to_ir(oid, octad)
end

"""
    query_ir_verisim(core::LocalVerisimCore; predicates...) -> Vector{UUID}

Scan all stored KRL TangleIR octads and return UUIDs matching every
supplied predicate.

Supported predicates:
- `provenance::Symbol` — exact match on provenance symbol
- `tags::Vector{String}` — all listed tags must be present
- `crossing_count::Int` — exact crossing count
- `name_prefix::String` — stored name starts with this string
- `actor::String` — at least one provenance chain entry has this actor
"""
function query_ir_verisim(core::LocalVerisimCore; kwargs...)::Vector{UUID}
    results = UUID[]

    for (oid, octad) in core.store.octads
        octad.semantic === nothing && continue
        _is_krl_octad(octad.semantic.type_uris) || continue

        match = true

        if haskey(kwargs, :provenance)
            want = kwargs[:provenance]::Symbol
            _type_uris_to_provenance(octad.semantic.type_uris) == want ||
                (match = false)
        end

        if match && haskey(kwargs, :tags)
            want_tags = kwargs[:tags]::Vector{String}
            present   = _type_uris_to_tags(octad.semantic.type_uris)
            all(t -> t in present, want_tags) || (match = false)
        end

        if match && haskey(kwargs, :crossing_count)
            want_n = kwargs[:crossing_count]::Int
            n = _type_uris_to_crossing_count(octad.semantic.type_uris)
            (n !== nothing && n == want_n) || (match = false)
        end

        if match && haskey(kwargs, :name_prefix)
            pfx  = kwargs[:name_prefix]::String
            name = _name_from_proof_bytes(octad.semantic.proof_bytes)
            startswith(name, pfx) || (match = false)
        end

        if match && haskey(kwargs, :actor) && octad.provenance !== nothing
            want_actor = kwargs[:actor]::String
            any(e -> e.actor == want_actor, octad.provenance.entries) ||
                (match = false)
        end

        match && push!(results, _octad_id_to_uuid(oid))
    end

    results
end

"""
    prove_consonance(core::LocalVerisimCore, ir1::TangleIR, ir2::TangleIR)
        -> ConsonanceVerdict

Assert VCL consonance between two TangleIRs.  Both IRs must have been
stored via `store_ir_verisim!` first (otherwise returns
ConsonanceVerdict(false, nothing, "octad not found ...")).

Delegates to `VCLProver.prove(ProofConsonance(id1, id2), store, manager)`
which uses tropical Bellman-Ford Reidemeister-move path search
(formally backed by Tropical_Matrices_Full.thy::bellman_ford).

Returns a witness string on pass.  Requires DT codes in
`ir.metadata.extra[:dt_code]` for non-trivial (non-identical) comparisons.
"""
function prove_consonance(core::LocalVerisimCore,
                          ir1::TangleIR,
                          ir2::TangleIR)::ConsonanceVerdict
    oid1   = _uuid_to_octad_id(ir1.id)
    oid2   = _uuid_to_octad_id(ir2.id)
    clause = Main.VCLQuery.ProofConsonance(oid1, oid2)
    result = try
        Main.VCLProver.prove(clause, core.store, core.manager)
    catch e
        # Degrade gracefully if the prover throws (e.g. KnotTheory unavailable
        # in Main when running outside the Verisim project context).
        return ConsonanceVerdict(false, nothing,
            "prove_consonance: prover threw $(typeof(e)): $(e)")
    end

    if result isa Main.VCLQuery.VerdictPass
        ConsonanceVerdict(true, result.witness, result.witness)
    else
        ConsonanceVerdict(false, nothing, result.reason)
    end
end
