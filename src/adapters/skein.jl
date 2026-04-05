# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
Skein.jl adapter — thin wrappers persisting TangleIR via the community
Skein library. Skein.jl is NEVER modified from this package.

TangleIR is converted to a KnotTheory `PlanarDiagram` (via the KnotTheory
adapter) then stored using Skein's PD-first path provided by its
`KnotTheoryExt` Julia package extension.
"""

import Skein
import KnotTheory

const SK = Skein
const KT = KnotTheory

export store_ir!, fetch_ir, query_ir

"""
    store_ir!(db::Skein.SkeinDB, ir::TangleIR; name=nothing, tags=String[]) -> String

Persist a `TangleIR` in Skein. Returns the Skein record id.

- If `name` is not supplied, uses the IR's metadata name; otherwise generates
  a name from the IR's UUID.
- The IR must be closed (no ports) for storage via the PlanarDiagram path.
- `tags` are attached as Skein metadata under keys `tag_0`, `tag_1`, …
"""
function store_ir!(db::SK.SkeinDB, ir::TangleIR;
        name::Union{String,Nothing} = nothing,
        tags::Vector{String} = String[])
    is_closed(ir) || throw(ArgumentError(
        "store_ir!: open tangles cannot be stored via Skein's PD-first path"))

    effective_name = if name !== nothing
        name
    elseif ir.metadata.name !== nothing
        ir.metadata.name
    else
        "tangle_ir_" * string(ir.id)[1:8]
    end

    metadata = Dict{String,String}(
        "krl_ir_uuid" => string(ir.id),
        "krl_provenance" => string(ir.metadata.provenance),
    )
    for (i, tag) in enumerate(tags)
        metadata["tag_$(i-1)"] = tag
    end
    if ir.metadata.source_text !== nothing
        metadata["krl_source_text"] = ir.metadata.source_text
    end

    pd = ir_to_pd(ir)
    SK.store!(db, effective_name, pd; metadata = metadata)
end

"""
    fetch_ir(db::Skein.SkeinDB, name::String) -> Union{TangleIR,Nothing}

Retrieve a stored diagram from Skein and reconstruct it as a `TangleIR`.
Returns `nothing` if no record with that name exists.
"""
function fetch_ir(db::SK.SkeinDB, name::String)
    record = SK.fetch_knot(db, name)
    record === nothing && return nothing
    pd = SK.to_planardiagram(record)
    pd === nothing && return nothing

    # Reconstruct UUID from metadata if present, otherwise fresh
    stored_uuid = get(record.metadata, "krl_ir_uuid", nothing)
    stored_provenance = get(record.metadata, "krl_provenance", "imported")
    stored_source = get(record.metadata, "krl_source_text", nothing)

    # Extract tags back from metadata
    tags = String[]
    i = 0
    while haskey(record.metadata, "tag_$i")
        push!(tags, record.metadata["tag_$i"])
        i += 1
    end

    crossings = [
        CrossingIR(Symbol("c", j), c.sign, c.arcs)
        for (j, c) in enumerate(pd.crossings)
    ]

    id = stored_uuid === nothing ? uuid4() : UUID(stored_uuid)
    provenance = Symbol(stored_provenance)

    TangleIR(
        id, Port[], Port[],
        crossings, copy(pd.components),
        TangleMetadata(
            name = record.name,
            source_text = stored_source,
            tags = tags,
            provenance = provenance,
            extra = Dict{Symbol,Any}(:source => :skein_fetch),
        ),
    )
end

"""
    query_ir(db::Skein.SkeinDB; crossing_number=nothing, writhe=nothing, determinant=nothing, signature=nothing) -> Vector{String}

Query the Skein store with filters; return the matching record names.
Filters map to Skein's indexed columns.
"""
function query_ir(db::SK.SkeinDB;
        crossing_number::Union{Int,Nothing} = nothing,
        writhe::Union{Int,Nothing} = nothing,
        determinant::Union{Int,Nothing} = nothing,
        signature::Union{Int,Nothing} = nothing)
    kwargs = Dict{Symbol,Any}()
    crossing_number === nothing || (kwargs[:crossing_number] = crossing_number)
    writhe === nothing || (kwargs[:writhe] = writhe)
    determinant === nothing || (kwargs[:determinant] = determinant)
    signature === nothing || (kwargs[:signature] = signature)
    records = SK.query(db; kwargs...)
    String[r.name for r in records]
end
