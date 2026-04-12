# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

# Integration tests for QuandleDB adapter (Task #6) and Groove emitter.
#
# These tests use a MockQuandleDB (no live server required) to validate
# the abstract interface and EquivalenceResult types, plus structural
# tests for GrooveEmitter that don't require a running OTLP collector.
#
# Live tests against a running QuandleDB server are tagged @slow and
# skipped unless the QUANDLEDB_LIVE environment variable is set.

using Test
using KRLAdapter

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

# Build a minimal TangleIR with known knot name for routing tests.
function _ir_with_name(name::String)
    TangleIR(CrossingIR[];
        metadata = TangleMetadata(extra = Dict{Symbol,Any}(:knot_name => name)))
end

# Build a TangleIR with Gauss code (no name) for fallback routing tests.
function _ir_with_gauss(codes::Vector{Int})
    TangleIR(CrossingIR[];
        metadata = TangleMetadata(extra = Dict{Symbol,Any}(:gauss_code => codes)))
end

# TangleIR with no usable reference (triggers :unknown routing path).
function _ir_bare()
    TangleIR(CrossingIR[])
end

# ---------------------------------------------------------------------------
# Mock QuandleDB — records calls, returns canned responses.
# ---------------------------------------------------------------------------

struct MockQuandleDB <: AbstractQuandleDB
    calls::Vector{Tuple{Symbol, Any}}
    MockQuandleDB() = new(Tuple{Symbol, Any}[])
end

function query_equivalence(db::MockQuandleDB, ir::TangleIR)
    push!(db.calls, (:query_equivalence, ir.id))
    EquivalenceResult("3_1",
        ["3_1_mirror"], String[], ["3_1_mirror"],
        "deadbeef", "qk-trefoil")
end

function classify_knot(db::MockQuandleDB, ir::TangleIR)
    push!(db.calls, (:classify_knot, ir.id))
    Dict{String,Any}("name" => "3_1", "crossing_number" => 3, "genus" => 1)
end

function fetch_knot(db::MockQuandleDB, name::String)
    push!(db.calls, (:fetch_knot, name))
    name == "3_1" ?
        Dict{String,Any}("name" => "3_1", "crossing_number" => 3) :
        nothing
end

# ---------------------------------------------------------------------------
# §1  Abstract interface / error types
# ---------------------------------------------------------------------------

@testset "QuandleDB abstract interface" begin
    struct _UnimplementedDB <: AbstractQuandleDB end
    db  = _UnimplementedDB()
    ir  = _ir_bare()

    @testset "stubs throw QuandleDBNotWiredError" begin
        @test_throws QuandleDBNotWiredError query_equivalence(db, ir)
        @test_throws QuandleDBNotWiredError classify_knot(db, ir)
        @test_throws QuandleDBNotWiredError fetch_knot(db, "3_1")
    end

    @testset "store_knot! always throws QuandleDBReadOnlyError" begin
        @test_throws QuandleDBReadOnlyError store_knot!(db, ir)
        # NqcQuandleDB also raises — it inherits the stub.
        nqc = NqcQuandleDB()
        @test_throws QuandleDBReadOnlyError store_knot!(nqc, ir)
    end

    @testset "error messages are non-empty" begin
        e1 = QuandleDBNotWiredError("test_method")
        @test occursin("test_method", sprint(showerror, e1))
        e2 = QuandleDBReadOnlyError()
        @test occursin("read-only", sprint(showerror, e2))
        @test occursin("Skein.jl", sprint(showerror, e2))
    end
end

# ---------------------------------------------------------------------------
# §2  EquivalenceResult struct
# ---------------------------------------------------------------------------

@testset "EquivalenceResult" begin
    r = EquivalenceResult("3_1",
            ["3_1_mirror"], ["figure_eight"], ["3_1_mirror", "figure_eight"],
            "abc123", "qk-xyz")

    @test r.name == "3_1"
    @test r.strong_candidates == ["3_1_mirror"]
    @test r.weak_candidates   == ["figure_eight"]
    @test length(r.combined_candidates) == 2
    @test r.descriptor_hash   == "abc123"
    @test r.quandle_key       == "qk-xyz"

    # Empty result (knot not found)
    empty_r = EquivalenceResult("unknown", String[], String[], String[], nothing, nothing)
    @test isempty(empty_r.combined_candidates)
    @test isnothing(empty_r.descriptor_hash)
end

# ---------------------------------------------------------------------------
# §3  Mock QuandleDB — dispatch and call recording
# ---------------------------------------------------------------------------

@testset "MockQuandleDB dispatch" begin
    db = MockQuandleDB()

    @testset "query_equivalence is called" begin
        ir = _ir_with_name("3_1")
        r  = query_equivalence(db, ir)
        @test r.name == "3_1"
        @test any(c -> c[1] == :query_equivalence, db.calls)
    end

    @testset "classify_knot returns dict" begin
        ir  = _ir_with_name("3_1")
        rec = classify_knot(db, ir)
        @test !isnothing(rec)
        @test get(rec, "name", nothing) == "3_1"
        @test get(rec, "crossing_number", 0) == 3
    end

    @testset "fetch_knot by name" begin
        @test !isnothing(fetch_knot(db, "3_1"))
        @test isnothing(fetch_knot(db, "unknown_knot_xyz"))
    end
end

# ---------------------------------------------------------------------------
# §4  NqcQuandleDB — constructor and URL helpers
# ---------------------------------------------------------------------------

@testset "NqcQuandleDB construction" begin
    @testset "default constructor" begin
        db = NqcQuandleDB()
        @test db.host == "localhost"
        @test db.port == 8080
    end

    @testset "explicit host and port" begin
        db = NqcQuandleDB("myhost", 8082)
        @test db.host == "myhost"
        @test db.port == 8082
    end

    @testset "base URL helper" begin
        db = NqcQuandleDB("db.example.com", 8090)
        @test KRLAdapter._base_url(db) == "http://db.example.com:8090"
    end
end

# ---------------------------------------------------------------------------
# §5  _resolve_knot_ref routing logic
# ---------------------------------------------------------------------------

@testset "_resolve_knot_ref routing" begin
    @testset "prefers :knot_name" begin
        ir = _ir_with_name("4_1")
        kind, ref = KRLAdapter._resolve_knot_ref(ir)
        @test kind == :name
        @test ref  == "4_1"
    end

    @testset "falls back to :gauss" begin
        ir = _ir_with_gauss([1, -2, 3, -1, 2, -3])
        kind, ref = KRLAdapter._resolve_knot_ref(ir)
        @test kind == :gauss
        @test occursin("gauss", ref)
        @test occursin("1", ref)
    end

    @testset ":unknown for bare IR" begin
        ir = _ir_bare()
        kind, _ = KRLAdapter._resolve_knot_ref(ir)
        @test kind == :unknown
    end
end

# ---------------------------------------------------------------------------
# §6  GrooveEmitter — construction and config
# ---------------------------------------------------------------------------

@testset "GrooveEmitter construction" begin
    @testset "default constructor" begin
        em = GrooveEmitter()
        @test em.enabled     == true
        @test em.groove_port == 6482
        @test occursin("4318", em.otlp_url)
        @test occursin("v1/traces", em.otlp_url)
    end

    @testset "custom OTLP URL" begin
        em = GrooveEmitter(otlp_url="http://otel-collector:9090/v1/traces")
        @test em.otlp_url == "http://otel-collector:9090/v1/traces"
    end

    @testset "disabled emitter" begin
        em = GrooveEmitter(enabled=false)
        @test em.enabled == false
        # emit_span on a disabled emitter must be a no-op (no error).
        @test_nowarn emit_span(em, "krl/test", time(), 1.0)
    end
end

# ---------------------------------------------------------------------------
# §7  emit_span — fire-and-forget with no live collector
# ---------------------------------------------------------------------------

@testset "emit_span resilience" begin
    # Point at a port that nothing is listening on — must not throw.
    em = GrooveEmitter(otlp_url="http://localhost:19999/v1/traces")

    @testset "does not raise when collector is absent" begin
        @test_nowarn emit_span(em, "krl/query_equivalence", time(), 12.5)
    end

    @testset "does not raise with extra attrs" begin
        attrs = Dict{String,Any}("krl.knot_name" => "3_1", "krl.n_candidates" => 3.0)
        @test_nowarn emit_span(em, "krl/query_equivalence", time(), 7.3; attrs=attrs)
    end
end

# ---------------------------------------------------------------------------
# §8  @groove_trace macro
# ---------------------------------------------------------------------------

@testset "@groove_trace macro" begin
    em = GrooveEmitter(enabled=false)  # disabled — no network traffic

    @testset "returns expression value" begin
        result = @groove_trace em "krl/test" (1 + 1)
        @test result == 2
    end

    @testset "propagates exceptions" begin
        @test_throws ErrorException @groove_trace em "krl/fail" error("boom")
    end
end

# ---------------------------------------------------------------------------
# §9  Groove capability declaration
# ---------------------------------------------------------------------------

@testset "Groove capability declaration" begin
    cap = KRLAdapter.GROOVE_CAPABILITIES
    @test cap["service"]  == "krl-adapter"
    @test "trace-source" in cap["offers"]
    @test "panll-observability" in cap["consumes"]
    @test cap["port"] == 6482
    @test haskey(cap, "otlp")
end

# ---------------------------------------------------------------------------
# §10  Live QuandleDB tests (skipped unless QUANDLEDB_LIVE=1)
# ---------------------------------------------------------------------------

if get(ENV, "QUANDLEDB_LIVE", "0") == "1"
    @testset "Live QuandleDB (requires server at localhost:8080)" begin
        db = NqcQuandleDB()

        @testset "fetch_knot 3_1" begin
            rec = fetch_knot(db, "3_1")
            @test !isnothing(rec)
            @test get(rec, "crossing_number", 0) == 3
        end

        @testset "query_equivalence trefoil" begin
            ir = _ir_with_name("3_1")
            r  = query_equivalence(db, ir)
            @test r isa EquivalenceResult
            @test r.name == "3_1"
            # The trefoil has a mirror — expect at least one candidate.
            @test !isempty(r.combined_candidates)
        end

        @testset "fetch_knot unknown returns nothing" begin
            @test isnothing(fetch_knot(db, "not_a_real_knot_xyz_999"))
        end
    end
end
