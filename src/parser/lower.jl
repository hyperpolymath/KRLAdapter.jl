# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
KRL AST → TangleIR lowering.

Converts a `KRLProgram` into a dictionary of named TangleIR values
(one per `let` binding) plus an ordered list of anonymous expression results.

Only the CONSTRUCT and TRANSFORM families are lowered to TangleIR.
RETRIEVE queries produce `KRLQueryPlan` values (passed directly to the
KRLAdapter query layer).

Lowering rules:

    KRLGenerator(:sigma, n)     → TangleIR with one positive crossing
    KRLGenerator(:sigma_inv, n) → TangleIR with one negative crossing
    KRLGenerator(:cup, n)       → TangleIR with one cup (two arcs, no crossing)
    KRLGenerator(:cap, n)       → TangleIR with one cap
    KRLCompose([a, b, ...])     → compose(a, b, ...) via operations.jl
    KRLTensor([a, b, ...])      → tensor(a, b, ...) via operations.jl
    KRLPrefixOp(:close, e)      → close_tangle(e)
    KRLPrefixOp(:mirror, e)     → mirror(e)
    KRLPrefixOp(:simplify, e)   → simplify_ir(e)    (Reidemeister on IR)
    KRLPrefixOp(:normalise, e)  → canonicalize_ir(e)
    KRLPrefixOp(:classify, e)   → e  (deferred to query layer)
    KRLIdentifier(name)         → look up in environment
    KRLParenExpr(e)             → lower(e)
    KRLQuery(...)               → KRLQueryPlan (passed through, not TangleIR)
"""

export lower_krl, KRLLowerError, KRLQueryPlan, KRLLoweredProgram

# ---------------------------------------------------------------------------
# Errors and result types
# ---------------------------------------------------------------------------

"""
    KRLLowerError(msg, line, col)

Thrown when the AST cannot be lowered to TangleIR (e.g. unbound identifier,
arity mismatch, non-integer index).
"""
struct KRLLowerError <: Exception
    msg::String
    line::Int
    col::Int
end

Base.showerror(io::IO, e::KRLLowerError) =
    print(io, "KRLLowerError at L$(e.line):C$(e.col): $(e.msg)")

"""
    KRLQueryPlan(filters)

Placeholder for a RETRIEVE query — passed through to the adapter query layer
without lowering to TangleIR.
"""
struct KRLQueryPlan
    filters::Vector{KRLNode}
end

"""
    KRLLoweredProgram

Result of lowering a `KRLProgram`.

# Fields
- `bindings::Dict{String,TangleIR}` — named TangleIR values (from `let`)
- `results::Vector{Any}` — anonymous expression values (TangleIR or KRLQueryPlan)
- `queries::Vector{KRLQueryPlan}` — all RETRIEVE queries, in order
"""
struct KRLLoweredProgram
    bindings::Dict{String,TangleIR}
    results::Vector{Any}
    queries::Vector{KRLQueryPlan}
end

# ---------------------------------------------------------------------------
# Environment (let-bindings)
# ---------------------------------------------------------------------------

const KRLEnv = Dict{String,TangleIR}

# ---------------------------------------------------------------------------
# Generator helpers
# ---------------------------------------------------------------------------

"""
    _sigma_ir(n, sign) -> TangleIR

Build a TangleIR for a single crossing on strands n and n+1.
Arc layout: (1,2,3,4), sign = +1 or -1.
"""
function _sigma_ir(n::Int, sign::Int)::TangleIR
    label = sign > 0 ? "sigma_$n" : "sigma_inv_$n"
    c = CrossingIR(Symbol(label), sign, (1, 2, 3, 4))
    ports_in  = [Port(Symbol("p_in_$i"),  :top,    i, :in)  for i in 1:2]
    ports_out = [Port(Symbol("p_out_$i"), :bottom, i, :out) for i in 1:2]
    TangleIR([c];
             ports_in  = ports_in,
             ports_out = ports_out,
             metadata  = TangleMetadata(
                 name        = label,
                 source_text = "$(sign > 0 ? "sigma" : "sigma_inv") $n",
                 provenance  = :user,
             ))
end

"""
    _cup_ir(n) -> TangleIR

Build a TangleIR for a cup (U-shaped arc, no crossings).
"""
function _cup_ir(n::Int)::TangleIR
    ports_in  = [Port(Symbol("cup_in_$i"),  :top, i, :in)  for i in 1:2]
    TangleIR(CrossingIR[];
             ports_in  = ports_in,
             ports_out = Port[],
             metadata  = TangleMetadata(
                 name        = "cup_$n",
                 source_text = "cup $n",
                 provenance  = :user,
             ))
end

"""
    _cap_ir(n) -> TangleIR

Build a TangleIR for a cap (Π-shaped arc, no crossings).
"""
function _cap_ir(n::Int)::TangleIR
    ports_out = [Port(Symbol("cap_out_$i"), :bottom, i, :out) for i in 1:2]
    TangleIR(CrossingIR[];
             ports_in  = Port[],
             ports_out = ports_out,
             metadata  = TangleMetadata(
                 name        = "cap_$n",
                 source_text = "cap $n",
                 provenance  = :user,
             ))
end

# ---------------------------------------------------------------------------
# IR-level Reidemeister simplification
# ---------------------------------------------------------------------------

"""
    simplify_ir(ir::TangleIR) -> TangleIR

Apply Reidemeister I and II simplification to the crossings of a TangleIR.
"""
function simplify_ir(ir::TangleIR)::TangleIR
    # R1: remove crossings where any arc index repeats
    r1_crossings = filter(c -> length(unique(c.arcs)) == 4, ir.crossings)
    ir_r1 = TangleIR(r1_crossings;
                     ports_in  = ir.ports_in,
                     ports_out = ir.ports_out,
                     metadata  = TangleMetadata(
                         name        = ir.metadata.name,
                         source_text = ir.metadata.source_text,
                         provenance  = :rewritten,
                     ))
    _simplify_r2_ir(ir_r1)
end

function _simplify_r2_ir(ir::TangleIR)::TangleIR
    crossings = collect(ir.crossings)
    changed = true
    while changed
        changed = false
        n = length(crossings)
        remove_i = 0
        remove_j = 0
        for i in 1:n
            found = false
            for j in (i+1):n
                ci, cj = crossings[i], crossings[j]
                ci.sign + cj.sign != 0 && continue
                shared = length(intersect(Set(ci.arcs), Set(cj.arcs)))
                shared == 2 || continue
                remove_i = i
                remove_j = j
                found = true
                break
            end
            found && break
        end
        if remove_i > 0
            # Remove indices remove_i and remove_j (higher index first)
            deleteat!(crossings, sort([remove_i, remove_j], rev=true))
            changed = true
        end
    end
    TangleIR(crossings;
             ports_in  = ir.ports_in,
             ports_out = ir.ports_out,
             metadata  = TangleMetadata(
                 name        = ir.metadata.name,
                 source_text = ir.metadata.source_text,
                 provenance  = :rewritten,
             ))
end

"""
    canonicalize_ir(ir::TangleIR) -> TangleIR

Normalise arc indices to a contiguous range starting at 1.
"""
function canonicalize_ir(ir::TangleIR)::TangleIR
    all_arcs = sort(unique(vcat([collect(c.arcs) for c in ir.crossings]...)))
    isempty(all_arcs) && return ir
    arc_map = Dict(a => i for (i, a) in enumerate(all_arcs))
    new_crossings = [
        CrossingIR(c.id, c.sign, (
            arc_map[c.arcs[1]], arc_map[c.arcs[2]],
            arc_map[c.arcs[3]], arc_map[c.arcs[4]],
        )) for c in ir.crossings
    ]
    TangleIR(new_crossings;
             ports_in  = ir.ports_in,
             ports_out = ir.ports_out,
             metadata  = TangleMetadata(
                 name        = ir.metadata.name,
                 source_text = ir.metadata.source_text,
                 provenance  = :rewritten,
             ))
end

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

"""
    lower_krl(prog::KRLProgram) -> KRLLoweredProgram

Lower a parsed `KRLProgram` to TangleIR values.

`let` bindings are accumulated into the environment and available to
subsequent statements.
"""
function lower_krl(prog::KRLProgram)::KRLLoweredProgram
    env     = KRLEnv()
    results = Any[]
    queries = KRLQueryPlan[]

    for stmt in prog.statements
        if stmt isa KRLBinding
            ir = _lower_expr(stmt.expr, env, stmt.line, stmt.col)
            env[stmt.name] = ir
        elseif stmt isa KRLExpressionStmt
            ir = _lower_expr(stmt.expr, env, stmt.line, stmt.col)
            push!(results, ir)
        elseif stmt isa KRLQuery
            qp = KRLQueryPlan(stmt.filters)
            push!(results, qp)
            push!(queries, qp)
        else
            throw(KRLLowerError("unknown statement type $(typeof(stmt))", 0, 0))
        end
    end

    KRLLoweredProgram(env, results, queries)
end

function _lower_expr(node::KRLNode, env::KRLEnv, line::Int, col::Int)::TangleIR
    if node isa KRLGenerator
        return _lower_generator(node)
    elseif node isa KRLCompose
        irs = [_lower_expr(op, env, op.line, op.col) for op in node.operands]
        return foldl(compose, irs)
    elseif node isa KRLTensor
        irs = [_lower_expr(op, env, op.line, op.col) for op in node.operands]
        return foldl(tensor, irs)
    elseif node isa KRLPrefixOp
        return _lower_prefix(node, env)
    elseif node isa KRLIdentifier
        haskey(env, node.name) || throw(KRLLowerError(
            "unbound identifier '$(node.name)'", node.line, node.col))
        return env[node.name]
    elseif node isa KRLParenExpr
        return _lower_expr(node.expr, env, node.line, node.col)
    else
        throw(KRLLowerError(
            "cannot lower $(typeof(node)) to TangleIR", line, col))
    end
end

function _lower_generator(node::KRLGenerator)::TangleIR
    node.kind == :sigma     && return _sigma_ir(node.index, +1)
    node.kind == :sigma_inv && return _sigma_ir(node.index, -1)
    node.kind == :cup       && return _cup_ir(node.index)
    node.kind == :cap       && return _cap_ir(node.index)
    throw(KRLLowerError("unknown generator kind $(node.kind)", node.line, node.col))
end

function _lower_prefix(node::KRLPrefixOp, env::KRLEnv)::TangleIR
    inner = _lower_expr(node.operand, env, node.line, node.col)
    node.op == :close     && return close_tangle(inner)
    node.op == :mirror    && return mirror(inner)
    node.op == :simplify  && return simplify_ir(inner)
    node.op == :normalise && return canonicalize_ir(inner)
    node.op == :classify  && return inner   # deferred to query layer
    throw(KRLLowerError("unknown prefix op $(node.op)", node.line, node.col))
end
