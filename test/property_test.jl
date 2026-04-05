# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Property-based tests for TangleIR operations.
# Not using a dedicated property-testing framework; roll our own random
# generator + invariant assertions to stay dependency-free.

using Test
using KRLAdapter
using Random

const SEED = 20260405
const ITERATIONS = 100

"Random well-formed closed-diagram TangleIR with n crossings."
function random_closed_ir(rng::AbstractRNG, n::Int)
    crossings = CrossingIR[
        CrossingIR(
            Symbol("c", i),
            rand(rng, (-1, 1)),
            (4i - 3, 4i - 2, 4i - 1, 4i),
        )
        for i in 1:n
    ]
    TangleIR(crossings)
end

"Random open tangle with matching ports on top and bottom."
function random_open_ir(rng::AbstractRNG, n::Int, port_count::Int)
    crossings = CrossingIR[
        CrossingIR(
            Symbol("c", i),
            rand(rng, (-1, 1)),
            (4i - 3, 4i - 2, 4i - 1, 4i),
        )
        for i in 1:n
    ]
    ports_in = [Port(Symbol("in", k), :top, k - 1, :in) for k in 1:port_count]
    ports_out = [Port(Symbol("out", k), :bottom, k - 1, :out) for k in 1:port_count]
    TangleIR(crossings; ports_in = ports_in, ports_out = ports_out)
end

@testset "Property: mirror is an involution (sign-wise)" begin
    rng = MersenneTwister(SEED)
    for _ in 1:ITERATIONS
        n = rand(rng, 0:8)
        ir = random_closed_ir(rng, n)
        mm = mirror(mirror(ir))
        @test length(mm.crossings) == length(ir.crossings)
        for (c_orig, c_mm) in zip(ir.crossings, mm.crossings)
            @test c_orig.sign == c_mm.sign
            @test c_orig.arcs == c_mm.arcs
        end
    end
end

@testset "Property: mirror flips every crossing sign" begin
    rng = MersenneTwister(SEED + 1)
    for _ in 1:ITERATIONS
        n = rand(rng, 0:8)
        ir = random_closed_ir(rng, n)
        m = mirror(ir)
        for (c_orig, c_m) in zip(ir.crossings, m.crossings)
            @test c_m.sign == -c_orig.sign
        end
    end
end

@testset "Property: writhe(mirror(ir)) == -writhe(ir)" begin
    rng = MersenneTwister(SEED + 2)
    for _ in 1:ITERATIONS
        ir = random_closed_ir(rng, rand(rng, 0:8))
        @test KRLAdapter.writhe(mirror(ir)) == -KRLAdapter.writhe(ir)
    end
end

@testset "Property: mirror preserves crossing count" begin
    rng = MersenneTwister(SEED + 3)
    for _ in 1:ITERATIONS
        n = rand(rng, 0:8)
        ir = random_closed_ir(rng, n)
        @test crossing_count(mirror(ir)) == n
    end
end

@testset "Property: tensor is additive in crossing count" begin
    rng = MersenneTwister(SEED + 4)
    for _ in 1:ITERATIONS
        na = rand(rng, 0:6)
        nb = rand(rng, 0:6)
        a = random_closed_ir(rng, na)
        b = random_closed_ir(rng, nb)
        t = tensor(a, b)
        @test crossing_count(t) == na + nb
    end
end

@testset "Property: tensor renumbers b's arcs above a's max" begin
    rng = MersenneTwister(SEED + 5)
    for _ in 1:ITERATIONS
        na = rand(rng, 1:6)   # a must have at least 1 crossing for max_arc to be defined
        nb = rand(rng, 1:6)
        a = random_closed_ir(rng, na)
        b = random_closed_ir(rng, nb)
        t = tensor(a, b)
        max_a = maximum(maximum(c.arcs) for c in a.crossings)
        # All crossings from b (after the first na) should have arcs > max_a
        for i in (na + 1):length(t.crossings)
            @test minimum(t.crossings[i].arcs) > max_a
        end
    end
end

@testset "Property: compose with matching ports sums crossings" begin
    rng = MersenneTwister(SEED + 6)
    for _ in 1:ITERATIONS
        na = rand(rng, 0:5)
        nb = rand(rng, 0:5)
        pc = rand(rng, 1:3)
        a = random_open_ir(rng, na, pc)
        b = random_open_ir(rng, nb, pc)
        c = compose(a, b)
        @test crossing_count(c) == na + nb
    end
end

@testset "Property: compose rejects mismatched port counts" begin
    rng = MersenneTwister(SEED + 7)
    for _ in 1:50
        pa = rand(rng, 1:4)
        pb = rand(rng, 1:4)
        pa == pb && continue
        a = random_open_ir(rng, 1, pa)
        b = random_open_ir(rng, 1, pb)
        @test_throws ArgumentError compose(a, b)
    end
end

@testset "Property: close_tangle makes ports empty when inputs match" begin
    rng = MersenneTwister(SEED + 8)
    for _ in 1:ITERATIONS
        n = rand(rng, 0:6)
        pc = rand(rng, 1:4)
        a = random_open_ir(rng, n, pc)
        closed = close_tangle(a)
        @test is_closed(closed)
        @test crossing_count(closed) == n
    end
end

@testset "Property: close_tangle rejects mismatched port counts" begin
    rng = MersenneTwister(SEED + 9)
    n = 2
    # Manually construct asymmetric port IRs
    a_asym = TangleIR(
        CrossingIR[];
        ports_in = [Port(:p, :top, 0, :in)],
        ports_out = [Port(:q, :bottom, 0, :out), Port(:r, :bottom, 1, :out)],
    )
    @test_throws ArgumentError close_tangle(a_asym)
end

@testset "Property: derivation records :derived provenance" begin
    rng = MersenneTwister(SEED + 10)
    for _ in 1:50
        a = random_closed_ir(rng, rand(rng, 1:4))
        b = random_closed_ir(rng, rand(rng, 1:4))
        @test mirror(a).metadata.provenance === :derived
        @test tensor(a, b).metadata.provenance === :derived
    end
end

@testset "Property: UUIDs are unique per construction" begin
    rng = MersenneTwister(SEED + 11)
    ids = Set{Any}()
    for _ in 1:200
        ir = random_closed_ir(rng, rand(rng, 0:3))
        push!(ids, ir.id)
    end
    @test length(ids) == 200
end
