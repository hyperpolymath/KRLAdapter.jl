# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency with
#  sibling community libs KnotTheory.jl and Skein.jl)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
KRLAdapter.jl

Adapter package for the KRL (Knot Resolution Language) stack. Defines TangleIR
and wraps the community Julia libraries `KnotTheory.jl` and `Skein.jl` without
modifying them.

Architecture:

    KRL surface language (pronounced "curl")
        ↓ compiled by TanglePL module
    TangleIR (defined in THIS package)
        ↓ via adapters in THIS package
    KnotTheory.jl (community library, untouched)  → invariants, Reidemeister
    Skein.jl      (community library, untouched)  → persistence, indexing

KnotTheory.jl and Skein.jl remain pure community libraries publishable to
JuliaHub. All KRL-stack-specific concerns live here.
"""
module KRLAdapter

include("ir.jl")
include("operations.jl")
include("adapters/knottheory.jl")
include("adapters/skein.jl")
include("adapters/tangle.jl")
include("adapters/verisim.jl")

# KRL surface language parser (v0.2 — Julia implementation, Option B)
include("parser/lexer.jl")
include("parser/ast.jl")
include("parser/parser.jl")
include("parser/lower.jl")

end # module
