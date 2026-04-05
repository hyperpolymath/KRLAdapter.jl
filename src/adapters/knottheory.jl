# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
KnotTheory.jl adapter — thin wrappers converting TangleIR ↔ PlanarDiagram
and invoking invariant computation in the community KnotTheory library.

KnotTheory.jl is NEVER modified from this package. All KRL-specific logic
lives here.
"""

import KnotTheory
const KT = KnotTheory

export pd_to_ir, ir_to_pd
export alexander, jones, simplify
export trefoil_ir, figure_eight_ir, unknot_ir

"""
    pd_to_ir(pd::KnotTheory.PlanarDiagram; name=nothing, provenance=:imported) -> TangleIR

Convert a KnotTheory `PlanarDiagram` into a `TangleIR`. Crossings are assigned
symbolic ids (`:c1`, `:c2`, …). The IR represents a closed diagram (no ports).
"""
function pd_to_ir(pd::KT.PlanarDiagram;
        name::Union{String,Nothing} = nothing,
        provenance::Symbol = :imported)
    crossings = [
        CrossingIR(Symbol("c", i), c.sign, c.arcs)
        for (i, c) in enumerate(pd.crossings)
    ]
    TangleIR(
        crossings;
        components = copy(pd.components),
        metadata = TangleMetadata(
            name = name,
            provenance = provenance,
            extra = Dict{Symbol,Any}(:source => :knottheory_pd),
        ),
    )
end

"""
    ir_to_pd(ir::TangleIR) -> KnotTheory.PlanarDiagram

Convert a `TangleIR` into a KnotTheory `PlanarDiagram` for invariant
computation. Requires the IR to be closed (no boundary ports).
"""
function ir_to_pd(ir::TangleIR)
    is_closed(ir) || throw(ArgumentError(
        "ir_to_pd: open tangles (with ports) cannot be converted to PlanarDiagram"))
    kt_crossings = [KT.Crossing(c.arcs, c.sign) for c in ir.crossings]
    KT.PlanarDiagram(kt_crossings, copy(ir.components))
end

"""
    alexander(ir::TangleIR)

Compute the Alexander polynomial of the IR via KnotTheory.jl.
"""
alexander(ir::TangleIR) = KT.alexander_polynomial(ir_to_pd(ir))

"""
    jones(ir::TangleIR)

Compute the Jones polynomial of the IR via KnotTheory.jl.
"""
jones(ir::TangleIR) = KT.jones_polynomial(ir_to_pd(ir))

"""
    determinant(ir::TangleIR) -> Int

Compute the knot determinant via KnotTheory.jl.
"""
determinant(ir::TangleIR) = KT.determinant(ir_to_pd(ir))

"""
    signature(ir::TangleIR) -> Int

Compute the knot signature via KnotTheory.jl.
"""
signature(ir::TangleIR) = KT.signature(ir_to_pd(ir))

"""
    simplify(ir::TangleIR) -> TangleIR

Apply KnotTheory's Reidemeister simplifications (`simplify_pd`), returning a
fresh TangleIR tagged with `:rewritten` provenance.
"""
function simplify(ir::TangleIR)
    pd = ir_to_pd(ir)
    simplified = KT.simplify_pd(pd)
    new_ir = pd_to_ir(simplified;
                      name = ir.metadata.name,
                      provenance = :rewritten)
    # Preserve original source_text if present
    TangleIR(
        new_ir.id, new_ir.ports_in, new_ir.ports_out,
        new_ir.crossings, new_ir.components,
        TangleMetadata(
            name = ir.metadata.name,
            source_text = ir.metadata.source_text,
            tags = ir.metadata.tags,
            provenance = :rewritten,
            extra = Dict{Symbol,Any}(
                :source => :knottheory_pd,
                :parent_id => ir.id,
                :operation => :simplify,
            ),
        ),
    )
end

export determinant, signature

# -- Convenience constructors from KnotTheory's built-in knot table --

"""
    trefoil_ir() -> TangleIR

Build a TangleIR for the trefoil knot using KnotTheory's canonical definition.
"""
trefoil_ir() = pd_to_ir(KT.trefoil().pd; name = "trefoil", provenance = :imported)

"""
    figure_eight_ir() -> TangleIR

Build a TangleIR for the figure-eight knot.
"""
figure_eight_ir() = pd_to_ir(KT.figure_eight().pd; name = "figure_eight", provenance = :imported)

"""
    unknot_ir() -> TangleIR

Build a TangleIR for the unknot (empty crossings).
"""
function unknot_ir()
    u = KT.unknot()
    if u.pd === nothing
        TangleIR(CrossingIR[]; metadata = TangleMetadata(name = "unknot", provenance = :imported))
    else
        pd_to_ir(u.pd; name = "unknot", provenance = :imported)
    end
end
