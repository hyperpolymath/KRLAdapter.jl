# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Example 04: populate a Skein DB and query by invariant
#
# Show that query_ir returns record names; each name can be round-tripped
# back to TangleIR via fetch_ir.

using KRLAdapter
import Skein

println("-- query by invariant --")

db = Skein.SkeinDB(":memory:")

# Populate with a few IRs
for (ir, name) in [
    (trefoil_ir(), "trefoil"),
    (figure_eight_ir(), "figure_eight"),
    (mirror(trefoil_ir()), "trefoil_mirror"),
]
    id = store_ir!(db, ir; name = name, tags = [name])
    det = KRLAdapter.determinant(ir)
    println("stored $name: det=$det id=$id")
end

println("\n-- queries --")
three_crossers = query_ir(db; crossing_number = 3)
println("crossing_number=3: $three_crossers")

four_crossers = query_ir(db; crossing_number = 4)
println("crossing_number=4: $four_crossers")

det3 = query_ir(db; determinant = 3)
println("determinant=3:    $det3")

det5 = query_ir(db; determinant = 5)
println("determinant=5:    $det5")

# Round-trip one match back to TangleIR
if !isempty(det3)
    name = first(det3)
    ir = fetch_ir(db, name)
    println("\nfetched first det=3 result '$name': $(crossing_count(ir)) crossings")
end

close(db)
println("-- done --")
