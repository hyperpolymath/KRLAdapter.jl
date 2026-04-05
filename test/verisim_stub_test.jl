# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using KRLAdapter
using UUIDs

# Synthesise a minimal concrete subtype for testing the stub contract.
struct _StubVerisimCore <: KRLAdapter.AbstractVerisimCore end

@testset "VerisimCore stub — error contract" begin
    core = _StubVerisimCore()
    ir = TangleIR([CrossingIR(:c1, 1, (1, 2, 3, 4))])

    @test_throws KRLAdapter.VerisimCoreNotWiredError store_ir_verisim!(core, ir)
    @test_throws KRLAdapter.VerisimCoreNotWiredError store_ir_verisim!(core, ir; name="x", tags=["t"])
    @test_throws KRLAdapter.VerisimCoreNotWiredError fetch_ir_verisim(core, uuid4())
    @test_throws KRLAdapter.VerisimCoreNotWiredError query_ir_verisim(core)
    @test_throws KRLAdapter.VerisimCoreNotWiredError query_ir_verisim(core; crossing_number=3)
    @test_throws KRLAdapter.VerisimCoreNotWiredError prove_consonance(core, ir, ir)
end

@testset "VerisimCore stub — subtype override works" begin
    # User defines their own concrete core and overrides store_ir_verisim!
    struct _WiredCore <: KRLAdapter.AbstractVerisimCore
        calls::Vector{Tuple{Symbol,Any}}
    end
    _WiredCore() = _WiredCore(Tuple{Symbol,Any}[])

    # Override: record the call and return the IR's UUID
    function KRLAdapter.store_ir_verisim!(core::_WiredCore, ir::TangleIR;
            name=nothing, tags=String[])
        push!(core.calls, (:store, (name, copy(tags))))
        ir.id
    end

    core = _WiredCore()
    ir = TangleIR([CrossingIR(:c1, 1, (1, 2, 3, 4))])
    result = store_ir_verisim!(core, ir; name="demo", tags=["a", "b"])

    @test result == ir.id
    @test length(core.calls) == 1
    @test core.calls[1][1] === :store
    @test core.calls[1][2] == ("demo", ["a", "b"])
end

@testset "ConsonanceVerdict struct" begin
    verdict = KRLAdapter.ConsonanceVerdict(true, "trefoil-mirror-trefoil is not consonant", "different chirality")
    @test verdict.consonant == true
    @test verdict.witness == "trefoil-mirror-trefoil is not consonant"
    @test verdict.reason == "different chirality"

    no_witness = KRLAdapter.ConsonanceVerdict(false, nothing, "no proof found")
    @test no_witness.witness === nothing
end

@testset "VerisimCoreNotWiredError message includes method name + experiment pointer" begin
    err = KRLAdapter.VerisimCoreNotWiredError("test_method")
    buf = IOBuffer()
    Base.showerror(buf, err)
    msg = String(take!(buf))
    @test occursin("test_method", msg)
    @test occursin("verisim-modular-experiment", msg)
    @test occursin("AbstractVerisimCore", msg)
end
