# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using KRLAdapter

@testset "Tangle bridge — pdv1_blob_to_ir" begin
    # Trefoil: three positive crossings sigma_1^3 closed
    # Entries for the canonical PD of trefoil: 3 crossings.
    # Example synthesised blob (matches Tangle's format):
    blob = "pdv1|x=1,2,3,4,1;3,4,5,6,1;5,6,1,2,1|c=1,2,3,4,5,6"
    ir = pdv1_blob_to_ir(blob; name = "trefoil")

    @test crossing_count(ir) == 3
    @test all(c.sign == 1 for c in ir.crossings)
    @test ir.crossings[1].arcs == (1, 2, 3, 4)
    @test ir.crossings[2].arcs == (3, 4, 5, 6)
    @test ir.crossings[3].arcs == (5, 6, 1, 2)
    @test ir.metadata.name == "trefoil"
    @test ir.metadata.provenance === :imported
    @test get(ir.metadata.extra, :source, nothing) === :tangle_pdv1
    @test length(ir.components) == 1
    @test ir.components[1] == [1, 2, 3, 4, 5, 6]
end

@testset "Tangle bridge — pdv1 with negative crossings" begin
    # Figure-eight knot: alternating crossings, two strands
    blob = "pdv1|x=1,2,3,4,1;3,4,5,6,-1;5,6,7,8,1;7,8,1,2,-1|c=1,2,3,4,5,6,7,8"
    ir = pdv1_blob_to_ir(blob; name = "figure_eight")

    @test crossing_count(ir) == 4
    @test ir.crossings[1].sign == 1
    @test ir.crossings[2].sign == -1
    @test ir.crossings[3].sign == 1
    @test ir.crossings[4].sign == -1
end

@testset "Tangle bridge — empty components and crossings" begin
    blob = "pdv1|x=|c="
    ir = pdv1_blob_to_ir(blob)
    @test crossing_count(ir) == 0
    @test isempty(ir.components)
end

@testset "Tangle bridge — multiple components (link)" begin
    # Two-component link: each component has its own arc list
    blob = "pdv1|x=1,2,3,4,1|c=1,2;3,4"
    ir = pdv1_blob_to_ir(blob; name = "hopf_link")

    @test crossing_count(ir) == 1
    @test length(ir.components) == 2
    @test ir.components[1] == [1, 2]
    @test ir.components[2] == [3, 4]
end

@testset "Tangle bridge — malformed blob rejected" begin
    @test_throws ArgumentError pdv1_blob_to_ir("not_pdv1")
    @test_throws ArgumentError pdv1_blob_to_ir("pdv1|x=1,2,3|c=")  # 3 fields, not 5
    @test_throws ArgumentError pdv1_blob_to_ir("pdv1|x=a,b,c,d,e|c=")  # non-numeric
end

@testset "Tangle bridge — source_text stored in metadata" begin
    blob = "pdv1|x=1,2,3,4,1|c=1,2,3,4"
    ir = pdv1_blob_to_ir(blob; name = "example", source_text = "sigma_1")
    @test ir.metadata.source_text == "sigma_1"
    @test ir.metadata.name == "example"
    @test haskey(ir.metadata.extra, :raw_blob)
end

@testset "Tangle bridge — tangle_entries_to_ir direct path" begin
    entries = [(1, 2, 3, 4, 1), (3, 4, 5, 6, -1)]
    components = [[1, 2, 3, 4, 5, 6]]
    ir = tangle_entries_to_ir(entries, components; name = "via_entries")

    @test crossing_count(ir) == 2
    @test ir.crossings[1].sign == 1
    @test ir.crossings[2].sign == -1
    @test ir.crossings[1].arcs == (1, 2, 3, 4)
    @test ir.crossings[2].arcs == (3, 4, 5, 6)
    @test ir.metadata.name == "via_entries"
    @test get(ir.metadata.extra, :source, nothing) === :tangle_entries
    @test ir.components[1] == [1, 2, 3, 4, 5, 6]
end

@testset "Tangle bridge — end-to-end: tangle blob → TangleIR → Skein round-trip" begin
    import Skein

    # Simulate a Tangle compile output: trefoil blob
    blob = "pdv1|x=1,2,3,4,1;3,4,5,6,1;5,6,1,2,1|c=1,2,3,4,5,6"
    ir = pdv1_blob_to_ir(blob; name = "tangle_trefoil", source_text = "sigma_1 ; sigma_1 ; sigma_1")

    @test crossing_count(ir) == 3
    @test KRLAdapter.writhe(ir) == 3  # all positive
    @test ir.metadata.source_text == "sigma_1 ; sigma_1 ; sigma_1"

    # Round-trip through Skein (verified 2026-04-05: tangle arc convention is
    # compatible with KnotTheory's PD format for data-level round-trip)
    db = Skein.SkeinDB(":memory:")
    try
        id = store_ir!(db, ir; name = "tangle_trefoil_stored", tags = ["from_tangle"])
        @test id isa String

        fetched = fetch_ir(db, "tangle_trefoil_stored")
        @test fetched !== nothing
        @test crossing_count(fetched) == crossing_count(ir)
        @test [c.sign for c in fetched.crossings] == [c.sign for c in ir.crossings]
        @test [c.arcs for c in fetched.crossings] == [c.arcs for c in ir.crossings]

        # UUID preservation via metadata encoding
        @test string(fetched.id) == string(ir.id)

        # Source text + tags survive
        @test fetched.metadata.source_text == "sigma_1 ; sigma_1 ; sigma_1"
        @test "from_tangle" in fetched.metadata.tags
    finally
        close(db)
    end
end

@testset "Tangle bridge — alternating signs round-trip (figure-8 shape)" begin
    import Skein

    blob = "pdv1|x=1,2,3,4,1;3,4,5,6,-1;5,6,7,8,1;7,8,1,2,-1|c=1,2,3,4,5,6,7,8"
    ir = pdv1_blob_to_ir(blob; name = "alternating")

    db = Skein.SkeinDB(":memory:")
    try
        store_ir!(db, ir; name = "alt_test")
        fetched = fetch_ir(db, "alt_test")

        @test fetched !== nothing
        @test crossing_count(fetched) == 4
        @test [c.sign for c in fetched.crossings] == [1, -1, 1, -1]
        @test [c.arcs for c in fetched.crossings] == [c.arcs for c in ir.crossings]
    finally
        close(db)
    end
end
