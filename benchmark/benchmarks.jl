# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# KRLAdapter.jl benchmark suite
#
# Run:
#   julia --project=. benchmark/benchmarks.jl
#
# Measures baseline overhead of the KRLAdapter layer over direct
# KnotTheory+Skein calls. Six Sigma classification of results should live
# alongside these numbers once a baseline is established across repo versions.

using KRLAdapter
import KnotTheory
import Skein
using Dates

println("KRLAdapter.jl benchmarks — ", now())
println("=" ^ 60)

function time_ns_repeated(f, repeats::Int)
    # Warm up
    f()
    times = Vector{UInt64}(undef, repeats)
    for i in 1:repeats
        t0 = time_ns()
        f()
        times[i] = time_ns() - t0
    end
    (
        min = minimum(times),
        median = sort(times)[div(repeats, 2) + 1],
        max = maximum(times),
    )
end

function bench(name, f; repeats = 100)
    t = time_ns_repeated(f, repeats)
    # Convert to microseconds for readability
    println(rpad(name, 40),
        lpad("min=$(round(t.min/1000, digits=1))μs", 15),
        lpad("med=$(round(t.median/1000, digits=1))μs", 15),
        lpad("max=$(round(t.max/1000, digits=1))μs", 15))
end

# ---------- Construction ----------

println("\n[Construction]")
bench("trefoil_ir()", () -> trefoil_ir())
bench("figure_eight_ir()", () -> figure_eight_ir())
bench("unknot_ir()", () -> unknot_ir())

# ---------- IR → PD → IR roundtrip ----------

println("\n[Conversion]")
ir = trefoil_ir()
bench("pd_to_ir(trefoil.pd)", () -> pd_to_ir(KnotTheory.trefoil().pd))
bench("ir_to_pd(trefoil_ir)", () -> ir_to_pd(ir))

# ---------- Invariants via KnotTheory adapter ----------

println("\n[Invariants via adapter]")
bench("alexander(trefoil)", () -> alexander(ir); repeats = 20)
bench("jones(trefoil)", () -> jones(ir); repeats = 20)
bench("determinant(trefoil)", () -> KRLAdapter.determinant(ir); repeats = 50)
bench("signature(trefoil)", () -> KRLAdapter.signature(ir); repeats = 20)

# ---------- Operations (pure TangleIR, no KnotTheory) ----------

println("\n[Operations — pure TangleIR]")
bench("mirror(trefoil)", () -> mirror(ir))
bench("mirror(mirror(trefoil))", () -> mirror(mirror(ir)))

ir_a = TangleIR([CrossingIR(:a, 1, (1, 2, 3, 4))]; ports_in=[Port(:p, :top, 0, :in)], ports_out=[Port(:q, :bottom, 0, :out)])
ir_b = TangleIR([CrossingIR(:b, -1, (1, 2, 3, 4))]; ports_in=[Port(:r, :top, 0, :in)], ports_out=[Port(:s, :bottom, 0, :out)])
bench("compose(a, b)", () -> compose(ir_a, ir_b))
bench("tensor(a, b)", () -> tensor(ir_a, ir_b))
bench("close_tangle(compose(a,b))", () -> close_tangle(compose(ir_a, ir_b)))

# ---------- Skein adapter (in-memory) ----------

println("\n[Skein adapter — in-memory DB]")
db = Skein.SkeinDB(":memory:")

# store_ir! uses unique names; wrap in counter
name_counter = Ref(0)
bench("store_ir!(trefoil)", () -> begin
    name_counter[] += 1
    store_ir!(db, ir; name = "bench_trefoil_$(name_counter[])")
end; repeats = 30)

# Store one known record for fetch benchmarks
store_ir!(db, ir; name = "bench_fixed")
bench("fetch_ir(existing)", () -> fetch_ir(db, "bench_fixed"); repeats = 50)
bench("query_ir(crossing=3)", () -> query_ir(db; crossing_number = 3); repeats = 50)

close(db)

println("\n" * "=" ^ 60)
println("Baseline established. Re-run after changes to detect regressions.")
println("Six Sigma classification: deferred until baseline stored.")
