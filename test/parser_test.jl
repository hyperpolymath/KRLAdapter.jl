# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Tests for the KRL parser (lexer + AST + parser + lowering).
# Decision: Option B — Julia in KRLAdapter.jl (2026-04-12).

using Test
using KRLAdapter

# ---------------------------------------------------------------------------
# § 1. Lexer
# ---------------------------------------------------------------------------

@testset "KRL Lexer" begin
    @testset "keywords" begin
        toks = tokenise("let close mirror simplify normalise classify find where and sigma sigma_inv cup cap")
        kinds = [t.kind for t in toks if t.kind != :eof]
        @test all(k -> k == :keyword, kinds)
        words = [t.value for t in toks if t.kind == :keyword]
        @test "let" in words
        @test "sigma_inv" in words
        @test "find" in words
    end

    @testset "identifiers" begin
        toks = tokenise("trefoil my_knot x1")
        ids = [t for t in toks if t.kind == :identifier]
        @test length(ids) == 3
        @test ids[1].value == "trefoil"
        @test ids[2].value == "my_knot"
    end

    @testset "integers" begin
        toks = tokenise("1 42 100")
        ints = [t for t in toks if t.kind == :integer]
        @test length(ints) == 3
        @test ints[2].value == "42"
    end

    @testset "string literals" begin
        toks = tokenise(raw"""find where name = "trefoil" ;""")
        strs = [t for t in toks if t.kind == :string]
        @test length(strs) == 1
        @test strs[1].value == "trefoil"
    end

    @testset "operators" begin
        toks = tokenise("= < > <= >= !=")
        ops = [t.kind for t in toks if t.kind != :eof]
        @test ops == [:equal, :lt, :gt, :lte, :gte, :neq]
    end

    @testset "punctuation" begin
        toks = tokenise("; | ( )")
        @test any(t -> t.kind == :semi,   toks)
        @test any(t -> t.kind == :pipe,   toks)
        @test any(t -> t.kind == :lparen, toks)
        @test any(t -> t.kind == :rparen, toks)
    end

    @testset "line comments stripped" begin
        toks = tokenise("sigma 1 -- this is a comment\nsigma_inv 2")
        kws = [t.value for t in toks if t.kind == :keyword]
        @test kws == ["sigma", "sigma_inv"]
        ints = [t.value for t in toks if t.kind == :integer]
        @test ints == ["1", "2"]
    end

    @testset "position tracking" begin
        toks = tokenise("sigma 1\nsigma_inv 2")
        sigma_tok = first(t for t in toks if t.kind == :keyword && t.value == "sigma")
        @test sigma_tok.line == 1
        inv_tok = first(t for t in toks if t.kind == :keyword && t.value == "sigma_inv")
        @test inv_tok.line == 2
    end

    @testset "lex error on unexpected character" begin
        @test_throws KRLLexError tokenise("sigma 1 @")
    end

    @testset "unterminated string literal" begin
        @test_throws KRLLexError tokenise(raw"""find where name = "unterminated""")
    end
end

# ---------------------------------------------------------------------------
# § 2. Parser — grammar coverage
# ---------------------------------------------------------------------------

@testset "KRL Parser" begin
    @testset "empty program" begin
        prog = parse_krl("")
        @test prog isa KRLProgram
        @test isempty(prog.statements)
    end

    @testset "single generator" begin
        prog = parse_krl("sigma 1 ;")
        @test length(prog.statements) == 1
        stmt = prog.statements[1]
        @test stmt isa KRLExpressionStmt
        @test stmt.expr isa KRLGenerator
        @test stmt.expr.kind == :sigma
        @test stmt.expr.index == 1
    end

    @testset "let binding" begin
        prog = parse_krl("let x = sigma 1 ;")
        @test length(prog.statements) == 1
        b = prog.statements[1]
        @test b isa KRLBinding
        @test b.name == "x"
        @test b.expr isa KRLGenerator
    end

    @testset "sequential composition" begin
        prog = parse_krl("let trefoil = sigma 1 ; sigma 1 ; sigma 1 ;")
        b = prog.statements[1]
        @test b isa KRLBinding
        @test b.expr isa KRLCompose
        @test length(b.expr.operands) == 3
    end

    @testset "tensor product" begin
        prog = parse_krl("sigma 1 | sigma 2 ;")
        stmt = prog.statements[1]
        @test stmt.expr isa KRLTensor
        @test length(stmt.expr.operands) == 2
    end

    @testset "prefix close" begin
        prog = parse_krl("close (sigma 1 ; sigma 1 ; sigma 1) ;")
        stmt = prog.statements[1]
        @test stmt.expr isa KRLPrefixOp
        @test stmt.expr.op == :close
        @test stmt.expr.operand isa KRLParenExpr
    end

    @testset "prefix mirror" begin
        prog = parse_krl("let m = mirror sigma 1 ;")
        @test prog.statements[1].expr isa KRLPrefixOp
        @test prog.statements[1].expr.op == :mirror
    end

    @testset "prefix simplify and normalise" begin
        prog = parse_krl("simplify sigma 1 ; normalise sigma 2 ;")
        @test prog.statements[1].expr isa KRLPrefixOp
        @test prog.statements[1].expr.op == :simplify
        @test prog.statements[2].expr isa KRLPrefixOp
        @test prog.statements[2].expr.op == :normalise
    end

    @testset "all generator kinds" begin
        for (kw, sym) in [("sigma", :sigma), ("sigma_inv", :sigma_inv),
                           ("cup", :cup), ("cap", :cap)]
            prog = parse_krl("$kw 1 ;")
            @test prog.statements[1].expr.kind == sym
        end
    end

    @testset "identifier reference" begin
        prog = parse_krl("let x = sigma 1 ; let y = close x ;")
        @test prog.statements[2].expr.operand isa KRLIdentifier
        @test prog.statements[2].expr.operand.name == "x"
    end

    @testset "parenthesised expression" begin
        prog = parse_krl("(sigma 1) ;")
        stmt = prog.statements[1]
        @test stmt.expr isa KRLParenExpr
        @test stmt.expr.expr isa KRLGenerator
    end

    @testset "query with single filter" begin
        prog = parse_krl("find where crossing < 8 ;")
        q = prog.statements[1]
        @test q isa KRLQuery
        @test length(q.filters) == 1
        f = q.filters[1]
        @test f isa KRLFilter
        @test f.lhs == "crossing"
        @test f.comparison == :lt
        @test f.rhs isa KRLIntValue
        @test f.rhs.n == 8
    end

    @testset "query with multiple filters" begin
        prog = parse_krl("find where crossing < 8 and writhe = 3 ;")
        q = prog.statements[1]
        @test length(q.filters) == 2
        @test q.filters[1].lhs == "crossing"
        @test q.filters[2].lhs == "writhe"
        @test q.filters[2].comparison == :eq
    end

    @testset "query filter — identifier value" begin
        prog = parse_krl("find where jones = trefoil ;")
        f = prog.statements[1].filters[1]
        @test f.rhs isa KRLIdentValue
        @test f.rhs.name == "trefoil"
    end

    @testset "query filter — string value" begin
        prog = parse_krl("""find where name = "3_1" ;""")
        f = prog.statements[1].filters[1]
        @test f.rhs isa KRLStrValue
        @test f.rhs.s == "3_1"
    end

    @testset "multi-statement program" begin
        src = """
        let trefoil = close (sigma 1 ; sigma 1 ; sigma 1) ;
        let mirror_trefoil = mirror trefoil ;
        find where jones = trefoil and crossing < 8 ;
        """
        prog = parse_krl(src)
        @test length(prog.statements) == 3
        @test prog.statements[1] isa KRLBinding
        @test prog.statements[2] isa KRLBinding
        @test prog.statements[3] isa KRLQuery
    end

    @testset "parse error: missing semicolon" begin
        @test_throws KRLParseError parse_krl("sigma 1")
    end

    @testset "parse error: unrecognised token in expression" begin
        @test_throws Union{KRLParseError, KRLLexError} parse_krl("let x = @ ;")
    end

    @testset "parse error: missing generator index" begin
        @test_throws KRLParseError parse_krl("sigma ;")
    end

    @testset "parse error: generator index zero" begin
        @test_throws KRLParseError parse_krl("sigma 0 ;")
    end
end

# ---------------------------------------------------------------------------
# § 3. Parsing all example .krl files from the krl/ repo
#
# Replaces the shell-based grammar_smoke.sh with a Julia parser check.
# ---------------------------------------------------------------------------

@testset "Example .krl files parse without error" begin
    # Locate the krl examples directory relative to the KRLAdapter repo.
    # Assumes both repos live in the same parent directory.
    adapter_root = joinpath(dirname(@__FILE__), "..")
    krl_examples = normpath(joinpath(adapter_root, "..", "krl", "examples"))

    if isdir(krl_examples)
        for f in readdir(krl_examples; join = true)
            endswith(f, ".krl") || continue
            src = read(f, String)
            @testset basename(f) begin
                @test (prog = parse_krl(src); prog isa KRLProgram)
                @test !isempty(prog.statements)
            end
        end
    else
        @warn "krl/examples not found at $krl_examples — skipping example file tests"
        @test true  # prevent empty testset failure
    end
end

# ---------------------------------------------------------------------------
# § 4. AST → TangleIR lowering
# ---------------------------------------------------------------------------

@testset "KRL Lowering" begin
    @testset "single sigma lowered to TangleIR" begin
        prog = parse_krl("sigma 1 ;")
        lp = lower_krl(prog)
        @test length(lp.results) == 1
        ir = lp.results[1]
        @test ir isa TangleIR
        @test length(ir.crossings) == 1
        @test ir.crossings[1].sign == +1
    end

    @testset "sigma_inv lowered to negative crossing" begin
        prog = parse_krl("sigma_inv 1 ;")
        lp = lower_krl(prog)
        ir = lp.results[1]
        @test ir.crossings[1].sign == -1
    end

    @testset "compose lowered via compose()" begin
        prog = parse_krl("sigma 1 ; sigma 1 ;")
        lp = lower_krl(prog)
        ir = lp.results[1]
        @test ir isa TangleIR
        @test length(ir.crossings) == 2
    end

    @testset "trefoil: close(sigma1;sigma1;sigma1)" begin
        src = "let trefoil = close (sigma 1 ; sigma 1 ; sigma 1) ;"
        prog = parse_krl(src)
        lp = lower_krl(prog)
        @test haskey(lp.bindings, "trefoil")
        ir = lp.bindings["trefoil"]
        @test ir isa TangleIR
        @test is_closed(ir)  # closure produces empty ports on both sides
    end

    @testset "mirror flips crossing signs" begin
        src = "let m = mirror sigma 1 ;"
        prog = parse_krl(src)
        lp = lower_krl(prog)
        ir = lp.bindings["m"]
        @test ir.crossings[1].sign == -1
    end

    @testset "let binding available to subsequent statements" begin
        src = """
        let x = sigma 1 ;
        let y = mirror x ;
        """
        prog = parse_krl(src)
        lp = lower_krl(prog)
        @test haskey(lp.bindings, "x")
        @test haskey(lp.bindings, "y")
        @test lp.bindings["y"].crossings[1].sign == -1
    end

    @testset "unbound identifier raises KRLLowerError" begin
        prog = parse_krl("close unbound_name ;")
        @test_throws KRLLowerError lower_krl(prog)
    end

    @testset "query produces KRLQueryPlan, not TangleIR" begin
        src = "find where crossing < 8 ;"
        prog = parse_krl(src)
        lp = lower_krl(prog)
        @test length(lp.queries) == 1
        @test lp.queries[1] isa KRLQueryPlan
    end

    @testset "simplify removes R1 kinks at IR level" begin
        # compose(sigma1, sigma_inv1) = R2-reducible bigon
        src = "simplify (sigma 1 ; sigma_inv 1) ;"
        prog = parse_krl(src)
        lp = lower_krl(prog)
        ir = lp.results[1]
        # After R2 simplification the bigon is gone
        @test length(ir.crossings) == 0
    end
end

println("parser-tests-ok")
