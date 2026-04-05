# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 used for Julia ecosystem consistency with
#  sibling community libs KnotTheory.jl and Skein.jl)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
TangleIR — the canonical interchange representation for the KRL stack.

TangleIR is defined *here* in KRLAdapter.jl, not in the community libraries
KnotTheory.jl or Skein.jl. It is the spine object that flows between the
surface language (KRL / TanglePL), the invariant engine (KnotTheory.jl),
the persistence layer (Skein.jl), and semantic fingerprint layers (QuandleDB).
"""

using UUIDs
using Dates

export Port, CrossingIR, TangleMetadata, TangleIR

"""
    Port

A boundary port on an open tangle.

# Fields
- `id::Symbol`: stable identifier
- `side::Symbol`: one of `:top`, `:bottom`, `:left`, `:right`
- `index::Int`: ordinal position along the side
- `orientation::Symbol`: one of `:in`, `:out`, `:unknown`
"""
struct Port
    id::Symbol
    side::Symbol
    index::Int
    orientation::Symbol
end

"""
    CrossingIR

A single crossing in TangleIR. PD-style: four arcs meet at the crossing.

# Fields
- `id::Symbol`: stable identifier (e.g. `:c1`, `:c2`)
- `sign::Int`: `+1` (positive crossing) or `-1` (negative crossing)
- `arcs::NTuple{4,Int}`: the four arc indices meeting at this crossing
"""
struct CrossingIR
    id::Symbol
    sign::Int
    arcs::NTuple{4,Int}
end

"""
    TangleMetadata

Metadata attached to a TangleIR: provenance, naming, source text, tags.

Provenance values:
- `:user` — constructed directly by user input
- `:derived` — computed from another IR
- `:rewritten` — result of a rewrite/simplification
- `:imported` — imported from an external source (DT code, braid word, etc.)
"""
struct TangleMetadata
    name::Union{String,Nothing}
    source_text::Union{String,Nothing}
    tags::Vector{String}
    provenance::Symbol
    extra::Dict{Symbol,Any}
end

"""
    TangleMetadata(; name=nothing, source_text=nothing, tags=String[], provenance=:user, extra=Dict{Symbol,Any}())

Convenience constructor with keyword arguments.
"""
function TangleMetadata(;
        name::Union{String,Nothing} = nothing,
        source_text::Union{String,Nothing} = nothing,
        tags::Vector{String} = String[],
        provenance::Symbol = :user,
        extra::Dict{Symbol,Any} = Dict{Symbol,Any}())
    TangleMetadata(name, source_text, tags, provenance, extra)
end

"""
    TangleIR

The canonical IR for tangles, knots, and links in the KRL stack.

# Fields
- `id::UUID`: unique identifier
- `ports_in::Vector{Port}`: incoming boundary ports (empty for closed diagrams)
- `ports_out::Vector{Port}`: outgoing boundary ports (empty for closed diagrams)
- `crossings::Vector{CrossingIR}`: all crossings in the diagram
- `components::Vector{Vector{Int}}`: arc index groups per link component
- `metadata::TangleMetadata`: provenance and naming
"""
struct TangleIR
    id::UUID
    ports_in::Vector{Port}
    ports_out::Vector{Port}
    crossings::Vector{CrossingIR}
    components::Vector{Vector{Int}}
    metadata::TangleMetadata
end

"""
    TangleIR(crossings::Vector{CrossingIR}; ports_in=Port[], ports_out=Port[], components=Vector{Int}[], metadata=TangleMetadata())

Convenience constructor. Generates a fresh UUID.
"""
function TangleIR(crossings::Vector{CrossingIR};
        ports_in::Vector{Port} = Port[],
        ports_out::Vector{Port} = Port[],
        components::Vector{Vector{Int}} = Vector{Int}[],
        metadata::TangleMetadata = TangleMetadata())
    TangleIR(uuid4(), ports_in, ports_out, crossings, components, metadata)
end

"""
    is_closed(ir::TangleIR) -> Bool

Return `true` if the IR represents a closed diagram (no boundary ports).
"""
is_closed(ir::TangleIR) = isempty(ir.ports_in) && isempty(ir.ports_out)

"""
    crossing_count(ir::TangleIR) -> Int

Return the number of crossings in the IR.
"""
crossing_count(ir::TangleIR) = length(ir.crossings)

"""
    writhe(ir::TangleIR) -> Int

Sum of crossing signs (structural writhe over the IR).
"""
writhe(ir::TangleIR) = sum(c.sign for c in ir.crossings; init = 0)

export is_closed, crossing_count, writhe
