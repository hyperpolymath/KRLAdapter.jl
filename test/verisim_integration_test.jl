# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

# verisim_integration_test.jl — Phase 4 dogfood: LocalVerisimCore integration.
#
# Tests the real wiring between KRLAdapter.jl and the Verisim package
# (nextgen-databases/verisim-modular-experiment/).
#
# These tests are SKIPPED if the Verisim package is not loaded.  The stub
# tests in verisim_stub_test.jl run independently of Verisim.
#
# To run these tests in isolation:
#   cd nextgen-databases/verisim-modular-experiment
#   julia --project -e 'using Verisim; include("test/verisim_integration_test.jl")'
#
# From the KRLAdapter.jl root:
#   julia --project -e 'using Verisim; Pkg.test()'

using Test
using UUIDs

# Ensure KnotTheory is reachable as Main.KnotTheory so the tropical
# RII/RIII prover path inside TangleGraph can find it.
if isdefined(Main, :VerisimCore)
    try
        eval(:(import KnotTheory))
    catch
    end
end

# Guard: skip entire suite if Verisim is not loaded.
const _VERISIM_LOADED = isdefined(Main, :VerisimCore)

if !_VERISIM_LOADED
    @info "Skipping verisim_integration_test.jl (Verisim package not loaded)"
end

# -----------------------------------------------------------------------
# Helper: build a TangleIR with an explicit DT code (for consonance tests)
# -----------------------------------------------------------------------

function _tangle_with_dt(name::String, dt::Vector{Int},
                          prov::Symbol = :user;
                          source::String = "")
    extra = Dict{Symbol,Any}(:dt_code => dt)
    meta  = TangleMetadata(name, isempty(source) ? nothing : source,
                           String[], prov, extra)
    TangleIR(CrossingIR[]; metadata = meta)
end

# -----------------------------------------------------------------------
# Suites
# -----------------------------------------------------------------------

if _VERISIM_LOADED

@testset "LocalVerisimCore — Phase 4 dogfood" begin

    @testset "Constructor: LocalVerisimCore() succeeds when Verisim loaded" begin
        core = LocalVerisimCore()
        @test core isa LocalVerisimCore
        @test core isa AbstractVerisimCore
    end

    @testset "store_ir_verisim! returns the TangleIR's UUID" begin
        core = LocalVerisimCore()
        ir   = TangleIR([CrossingIR(:c1, +1, (1,2,3,4))])
        returned = store_ir_verisim!(core, ir)
        @test returned == ir.id
    end

    @testset "store then fetch round-trip (identity fields)" begin
        core = LocalVerisimCore()
        ir = TangleIR(
            [CrossingIR(:c1, +1, (1,2,3,4))];
            metadata = TangleMetadata(
                name       = "trefoil",
                source_text = "B_1^3",
                tags        = ["knot", "prime"],
                provenance  = :user,
                extra       = Dict{Symbol,Any}(:dt_code => [4,6,2]),
            )
        )

        store_ir_verisim!(core, ir)
        fetched = fetch_ir_verisim(core, ir.id)

        @test fetched !== nothing
        @test fetched.id == ir.id
        @test fetched.metadata.name == "trefoil"
        @test fetched.metadata.source_text == "B_1^3"
        @test fetched.metadata.provenance == :user
        @test "knot" in fetched.metadata.tags
        @test "prime" in fetched.metadata.tags
        @test get(fetched.metadata.extra, :dt_code, Int[]) == [4,6,2]
    end

    @testset "fetch returns nothing for unknown UUID" begin
        core = LocalVerisimCore()
        @test fetch_ir_verisim(core, uuid4()) === nothing
    end

    @testset "store with name override" begin
        core = LocalVerisimCore()
        ir   = TangleIR(CrossingIR[]; metadata = TangleMetadata(name = "old-name"))
        store_ir_verisim!(core, ir; name = "new-name")
        fetched = fetch_ir_verisim(core, ir.id)
        @test fetched !== nothing
        @test fetched.metadata.name == "new-name"
    end

    @testset "store with extra tags" begin
        core = LocalVerisimCore()
        ir   = TangleIR(CrossingIR[]; metadata = TangleMetadata(tags = ["a"]))
        store_ir_verisim!(core, ir; tags = ["b", "c"])
        fetched = fetch_ir_verisim(core, ir.id)
        @test fetched !== nothing
        all_tags = fetched.metadata.tags
        @test "a" in all_tags
        @test "b" in all_tags
        @test "c" in all_tags
    end

    @testset "query_ir_verisim — provenance filter" begin
        core = LocalVerisimCore()
        ir_user = TangleIR(CrossingIR[]; metadata = TangleMetadata(provenance = :user))
        ir_rw   = TangleIR(CrossingIR[]; metadata = TangleMetadata(provenance = :rewritten))
        store_ir_verisim!(core, ir_user)
        store_ir_verisim!(core, ir_rw)

        user_ids  = query_ir_verisim(core; provenance = :user)
        rw_ids    = query_ir_verisim(core; provenance = :rewritten)
        all_ids   = query_ir_verisim(core)

        @test ir_user.id in user_ids
        @test ir_rw.id   in rw_ids
        @test !(ir_rw.id in user_ids)
        @test length(all_ids) == 2
    end

    @testset "query_ir_verisim — tag filter" begin
        core = LocalVerisimCore()
        ir_a = TangleIR(CrossingIR[]; metadata = TangleMetadata(tags = ["knot", "prime"]))
        ir_b = TangleIR(CrossingIR[]; metadata = TangleMetadata(tags = ["link"]))
        store_ir_verisim!(core, ir_a)
        store_ir_verisim!(core, ir_b)

        knot_ids = query_ir_verisim(core; tags = ["knot"])
        @test ir_a.id in knot_ids
        @test !(ir_b.id in knot_ids)
        both_ids = query_ir_verisim(core; tags = ["knot", "prime"])
        @test ir_a.id in both_ids
    end

    @testset "query_ir_verisim — crossing_count filter" begin
        core = LocalVerisimCore()
        ir3 = TangleIR(
            [CrossingIR(:c1,+1,(1,2,3,4)),
             CrossingIR(:c2,+1,(5,6,7,8)),
             CrossingIR(:c3,-1,(9,10,11,12))];
            metadata = TangleMetadata(name = "three-crossing")
        )
        ir0 = TangleIR(CrossingIR[]; metadata = TangleMetadata(name = "unknot"))
        store_ir_verisim!(core, ir3)
        store_ir_verisim!(core, ir0)

        ids3 = query_ir_verisim(core; crossing_count = 3)
        ids0 = query_ir_verisim(core; crossing_count = 0)
        @test ir3.id in ids3
        @test ir0.id in ids0
        @test !(ir0.id in ids3)
    end

    @testset "query_ir_verisim — name_prefix filter" begin
        core = LocalVerisimCore()
        ir_tre = TangleIR(CrossingIR[]; metadata = TangleMetadata(name = "trefoil"))
        ir_fig = TangleIR(CrossingIR[]; metadata = TangleMetadata(name = "figure-eight"))
        store_ir_verisim!(core, ir_tre)
        store_ir_verisim!(core, ir_fig)

        @test ir_tre.id in query_ir_verisim(core; name_prefix = "tre")
        @test ir_fig.id in query_ir_verisim(core; name_prefix = "fig")
        @test !(ir_fig.id in query_ir_verisim(core; name_prefix = "tre"))
    end

    @testset "query_ir_verisim — actor filter" begin
        core   = LocalVerisimCore()
        ir_u   = TangleIR(CrossingIR[]; metadata = TangleMetadata(provenance = :user))
        ir_sys = TangleIR(CrossingIR[]; metadata = TangleMetadata(provenance = :derived))
        store_ir_verisim!(core, ir_u)
        store_ir_verisim!(core, ir_sys)

        # provenance symbol becomes actor string in the hash chain.
        @test ir_u.id   in query_ir_verisim(core; actor = "user")
        @test ir_sys.id in query_ir_verisim(core; actor = "derived")
        @test !(ir_sys.id in query_ir_verisim(core; actor = "user"))
    end

    @testset "prove_consonance — same IR is trivially consonant" begin
        core = LocalVerisimCore()
        ir   = _tangle_with_dt("trefoil", [4,6,2])
        store_ir_verisim!(core, ir)

        v = prove_consonance(core, ir, ir)
        @test v isa ConsonanceVerdict
        @test v.consonant == true
        @test v.witness !== nothing
    end

    @testset "prove_consonance — same DT code, different provenance: consonant" begin
        core  = LocalVerisimCore()
        ir1   = _tangle_with_dt("trefoil",    [4,6,2], :user)
        ir2   = _tangle_with_dt("trefoil-rw", [4,6,2], :rewritten)
        store_ir_verisim!(core, ir1)
        store_ir_verisim!(core, ir2)

        v = prove_consonance(core, ir1, ir2)
        @test v.consonant == true
    end

    @testset "prove_consonance — different knot types: not consonant (depth 1)" begin
        core = LocalVerisimCore()
        trefoil  = _tangle_with_dt("trefoil",  [4,6,2])
        figure8  = _tangle_with_dt("figure8",  [4,8,12,2,10,6])
        store_ir_verisim!(core, trefoil)
        store_ir_verisim!(core, figure8)

        # Tropical prover at default depth cannot find a Reidemeister path
        # between topologically distinct knots.
        v = prove_consonance(core, trefoil, figure8)
        @test v.consonant == false
        @test v.reason !== ""
    end

    @testset "prove_consonance — unstored IR returns VerdictFail gracefully" begin
        core  = LocalVerisimCore()
        ir1   = _tangle_with_dt("trefoil", [4,6,2])
        ir2   = _tangle_with_dt("figure8", [4,8,12,2,10,6])
        # Neither stored — prover returns octad-not-found VerdictFail.

        v = prove_consonance(core, ir1, ir2)
        @test v.consonant == false
        @test occursin("not found", v.reason)
    end

    @testset "Identity Persistence: provenance chain grows with re-enrichment" begin
        core  = LocalVerisimCore()
        ir    = _tangle_with_dt("trefoil", [4,6,2], :user; source = "B_1^3")
        store_ir_verisim!(core, ir)

        # Second store call enriches again (same UUID → same OctadId).
        ir2 = TangleIR(
            ir.id, ir.ports_in, ir.ports_out, ir.crossings, ir.components,
            TangleMetadata("trefoil", "Reidemeister III applied",
                           ir.metadata.tags, :rewritten, ir.metadata.extra)
        )
        store_ir_verisim!(core, ir2)

        fetched = fetch_ir_verisim(core, ir.id)
        @test fetched !== nothing
        chain_len = get(fetched.metadata.extra, :provenance_chain_length, 0)
        @test chain_len == 2
    end

    @testset "Phase 4 result: no Federable shapes needed (empty manager)" begin
        # Positive result: the entire lifecycle completes with Manager()
        # reporting zero registered shapes.
        core = LocalVerisimCore()
        @test isempty(Main.FederationManager.registered_shapes(core.manager))

        ir = _tangle_with_dt("hopf-link", [4,2,8,6], :user)
        store_ir_verisim!(core, ir)

        oid     = KRLAdapter._uuid_to_octad_id(ir.id)
        verdict = Main.VCLProver.prove(
            Main.VCLQuery.ProofIntegrity(oid), core.store, core.manager)
        @test verdict isa Main.VCLQuery.VerdictPass
    end

end # @testset "LocalVerisimCore — Phase 4 dogfood"

end # if _VERISIM_LOADED
