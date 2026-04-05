# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Example 01: trefoil end-to-end roundtrip
#
# Build a trefoil TangleIR, compute Jones polynomial via KnotTheory adapter,
# store in Skein, fetch back, verify invariants + UUID preserved.

using KRLAdapter
import Skein

println("-- trefoil roundtrip --")

# Build TangleIR for the trefoil using KnotTheory's built-in knot table
ir = trefoil_ir()
println("constructed trefoil: $(crossing_count(ir)) crossings, id=$(ir.id)")

# Compute invariants via KnotTheory adapter
j = jones(ir)
det = KRLAdapter.determinant(ir)
sig = KRLAdapter.signature(ir)
println("jones polynomial: $j")
println("determinant: $det  (expected 3)")
println("signature: $sig  (nonzero — trefoil is chiral)")

# Persist in Skein (in-memory DB for the example)
db = Skein.SkeinDB(":memory:")
record_id = store_ir!(db, ir; name = "example_trefoil", tags = ["3_1", "prime"])
println("stored with record id: $record_id")

# Fetch back as TangleIR
fetched = fetch_ir(db, "example_trefoil")
println("fetched crossing_count: $(crossing_count(fetched))")
println("UUID preserved: $(string(fetched.id) == string(ir.id))")

# Verify invariants agree
@assert string(jones(fetched)) == string(j)
@assert KRLAdapter.determinant(fetched) == det
println("all invariants agree across roundtrip ✓")

# Query by crossing number
matches = query_ir(db; crossing_number = 3)
println("records with crossing_number=3: $matches")

close(db)
println("-- done --")
