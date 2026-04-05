<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Next-Session Notes — KRL Stack

**Origin:** session 2026-04-05 (Claude Opus 4.6, 1M context). Left as a
hand-off for future Claude sessions working on the KRL stack.

## Where we left off

### KRLAdapter.jl: grade C

- 5,472 tests passing (unit + E2E + property-based × 100 iter + fuzz smoke × 500 iter + roundtrip + tangle bridge + verisim stub)
- 4 adapters: knottheory, skein, tangle, verisim (stub)
- Documented + benchmarked + example-verified
- On GitHub: https://github.com/hyperpolymath/KRLAdapter.jl
- Missing: JuliaHub registration, external-project dogfood evidence

### tangle→TangleIR bridge: working

- `pdv1_blob_to_ir` parses Tangle's compositional PD output
- Round-trip through Skein verified (data-level) for trefoil + alternating-signs
- Semantic caveat: invariants on tangle-sourced IRs are only meaningful
  if Tangle emits canonically-correct PD codes (needs E2E test with real
  Tangle compiler invocation)

### VerisimCore adapter: stub in place

- `AbstractVerisimCore` type + 4 stub methods (store/fetch/query/prove_consonance)
- Throws `VerisimCoreNotWiredError` with experiment pointer until wired
- Ready for Phase 4 of verisim-modular-experiment — see session note at
  `nextgen-databases/verisim-modular-experiment/docs/sessions/2026-04-05-krladapter-phase4-prep.adoc`

### KRL language: grade E

- Grammar drafted (EBNF v0.1.0) at `krl/spec/grammar.ebnf`
- 4 example programs covering CONSTRUCT/TRANSFORM/RESOLVE/RETRIEVE
- Smoke test: 16 lexical checks, all passing
- No parser yet. Path to D needs parser implementation language decision.

## Critical constraints (DO NOT VIOLATE)

1. **KnotTheory.jl and Skein.jl are READ-ONLY community libraries.** All
   KRL-stack integration lives in KRLAdapter.jl. If tempted to edit a file
   in either, STOP and use an adapter instead.
   See memory: `feedback_krl_adapter_boundary.md`.

2. **verisimdb main repo is other-claude's primary target.** Only touch
   for explicitly-approved foldback items from
   `nextgen-databases/verisim-modular-experiment/docs/FOLDBACK.adoc`.
   Both known foldback items applied in this session.

3. **VQL is now VCL.** Don't use VQL in new writing.

4. **KRL is pronounced "curl".** README should hint at this.

## Open architectural questions (for user decision)

1. **KRL parser language:** Tangle OCaml / KRLAdapter Julia / sibling OCaml?
   See `krl/spec/grammar-overview.md`.
2. **tangle → TangleIR semantic validation:** how to invoke tangle's
   compiler from Julia for E2E tests? Subprocess? Ship tangle-wasm
   via WebAssembly.jl?
3. **Task #6 — PanLL wiring:** which client? which integration shape?
   Still unspecified.

## Session summary in numbers

- **24 commits** across 7 repos this session
- **2 new GitHub repos** created (KRLAdapter.jl, krl)
- **29 doc files** added (READMEs / READINESS / EXPLAINME / TEST-NEEDS / PROOF-NEEDS / examples / benchmarks / CHANGELOG / session notes)
- **4 new memory files** indexed
- **2 foldback items applied** to verisimdb
- **16,000+ lines added** (code, docs, tests, scaffolds)

## Desktop continuation list

See `~/Desktop/KRL-STACK-NEXT-SESSION.md` for the priority-ordered queue.
