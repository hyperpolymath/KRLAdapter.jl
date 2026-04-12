# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
KRL AST — one Julia type per grammar production.

Corresponds directly to grammar.ebnf (v0.1.0). All nodes carry a
`(line, col)` source position for downstream error messages.

Grammar summary (top-down):

    program        = { statement }
    statement      = binding | expression_stmt | query
    binding        = "let" identifier "=" expression ";"
    expression     = compose_expr
    compose_expr   = tensor_expr { ";" tensor_expr }
    tensor_expr    = unary_expr { "|" unary_expr }
    unary_expr     = prefix_op unary_expr | atom
    prefix_op      = "close" | "mirror" | "simplify" | "normalise" | "classify"
    atom           = generator | identifier | "(" expression ")"
    generator      = crossing_gen | cup_cap_gen
    crossing_gen   = ("sigma" | "sigma_inv") integer
    cup_cap_gen    = ("cup" | "cap") integer
    query          = "find" "where" filter_list ";"
    filter_list    = filter { "and" filter }
    filter         = identifier comparison value
    comparison     = "=" | "<" | ">" | "<=" | ">=" | "!="
    value          = integer | string_literal | identifier
"""

export KRLNode, KRLProgram
export KRLBinding, KRLExpressionStmt, KRLQuery
export KRLCompose, KRLTensor, KRLPrefixOp, KRLGenerator, KRLIdentifier, KRLParenExpr
export KRLFilter, KRLFilterList
export KRLIntValue, KRLStrValue, KRLIdentValue

# ---------------------------------------------------------------------------
# Base node type
# ---------------------------------------------------------------------------

abstract type KRLNode end

# ---------------------------------------------------------------------------
# Program
# ---------------------------------------------------------------------------

"""
    KRLProgram(statements, line, col)

Root of the AST: an ordered list of top-level statements.
"""
struct KRLProgram <: KRLNode
    statements::Vector{KRLNode}
    line::Int
    col::Int
end

# ---------------------------------------------------------------------------
# Statements
# ---------------------------------------------------------------------------

"""
    KRLBinding(name, expr, line, col)

`let <name> = <expr> ;`
"""
struct KRLBinding <: KRLNode
    name::String
    expr::KRLNode
    line::Int
    col::Int
end

"""
    KRLExpressionStmt(expr, line, col)

A bare expression followed by `;`.
"""
struct KRLExpressionStmt <: KRLNode
    expr::KRLNode
    line::Int
    col::Int
end

"""
    KRLQuery(filters, line, col)

`find where <filter_list> ;`
"""
struct KRLQuery <: KRLNode
    filters::Vector{KRLNode}  # Vector{KRLFilter}
    line::Int
    col::Int
end

# ---------------------------------------------------------------------------
# Expressions
# ---------------------------------------------------------------------------

"""
    KRLCompose(operands, line, col)

Sequential composition: `a ; b ; c` (left-associative).
`operands` has ≥ 2 elements (folded from `tensor_expr { ";" tensor_expr }`).
If the parse yields a single tensor_expr with no `;`, the parser returns it
directly (no wrapping KRLCompose needed).
"""
struct KRLCompose <: KRLNode
    operands::Vector{KRLNode}
    line::Int
    col::Int
end

"""
    KRLTensor(operands, line, col)

Tensor product: `a | b | c` (left-associative).
Same convention: ≥ 2 operands; single-operand case is returned unwrapped.
"""
struct KRLTensor <: KRLNode
    operands::Vector{KRLNode}
    line::Int
    col::Int
end

"""
    KRLPrefixOp(op, operand, line, col)

Prefix operation: `close expr`, `mirror expr`, `simplify expr`,
`normalise expr`, `classify expr`.

`op` is one of `:close`, `:mirror`, `:simplify`, `:normalise`, `:classify`.
"""
struct KRLPrefixOp <: KRLNode
    op::Symbol
    operand::KRLNode
    line::Int
    col::Int
end

"""
    KRLGenerator(kind, index, line, col)

A primitive generator: `sigma N`, `sigma_inv N`, `cup N`, or `cap N`.

`kind` is one of `:sigma`, `:sigma_inv`, `:cup`, `:cap`.
`index` is the strand index (positive integer).
"""
struct KRLGenerator <: KRLNode
    kind::Symbol
    index::Int
    line::Int
    col::Int
end

"""
    KRLIdentifier(name, line, col)

A reference to a `let`-bound name.
"""
struct KRLIdentifier <: KRLNode
    name::String
    line::Int
    col::Int
end

"""
    KRLParenExpr(expr, line, col)

A parenthesised expression. Kept in the AST for source-position fidelity;
the lowering pass treats it as transparent.
"""
struct KRLParenExpr <: KRLNode
    expr::KRLNode
    line::Int
    col::Int
end

# ---------------------------------------------------------------------------
# Query filter pieces
# ---------------------------------------------------------------------------

"""
    KRLFilter(lhs, comparison, rhs, line, col)

A single filter predicate: `<identifier> <op> <value>`.

`comparison` is one of `:eq`, `:lt`, `:gt`, `:lte`, `:gte`, `:neq`.
"""
struct KRLFilter <: KRLNode
    lhs::String
    comparison::Symbol
    rhs::KRLNode  # KRLIntValue | KRLStrValue | KRLIdentValue
    line::Int
    col::Int
end

"""
    KRLIntValue(n, line, col)

An integer literal value in a filter.
"""
struct KRLIntValue <: KRLNode
    n::Int
    line::Int
    col::Int
end

"""
    KRLStrValue(s, line, col)

A string literal value in a filter.
"""
struct KRLStrValue <: KRLNode
    s::String
    line::Int
    col::Int
end

"""
    KRLIdentValue(name, line, col)

An identifier used as a value in a filter (reference to a let-bound expression).
"""
struct KRLIdentValue <: KRLNode
    name::String
    line::Int
    col::Int
end
