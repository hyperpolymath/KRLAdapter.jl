# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Example 03: compositional operations on TangleIR
#
# Demonstrates compose / tensor / close_tangle / mirror on open tangles,
# including port-based composition and arc renumbering.

using KRLAdapter

println("-- compositional operations --")

# Build two open tangles, each with one port in and one port out
a = TangleIR(
    CrossingIR[CrossingIR(:x, 1, (1, 2, 3, 4))];
    ports_in = [Port(:top, :top, 0, :in)],
    ports_out = [Port(:bot, :bottom, 0, :out)],
)

b = TangleIR(
    CrossingIR[CrossingIR(:y, -1, (1, 2, 3, 4))];
    ports_in = [Port(:top, :top, 0, :in)],
    ports_out = [Port(:bot, :bottom, 0, :out)],
)

# Sequential composition (a then b)
composed = compose(a, b)
println("compose: $(crossing_count(a)) + $(crossing_count(b)) → $(crossing_count(composed))")
println("  signs: $([c.sign for c in composed.crossings])")
println("  operation tag: $(get(composed.metadata.extra, :operation, nothing))")

# Tensor (side by side)
tensored = tensor(a, b)
println("\ntensor: $(crossing_count(a)) | $(crossing_count(b)) → $(crossing_count(tensored))")
println("  arc renumbering in b: $(tensored.crossings[2].arcs)")

# Closure of composed (requires matching port counts)
closed = close_tangle(composed)
println("\nclose_tangle: is_closed = $(KRLAdapter.is_closed(closed))")

# Mirror flips signs on everything
m = mirror(composed)
println("\nmirror(compose): $([c.sign for c in m.crossings])")

println("-- done --")
