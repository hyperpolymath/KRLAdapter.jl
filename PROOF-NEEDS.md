<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# PROOF-NEEDS — KRLAdapter.jl

This package has no formal proof obligations at present. Property-based
tests stand in for proof in the near term; formal proofs would follow if
the adapter becomes load-bearing for verified KRL compilation.

## Currently verified (by property-based tests, 100+ iterations each)

| Property | Test | Confidence |
|---|---|---|
| `mirror(mirror(ir)) == ir` sign-and-arc wise | `test/property_test.jl` | property-tested |
| `mirror(ir)` flips every crossing sign | `test/property_test.jl` | property-tested |
| `writhe(mirror(ir)) == -writhe(ir)` | `test/property_test.jl` | property-tested |
| `crossing_count(mirror(ir)) == crossing_count(ir)` | `test/property_test.jl` | property-tested |
| `crossing_count(tensor(a, b)) == na + nb` | `test/property_test.jl` | property-tested |
| `compose` with matching ports sums crossings | `test/property_test.jl` | property-tested |
| `compose` rejects mismatched port counts | `test/property_test.jl` | property-tested |
| `close_tangle` makes ports empty | `test/property_test.jl` | property-tested |
| TangleIR UUIDs are unique per construction | `test/property_test.jl` | property-tested |
| UUID round-trips through Skein store/fetch | `test/adapter_roundtrip.jl` | example-tested |

## Would benefit from formal proof (not currently proved)

### P1. Tensor is monoidal
Statement: `tensor(tensor(a, b), c)` ≅ `tensor(a, tensor(b, c))` up to arc
relabelling. I.e. tensor is associative on TangleIR modulo renumbering.

Current status: not tested, not proved. Would need to define an arc-relabelling
equivalence relation on TangleIR first.

### P2. Compose is associative (when ports match)
Statement: `compose(compose(a, b), c) == compose(a, compose(b, c))` when port
counts align throughout.

Current status: not tested, not proved. Same arc-relabelling caveat.

### P3. Compose/tensor commute with mirror
Statement: `mirror(compose(a, b)) == compose(mirror(a), mirror(b))` and
similarly for tensor.

Current status: plausible; not proved. Would validate that KRLAdapter's
compositional operations respect the knot-theoretic mirror-reflection
structure.

### P4. Skein storage is injective modulo metadata
Statement: Two distinct TangleIRs with the same name, crossings, and
components produce the same Skein record content (modulo timestamps and UUIDs).

Current status: not directly tested. The metadata scheme implies this, but
not asserted by tests.

## Would require KRL language proofs (deferred until KRL exists)

- KRL source → TanglePL AST parse correctness (will live in `tangle/` repo proofs)
- TanglePL AST → TangleIR compilation correctness
- Commutation: `compile(parse(source)) == ir` iff source defines ir

These obligations belong to the `tangle/` and `krl/` repos, not here.

## How to propose a new obligation

1. State the claim precisely in this file.
2. Either add a property-based test that exercises it, or write the proof
   in a proof system (Idris2 or Lean 4) under `verification/` if one exists.
3. Update the "Currently verified" table when discharged.
