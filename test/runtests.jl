# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using KRLAdapter

@testset "KRLAdapter" begin
    include("ir_test.jl")
    include("operations_test.jl")
    include("adapter_roundtrip.jl")
    include("property_test.jl")
    include("fuzz_smoke.jl")
end
