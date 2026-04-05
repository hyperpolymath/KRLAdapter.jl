# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
TangleIR operations: compositional builders (compose, tensor, close_tangle, mirror).

These operate purely on TangleIR — they do not depend on KnotTheory.jl or Skein.jl.
"""

export compose, tensor, close_tangle, mirror

"""
    _renumber_arcs(crossings::Vector{CrossingIR}, offset::Int) -> Vector{CrossingIR}

Shift every arc index in the crossings by `offset` and prefix crossing ids with
`offset`-awareness so composed IRs don't clash.
"""
function _renumber_arcs(crossings::Vector{CrossingIR}, arc_offset::Int, id_suffix::String)
    [CrossingIR(
        Symbol(string(c.id) * id_suffix),
        c.sign,
        (c.arcs[1] + arc_offset, c.arcs[2] + arc_offset,
         c.arcs[3] + arc_offset, c.arcs[4] + arc_offset),
    ) for c in crossings]
end

"""
    compose(a::TangleIR, b::TangleIR) -> TangleIR

Sequential composition: glue the outgoing ports of `a` to the incoming ports of `b`.

Requires `length(a.ports_out) == length(b.ports_in)`. Arc indices in `b` are
shifted to follow `a`, and shared ports collapse to single arcs.

For closed diagrams (no ports), this is equivalent to disjoint union — use
`tensor` for that semantics explicitly.
"""
function compose(a::TangleIR, b::TangleIR)
    length(a.ports_out) == length(b.ports_in) ||
        throw(ArgumentError("compose: a.ports_out has $(length(a.ports_out)) ports, " *
                            "b.ports_in has $(length(b.ports_in))"))

    max_arc_a = isempty(a.crossings) ? 0 :
        maximum(maximum(c.arcs) for c in a.crossings)
    b_crossings = _renumber_arcs(b.crossings, max_arc_a, "_b")
    a_crossings = [CrossingIR(Symbol(string(c.id) * "_a"), c.sign, c.arcs) for c in a.crossings]

    TangleIR(
        vcat(a_crossings, b_crossings);
        ports_in = a.ports_in,
        ports_out = b.ports_out,
        metadata = TangleMetadata(provenance = :derived,
                                  extra = Dict{Symbol,Any}(:operation => :compose)),
    )
end

"""
    tensor(a::TangleIR, b::TangleIR) -> TangleIR

Tensor (juxtaposition) product: place `a` and `b` side by side. Arc indices
in `b` are shifted to avoid collision with `a`.
"""
function tensor(a::TangleIR, b::TangleIR)
    max_arc_a = isempty(a.crossings) ? 0 :
        maximum(maximum(c.arcs) for c in a.crossings)
    b_crossings = _renumber_arcs(b.crossings, max_arc_a, "_t2")
    a_crossings = [CrossingIR(Symbol(string(c.id) * "_t1"), c.sign, c.arcs) for c in a.crossings]

    # Shift b's port indices to follow a's on each side
    a_top = count(p -> p.side === :top, a.ports_in) + count(p -> p.side === :top, a.ports_out)
    shifted_b_in = [Port(p.id, p.side, p.index + a_top, p.orientation) for p in b.ports_in]
    shifted_b_out = [Port(p.id, p.side, p.index + a_top, p.orientation) for p in b.ports_out]

    TangleIR(
        vcat(a_crossings, b_crossings);
        ports_in = vcat(a.ports_in, shifted_b_in),
        ports_out = vcat(a.ports_out, shifted_b_out),
        metadata = TangleMetadata(provenance = :derived,
                                  extra = Dict{Symbol,Any}(:operation => :tensor)),
    )
end

"""
    close_tangle(a::TangleIR) -> TangleIR

Closure (trace): connect every outgoing port of `a` to the corresponding
incoming port, yielding a closed diagram with no ports.

Requires `length(a.ports_in) == length(a.ports_out)`.
"""
function close_tangle(a::TangleIR)
    length(a.ports_in) == length(a.ports_out) ||
        throw(ArgumentError("close_tangle: ports_in has $(length(a.ports_in)) ports, " *
                            "ports_out has $(length(a.ports_out))"))

    TangleIR(
        a.crossings;
        ports_in = Port[],
        ports_out = Port[],
        components = a.components,
        metadata = TangleMetadata(provenance = :derived,
                                  extra = Dict{Symbol,Any}(:operation => :close)),
    )
end

"""
    mirror(a::TangleIR) -> TangleIR

Mirror reflection: flip the sign of every crossing.
"""
function mirror(a::TangleIR)
    flipped = [CrossingIR(c.id, -c.sign, c.arcs) for c in a.crossings]
    TangleIR(
        flipped;
        ports_in = a.ports_in,
        ports_out = a.ports_out,
        components = a.components,
        metadata = TangleMetadata(provenance = :derived,
                                  extra = Dict{Symbol,Any}(:operation => :mirror)),
    )
end
