# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
KRL Recursive-Descent Parser

Converts a `Vector{Token}` produced by `tokenise` into a `KRLProgram` AST.

Grammar followed exactly:

    program        = { statement }
    statement      = binding | expression_stmt | query
    binding        = "let" identifier "=" expression ";"
    expression_stmt= expression ";"
    query          = "find" "where" filter_list ";"

    expression     = compose_expr
    compose_expr   = tensor_expr { ";" tensor_expr }   (* left-assoc *)
    tensor_expr    = unary_expr { "|" unary_expr }      (* left-assoc *)
    unary_expr     = prefix_op unary_expr | atom
    prefix_op      = "close" | "mirror" | "simplify" | "normalise" | "classify"
    atom           = generator | identifier | "(" expression ")"
    generator      = ("sigma" | "sigma_inv" | "cup" | "cap") integer

    filter_list    = filter { "and" filter }
    filter         = identifier comparison value
    comparison     = "=" | "<" | ">" | "<=" | ">=" | "!="
    value          = integer | string_literal | identifier

The parser is entirely standalone: it does not import KRLAdapter internals or
any knot-theory library.
"""

export parse_krl, KRLParseError

# ---------------------------------------------------------------------------
# Parse error
# ---------------------------------------------------------------------------

"""
    KRLParseError(msg, line, col)

Thrown when the token stream does not match the grammar.
"""
struct KRLParseError <: Exception
    msg::String
    line::Int
    col::Int
end

Base.showerror(io::IO, e::KRLParseError) =
    print(io, "KRLParseError at L$(e.line):C$(e.col): $(e.msg)")

# ---------------------------------------------------------------------------
# Parser state (mutable, local to one parse call)
# ---------------------------------------------------------------------------

mutable struct ParserState
    tokens::Vector{Token}
    pos::Int  # index of current (next-to-consume) token
end

function _peek(ps::ParserState)::Token
    ps.tokens[ps.pos]
end

function _advance!(ps::ParserState)::Token
    t = ps.tokens[ps.pos]
    ps.pos = min(ps.pos + 1, length(ps.tokens))
    t
end

function _at_eof(ps::ParserState)::Bool
    _peek(ps).kind == :eof
end

"""
Consume the next token if it matches `kind` and (optionally) `value`.
Returns the consumed token. Throws `KRLParseError` otherwise.
"""
function _expect!(ps::ParserState, kind::Symbol, value::Union{String,Nothing} = nothing)::Token
    t = _peek(ps)
    if t.kind != kind || (!isnothing(value) && t.value != value)
        expected = isnothing(value) ? string(kind) : "$(kind)($(repr(value)))"
        got = t.kind == :eof ? "end-of-file" : "$(t.kind)($(repr(t.value)))"
        throw(KRLParseError("expected $expected, got $got", t.line, t.col))
    end
    _advance!(ps)
end

"""
Return true and consume if current token matches kind+value, else return false.
"""
function _match!(ps::ParserState, kind::Symbol, value::Union{String,Nothing} = nothing)::Bool
    t = _peek(ps)
    if t.kind == kind && (isnothing(value) || t.value == value)
        _advance!(ps)
        return true
    end
    false
end

# ---------------------------------------------------------------------------
# Top-level entry point
# ---------------------------------------------------------------------------

"""
    parse_krl(src::String) -> KRLProgram

Lex and parse a KRL source string. Returns a `KRLProgram` AST.

Throws `KRLLexError` on invalid characters, `KRLParseError` on grammar violations.
"""
function parse_krl(src::String)::KRLProgram
    tokens = tokenise(src)
    ps = ParserState(tokens, 1)
    parse_program(ps)
end

# ---------------------------------------------------------------------------
# Grammar: program
# ---------------------------------------------------------------------------

function parse_program(ps::ParserState)::KRLProgram
    line = _peek(ps).line
    col  = _peek(ps).col
    stmts = KRLNode[]
    while !_at_eof(ps)
        push!(stmts, parse_statement(ps))
    end
    KRLProgram(stmts, line, col)
end

# ---------------------------------------------------------------------------
# Grammar: statement
# ---------------------------------------------------------------------------

function parse_statement(ps::ParserState)::KRLNode
    t = _peek(ps)

    # binding: "let" identifier "=" expression ";"
    if t.kind == :keyword && t.value == "let"
        return parse_binding(ps)
    end

    # query: "find" "where" filter_list ";"
    if t.kind == :keyword && t.value == "find"
        return parse_query(ps)
    end

    # expression_stmt: expression ";"
    parse_expression_stmt(ps)
end

function parse_binding(ps::ParserState)::KRLBinding
    let_tok = _expect!(ps, :keyword, "let")
    name_tok = _expect!(ps, :identifier)
    _expect!(ps, :equal)
    expr = parse_expression(ps)
    _expect!(ps, :semi)
    KRLBinding(name_tok.value, expr, let_tok.line, let_tok.col)
end

function parse_expression_stmt(ps::ParserState)::KRLExpressionStmt
    t = _peek(ps)
    expr = parse_expression(ps)
    _expect!(ps, :semi)
    KRLExpressionStmt(expr, t.line, t.col)
end

function parse_query(ps::ParserState)::KRLQuery
    find_tok = _expect!(ps, :keyword, "find")
    _expect!(ps, :keyword, "where")
    filters = parse_filter_list(ps)
    _expect!(ps, :semi)
    KRLQuery(filters, find_tok.line, find_tok.col)
end

# ---------------------------------------------------------------------------
# Grammar: expression → compose_expr → tensor_expr → unary_expr → atom
# ---------------------------------------------------------------------------

"""
Parse an expression. `in_parens` controls whether `;` is treated as sequential
composition. At the top level of a statement, `;` is a terminator and must NOT
be consumed here — the statement parsers (`parse_binding`, `parse_expression_stmt`)
consume it explicitly via `_expect!(ps, :semi)`. Only inside a parenthesised
sub-expression is `;` sequential composition.
"""
function parse_expression(ps::ParserState; in_parens::Bool = false)::KRLNode
    parse_compose_expr(ps; in_parens)
end

# compose_expr = tensor_expr { ";" tensor_expr }
# Sequential composition with ";" is only active inside parentheses.
# At the statement level, ";" terminates the statement and must not be consumed.
function parse_compose_expr(ps::ParserState; in_parens::Bool = false)::KRLNode
    first = parse_tensor_expr(ps)
    operands = KRLNode[first]

    # Only consume ";" as composition when we are inside a parenthesised expression.
    if in_parens
        while true
            t = _peek(ps)
            t.kind == :semi || break
            # Stop before ")" which closes the paren context.
            next_pos = ps.pos + 1
            if next_pos > length(ps.tokens)
                break
            end
            after = ps.tokens[next_pos]
            (after.kind == :eof || after.kind == :rparen) && break

            _advance!(ps)  # consume ";"
            push!(operands, parse_tensor_expr(ps))
        end
    end

    length(operands) == 1 ? operands[1] : KRLCompose(operands, first.line, first.col)
end

# tensor_expr = unary_expr { "|" unary_expr }
function parse_tensor_expr(ps::ParserState)::KRLNode
    first = parse_unary_expr(ps)
    operands = KRLNode[first]

    while _peek(ps).kind == :pipe
        _advance!(ps)  # consume "|"
        push!(operands, parse_unary_expr(ps))
    end

    length(operands) == 1 ? operands[1] : KRLTensor(operands, first.line, first.col)
end

# unary_expr = prefix_op unary_expr | atom
const PREFIX_OPS = Set(["close", "mirror", "simplify", "normalise", "classify"])

function parse_unary_expr(ps::ParserState)::KRLNode
    t = _peek(ps)
    if t.kind == :keyword && t.value in PREFIX_OPS
        _advance!(ps)
        op = Symbol(t.value)
        operand = parse_unary_expr(ps)
        return KRLPrefixOp(op, operand, t.line, t.col)
    end
    parse_atom(ps)
end

# atom = generator | identifier | "(" expression ")"
const GENERATOR_KINDS = Set(["sigma", "sigma_inv", "cup", "cap"])

function parse_atom(ps::ParserState)::KRLNode
    t = _peek(ps)

    # generator: sigma / sigma_inv / cup / cap followed by integer
    if t.kind == :keyword && t.value in GENERATOR_KINDS
        _advance!(ps)
        idx_tok = _expect!(ps, :integer)
        idx = parse(Int, idx_tok.value)
        idx >= 1 || throw(KRLParseError(
            "generator index must be ≥ 1, got $idx", idx_tok.line, idx_tok.col))
        return KRLGenerator(Symbol(t.value), idx, t.line, t.col)
    end

    # parenthesised expression — ";" is sequential composition inside parens
    if t.kind == :lparen
        _advance!(ps)
        expr = parse_expression(ps; in_parens=true)
        _expect!(ps, :rparen)
        return KRLParenExpr(expr, t.line, t.col)
    end

    # identifier (let-bound reference)
    if t.kind == :identifier
        _advance!(ps)
        return KRLIdentifier(t.value, t.line, t.col)
    end

    # nothing matched
    got = t.kind == :eof ? "end-of-file" : "$(t.kind)($(repr(t.value)))"
    throw(KRLParseError("expected expression (generator, identifier, or '('), got $got",
                        t.line, t.col))
end

# ---------------------------------------------------------------------------
# Grammar: query filters
# ---------------------------------------------------------------------------

# filter_list = filter { "and" filter }
function parse_filter_list(ps::ParserState)::Vector{KRLNode}
    filters = KRLNode[parse_filter(ps)]
    while _peek(ps).kind == :keyword && _peek(ps).value == "and"
        _advance!(ps)  # consume "and"
        push!(filters, parse_filter(ps))
    end
    filters
end

# filter = identifier comparison value
function parse_filter(ps::ParserState)::KRLFilter
    lhs_tok = _expect!(ps, :identifier)
    cmp_tok = _advance!(ps)
    cmp = _token_to_comparison(cmp_tok)
    rhs = parse_value(ps)
    KRLFilter(lhs_tok.value, cmp, rhs, lhs_tok.line, lhs_tok.col)
end

function _token_to_comparison(t::Token)::Symbol
    t.kind == :equal && return :eq
    t.kind == :lt    && return :lt
    t.kind == :gt    && return :gt
    t.kind == :lte   && return :lte
    t.kind == :gte   && return :gte
    t.kind == :neq   && return :neq
    throw(KRLParseError("expected comparison operator, got $(t.kind)($(repr(t.value)))",
                        t.line, t.col))
end

# value = integer | string_literal | identifier
function parse_value(ps::ParserState)::KRLNode
    t = _peek(ps)
    if t.kind == :integer
        _advance!(ps)
        return KRLIntValue(parse(Int, t.value), t.line, t.col)
    end
    if t.kind == :string
        _advance!(ps)
        return KRLStrValue(t.value, t.line, t.col)
    end
    if t.kind == :identifier
        _advance!(ps)
        return KRLIdentValue(t.value, t.line, t.col)
    end
    throw(KRLParseError("expected filter value (integer, string, or identifier), got $(t.kind)",
                        t.line, t.col))
end
