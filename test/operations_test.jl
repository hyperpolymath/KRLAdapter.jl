# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using KRLAdapter

@testset "mirror flips crossing signs" begin
    c1 = CrossingIR(:c1, 1, (1, 2, 3, 4))
    c2 = CrossingIR(:c2, -1, (3, 4, 5, 6))
    ir = TangleIR([c1, c2])

    m = mirror(ir)
    @test length(m.crossings) == 2
    @test m.crossings[1].sign == -1
    @test m.crossings[2].sign == 1
    @test m.metadata.provenance === :derived
end

@testset "mirror is an involution" begin
    c1 = CrossingIR(:c1, 1, (1, 2, 3, 4))
    ir = TangleIR([c1])
    mm = mirror(mirror(ir))
    @test mm.crossings[1].sign == ir.crossings[1].sign
end

@testset "compose requires matching port counts" begin
    a = TangleIR(CrossingIR[]; ports_out = [Port(:p, :bottom, 0, :out)])
    b = TangleIR(CrossingIR[]; ports_in = [Port(:q, :top, 0, :in)])
    c = compose(a, b)
    @test c.metadata.provenance === :derived
    @test get(c.metadata.extra, :operation, nothing) === :compose

    bad = TangleIR(CrossingIR[]; ports_in = [Port(:r, :top, 0, :in), Port(:s, :top, 1, :in)])
    @test_throws ArgumentError compose(a, bad)
end

@testset "tensor disjoint-union shifts arcs" begin
    c1 = CrossingIR(:c1, 1, (1, 2, 3, 4))
    c2 = CrossingIR(:c2, 1, (1, 2, 3, 4))
    a = TangleIR([c1])
    b = TangleIR([c2])

    t = tensor(a, b)
    @test length(t.crossings) == 2
    # a's crossing retains arcs 1-4; b's crossing shifts by 4
    @test t.crossings[1].arcs == (1, 2, 3, 4)
    @test t.crossings[2].arcs == (5, 6, 7, 8)
end

@testset "close_tangle empties ports" begin
    a = TangleIR(CrossingIR[];
        ports_in = [Port(:p, :top, 0, :in)],
        ports_out = [Port(:q, :bottom, 0, :out)])
    closed = close_tangle(a)
    @test is_closed(closed)
    @test closed.metadata.provenance === :derived
end
