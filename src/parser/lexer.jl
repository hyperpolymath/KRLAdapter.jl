# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
KRL Lexer — tokenises a KRL source string into a flat `Vector{Token}`.

The lexer is a single-pass scanner that:
  - Skips whitespace (space, tab, CR, LF)
  - Discards line comments (`--` to end-of-line)
  - Recognises all KRL tokens in one pass

Token kinds are represented as `Symbol` tags:
  `:keyword`, `:identifier`, `:integer`, `:string`,
  `:semi`, `:pipe`, `:lparen`, `:rparen`, `:equal`,
  `:lt`, `:gt`, `:lte`, `:gte`, `:neq`, `:eof`

Positions carry `line` and `col` for error messages.
"""

export Token, TokenKind, tokenise, KRLLexError

# ---------------------------------------------------------------------------
# Token kind
# ---------------------------------------------------------------------------

const TokenKind = Symbol  # one of the tags enumerated above

# ---------------------------------------------------------------------------
# Reserved words (must match grammar.ebnf)
# ---------------------------------------------------------------------------

const KRL_KEYWORDS = Set([
    "let", "close", "mirror", "simplify", "normalise", "classify",
    "find", "where", "and",
    "sigma", "sigma_inv", "cup", "cap",
])

# ---------------------------------------------------------------------------
# Token
# ---------------------------------------------------------------------------

"""
    Token

A single lexical unit produced by `tokenise`.

# Fields
- `kind::TokenKind` — `:keyword`, `:identifier`, `:integer`, `:string`,
  `:semi`, `:pipe`, `:lparen`, `:rparen`, `:equal`,
  `:lt`, `:gt`, `:lte`, `:gte`, `:neq`, `:eof`
- `value::String` — raw text of the token (empty for `:eof`)
- `line::Int` — 1-based source line
- `col::Int` — 1-based column of first character
"""
struct Token
    kind::TokenKind
    value::String
    line::Int
    col::Int
end

Base.show(io::IO, t::Token) =
    print(io, "Token($(t.kind), $(repr(t.value)), L$(t.line):C$(t.col))")

# ---------------------------------------------------------------------------
# Lex error
# ---------------------------------------------------------------------------

"""
    KRLLexError(msg, line, col)

Thrown by `tokenise` when an unexpected character or unterminated string
is encountered.
"""
struct KRLLexError <: Exception
    msg::String
    line::Int
    col::Int
end

Base.showerror(io::IO, e::KRLLexError) =
    print(io, "KRLLexError at L$(e.line):C$(e.col): $(e.msg)")

# ---------------------------------------------------------------------------
# Tokeniser
# ---------------------------------------------------------------------------

"""
    tokenise(src::String) -> Vector{Token}

Scan `src` and return a `Vector{Token}`. The last token is always `Token(:eof, "", …)`.

Throws `KRLLexError` on unrecognised characters or unterminated string literals.
"""
function tokenise(src::String)::Vector{Token}
    tokens = Token[]
    chars = collect(src)
    n = length(chars)
    i = 1
    line = 1
    col = 1

    @inline advance!() = begin
        c = chars[i]
        i += 1
        if c == '\n'
            line += 1
            col = 1
        else
            col += 1
        end
        c
    end

    @inline peek() = i <= n ? chars[i] : '\0'
    @inline peek2() = i + 1 <= n ? chars[i + 1] : '\0'

    while i <= n
        start_line = line
        start_col  = col
        c = advance!()

        # ---- whitespace ----
        if c == ' ' || c == '\t' || c == '\r' || c == '\n'
            continue
        end

        # ---- line comment: -- to end-of-line ----
        if c == '-' && peek() == '-'
            advance!()  # consume second '-'
            while i <= n && chars[i] != '\n'
                advance!()
            end
            continue
        end

        # ---- single-character tokens ----
        if c == ';'
            push!(tokens, Token(:semi, ";", start_line, start_col))
            continue
        end
        if c == '|'
            push!(tokens, Token(:pipe, "|", start_line, start_col))
            continue
        end
        if c == '('
            push!(tokens, Token(:lparen, "(", start_line, start_col))
            continue
        end
        if c == ')'
            push!(tokens, Token(:rparen, ")", start_line, start_col))
            continue
        end

        # ---- comparison operators (may be two characters) ----
        if c == '='
            push!(tokens, Token(:equal, "=", start_line, start_col))
            continue
        end
        if c == '<'
            if peek() == '='
                advance!()
                push!(tokens, Token(:lte, "<=", start_line, start_col))
            else
                push!(tokens, Token(:lt, "<", start_line, start_col))
            end
            continue
        end
        if c == '>'
            if peek() == '='
                advance!()
                push!(tokens, Token(:gte, ">=", start_line, start_col))
            else
                push!(tokens, Token(:gt, ">", start_line, start_col))
            end
            continue
        end
        if c == '!'
            if peek() == '='
                advance!()
                push!(tokens, Token(:neq, "!=", start_line, start_col))
            else
                throw(KRLLexError("unexpected character '!'", start_line, start_col))
            end
            continue
        end

        # ---- string literals ----
        if c == '"'
            buf = Char[]
            while true
                i > n && throw(KRLLexError("unterminated string literal", start_line, start_col))
                ch = advance!()
                ch == '"' && break
                if ch == '\\' && i <= n
                    esc = advance!()
                    push!(buf, esc == 'n' ? '\n' : esc == 't' ? '\t' : esc)
                else
                    push!(buf, ch)
                end
            end
            push!(tokens, Token(:string, String(buf), start_line, start_col))
            continue
        end

        # ---- integers ----
        if isdigit(c)
            buf = [c]
            while i <= n && isdigit(peek())
                push!(buf, advance!())
            end
            push!(tokens, Token(:integer, String(buf), start_line, start_col))
            continue
        end

        # ---- identifiers and keywords ----
        # KRL identifiers start with a letter and continue with letters/digits/underscores.
        # sigma_inv uses an underscore, so underscores are valid in identifiers.
        if isletter(c) || c == '_'
            buf = [c]
            while i <= n && (isletter(peek()) || isdigit(peek()) || peek() == '_')
                push!(buf, advance!())
            end
            word = String(buf)
            kind = word in KRL_KEYWORDS ? :keyword : :identifier
            push!(tokens, Token(kind, word, start_line, start_col))
            continue
        end

        # ---- unrecognised ----
        throw(KRLLexError("unexpected character $(repr(c))", start_line, start_col))
    end

    push!(tokens, Token(:eof, "", line, col))
    tokens
end
