# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using KRLAdapter
import KnotTheory
import Skein

@testset "Adapter roundtrip — trefoil end-to-end" begin
    # Build trefoil as TangleIR via KnotTheory adapter
    ir = trefoil_ir()
    @test ir.metadata.name == "trefoil"
    @test crossing_count(ir) == 3
    @test is_closed(ir)

    # Compute invariants via KnotTheory adapter
    j = jones(ir)
    det = KRLAdapter.determinant(ir)
    @test det == 3  # trefoil determinant is 3
    @test KRLAdapter.signature(ir) != 0  # trefoil is chiral

    # Persist via Skein adapter
    db = Skein.SkeinDB(":memory:")
    id = store_ir!(db, ir; name = "krl_trefoil", tags = ["test", "knot_3_1"])
    @test id isa String

    # Fetch back
    fetched = fetch_ir(db, "krl_trefoil")
    @test fetched !== nothing
    @test fetched.metadata.name == "krl_trefoil"
    @test crossing_count(fetched) == crossing_count(ir)
    @test "test" in fetched.metadata.tags
    @test "knot_3_1" in fetched.metadata.tags

    # Round-trip IR UUID preservation
    @test string(fetched.id) == string(ir.id)

    # Verify invariants agree across the roundtrip
    j2 = jones(fetched)
    @test string(j2) == string(j)
    @test KRLAdapter.determinant(fetched) == det

    # Query by crossing_number should find the stored record
    matches = query_ir(db; crossing_number = 3)
    @test "krl_trefoil" in matches

    close(db)
end

@testset "Mirror inverts crossing signs + determinant unchanged" begin
    ir = trefoil_ir()
    m = mirror(ir)
    # Mirror trefoil: all crossings sign-flipped
    for (c_orig, c_mirror) in zip(ir.crossings, m.crossings)
        @test c_mirror.sign == -c_orig.sign
    end
    # Determinant is mirror-invariant
    @test KRLAdapter.determinant(m) == KRLAdapter.determinant(ir)
end

@testset "Simplify returns TangleIR with :rewritten provenance" begin
    ir = trefoil_ir()
    simplified = simplify(ir)
    @test simplified isa TangleIR
    @test simplified.metadata.provenance === :rewritten
    @test get(simplified.metadata.extra, :operation, nothing) === :simplify
    @test get(simplified.metadata.extra, :parent_id, nothing) == ir.id
    # Simplification should not increase crossing count
    @test crossing_count(simplified) <= crossing_count(ir)
end
