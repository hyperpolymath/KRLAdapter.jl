# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
Tangle compiler bridge — read the pdv1 text format produced by
`Compositional.pdv1_blob_of_pd` (OCaml, in tangle/compiler/lib/compositional.ml)
and reconstruct it as a `TangleIR`.

This is the adapter that lets KRL source text (written in Tangle) flow
through the Tangle compiler and arrive in KRLAdapter.jl's TangleIR shape
ready for invariant computation or Skein persistence.

Format: `pdv1|x=a,b,c,d,s;a,b,c,d,s;...|c=arc,arc;arc,arc;...`

- `x=` sections: crossings as 5-tuples of (arc1, arc2, arc3, arc4, sign).
- `c=` sections: components as groups of arc indices.
- Semicolons separate crossings and components; commas separate fields within.
"""

export pdv1_blob_to_ir, tangle_entries_to_ir

"""
    pdv1_blob_to_ir(blob::AbstractString; name=nothing, source_text=nothing) -> TangleIR

Parse a Tangle-emitted `pdv1|x=...|c=...` blob and construct a `TangleIR`.

# Arguments
- `blob::AbstractString`: the pdv1 text blob
- `name`: optional name to attach to the TangleIR metadata
- `source_text`: optional original Tangle source (stored in metadata.source_text)

# Throws
- `ArgumentError` if the blob doesn't start with "pdv1|"
- `ArgumentError` if a crossing entry doesn't have exactly 5 comma-separated fields
"""
function pdv1_blob_to_ir(blob::AbstractString;
        name::Union{String,Nothing} = nothing,
        source_text::Union{String,Nothing} = nothing)
    startswith(blob, "pdv1|") ||
        throw(ArgumentError("pdv1_blob_to_ir: expected blob to start with 'pdv1|', got: " *
                            first(blob, min(20, length(blob)))))

    sections = split(blob, '|')
    length(sections) >= 3 ||
        throw(ArgumentError("pdv1_blob_to_ir: expected 3 sections (pdv1, x=, c=), got $(length(sections))"))

    x_section = ""
    c_section = ""
    for s in sections[2:end]
        if startswith(s, "x=")
            x_section = String(s)[3:end]
        elseif startswith(s, "c=")
            c_section = String(s)[3:end]
        end
    end

    # Parse crossings
    crossings = CrossingIR[]
    if !isempty(x_section)
        for (i, crossing_str) in enumerate(split(x_section, ';'))
            isempty(crossing_str) && continue
            fields = split(crossing_str, ',')
            length(fields) == 5 ||
                throw(ArgumentError("pdv1_blob_to_ir: expected 5 fields in crossing '$crossing_str', got $(length(fields))"))
            try
                arcs = (parse(Int, fields[1]), parse(Int, fields[2]),
                        parse(Int, fields[3]), parse(Int, fields[4]))
                sign = parse(Int, fields[5])
                push!(crossings, CrossingIR(Symbol("c", i), sign, arcs))
            catch e
                throw(ArgumentError("pdv1_blob_to_ir: failed to parse crossing '$crossing_str': $e"))
            end
        end
    end

    # Parse components
    components = Vector{Int}[]
    if !isempty(c_section)
        for comp_str in split(c_section, ';')
            isempty(comp_str) && continue
            arcs = [parse(Int, s) for s in split(comp_str, ',') if !isempty(s)]
            push!(components, arcs)
        end
    end

    TangleIR(
        crossings;
        components = components,
        metadata = TangleMetadata(
            name = name,
            source_text = source_text,
            provenance = :imported,
            extra = Dict{Symbol,Any}(
                :source => :tangle_pdv1,
                :raw_blob => String(blob),
            ),
        ),
    )
end

"""
    tangle_entries_to_ir(entries::Vector{NTuple{5,Int}}, components=Vector{Int}[]; name=nothing, source_text=nothing) -> TangleIR

Construct a `TangleIR` from Tangle's `entries_of_pd` output — 5-tuples of
`(arc1, arc2, arc3, arc4, sign)` per crossing, plus optional component list.

This is the direct-programmatic entry point for anyone with Tangle's
OCaml-side 5-tuple representation in hand (e.g. through a FFI call).
"""
function tangle_entries_to_ir(entries::AbstractVector{<:NTuple{5,Int}},
        components::Vector{Vector{Int}} = Vector{Int}[];
        name::Union{String,Nothing} = nothing,
        source_text::Union{String,Nothing} = nothing)
    crossings = [
        CrossingIR(Symbol("c", i), entries[i][5],
                   (entries[i][1], entries[i][2], entries[i][3], entries[i][4]))
        for i in eachindex(entries)
    ]
    TangleIR(
        crossings;
        components = components,
        metadata = TangleMetadata(
            name = name,
            source_text = source_text,
            provenance = :imported,
            extra = Dict{Symbol,Any}(:source => :tangle_entries),
        ),
    )
end
