# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Fuzz smoke tests — generate random inputs and verify operations don't
# crash on well-formed data. Not a replacement for proper property testing,
# but catches panics and throws from edge-case crossings/arcs/ports.

using Test
using KRLAdapter
using Random

const FUZZ_SEED = 42
const FUZZ_ITERATIONS = 500

@testset "Fuzz: TangleIR construction never crashes on well-formed input" begin
    rng = MersenneTwister(FUZZ_SEED)
    for _ in 1:FUZZ_ITERATIONS
        n_crossings = rand(rng, 0:20)
        crossings = CrossingIR[
            CrossingIR(
                Symbol("f", i, "_", rand(rng, 1:1000)),
                rand(rng, (-1, 1)),
                Tuple(rand(rng, 1:1000, 4)),
            )
            for i in 1:n_crossings
        ]
        # Should not throw
        ir = TangleIR(crossings)
        @test ir isa TangleIR
        @test length(ir.crossings) == n_crossings
    end
end

@testset "Fuzz: mirror never crashes on random crossings" begin
    rng = MersenneTwister(FUZZ_SEED + 1)
    for _ in 1:FUZZ_ITERATIONS
        n = rand(rng, 0:15)
        crossings = CrossingIR[
            CrossingIR(:c, rand(rng, (-1, 1)), Tuple(rand(rng, -100:100, 4)))
            for _ in 1:n
        ]
        ir = TangleIR(crossings)
        m = mirror(ir)
        @test length(m.crossings) == n
    end
end

@testset "Fuzz: tensor is safe with empty or random tangles" begin
    rng = MersenneTwister(FUZZ_SEED + 2)
    for _ in 1:FUZZ_ITERATIONS
        na = rand(rng, 0:10)
        nb = rand(rng, 0:10)
        a_crossings = CrossingIR[
            CrossingIR(:a, rand(rng, (-1, 1)), (4i - 3, 4i - 2, 4i - 1, 4i))
            for i in 1:na
        ]
        b_crossings = CrossingIR[
            CrossingIR(:b, rand(rng, (-1, 1)), (4i - 3, 4i - 2, 4i - 1, 4i))
            for i in 1:nb
        ]
        a = TangleIR(a_crossings)
        b = TangleIR(b_crossings)
        t = tensor(a, b)
        @test crossing_count(t) == na + nb
    end
end

@testset "Fuzz: close_tangle is safe when port counts match" begin
    rng = MersenneTwister(FUZZ_SEED + 3)
    for _ in 1:FUZZ_ITERATIONS
        pc = rand(rng, 1:6)
        ports_in = [Port(Symbol("i", k), :top, k - 1, :in) for k in 1:pc]
        ports_out = [Port(Symbol("o", k), :bottom, k - 1, :out) for k in 1:pc]
        ir = TangleIR(CrossingIR[]; ports_in = ports_in, ports_out = ports_out)
        closed = close_tangle(ir)
        @test is_closed(closed)
    end
end

@testset "Fuzz: metadata extras survive random dict contents" begin
    rng = MersenneTwister(FUZZ_SEED + 4)
    for _ in 1:200
        extra = Dict{Symbol,Any}()
        for _ in 1:rand(rng, 0:5)
            extra[Symbol("k", rand(rng, 1:1000))] = rand(rng, (42, "str", :sym, true, 3.14))
        end
        meta = TangleMetadata(
            name = rand(rng, (nothing, "name$(rand(rng, 1:100))")),
            provenance = rand(rng, (:user, :derived, :rewritten, :imported)),
            extra = extra,
        )
        ir = TangleIR(CrossingIR[]; metadata = meta)
        @test ir.metadata.provenance in (:user, :derived, :rewritten, :imported)
        @test ir.metadata.extra == extra
    end
end
