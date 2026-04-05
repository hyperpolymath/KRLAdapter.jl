# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using KRLAdapter
using UUIDs

@testset "TangleIR construction" begin
    c1 = CrossingIR(:c1, 1, (1, 2, 3, 4))
    c2 = CrossingIR(:c2, -1, (3, 4, 5, 6))
    ir = TangleIR([c1, c2])

    @test ir.id isa UUID
    @test length(ir.crossings) == 2
    @test is_closed(ir)
    @test crossing_count(ir) == 2
    @test KRLAdapter.writhe(ir) == 0  # +1 + -1
end

@testset "TangleMetadata defaults" begin
    meta = TangleMetadata()
    @test meta.name === nothing
    @test meta.source_text === nothing
    @test isempty(meta.tags)
    @test meta.provenance === :user
    @test isempty(meta.extra)
end

@testset "Port construction" begin
    p = Port(:p1, :top, 0, :in)
    @test p.id === :p1
    @test p.side === :top
    @test p.index == 0
    @test p.orientation === :in
end
