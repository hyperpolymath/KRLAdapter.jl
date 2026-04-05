<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Component Readiness — KRLAdapter.jl

**Current Grade:** D
**Assessed:** 2026-04-05
**Standard:** [CRG v2.0 STRICT](../standards/component-readiness-grades/)

## Grade rationale (evidence for D)

Works on some things + RSR compliance present. Fresh package: created 2026-04-05.

### Evidence

- **Tests:** 51 passing (IR construction, operations, trefoil end-to-end roundtrip
  including UUID preservation through Skein store/fetch cycle)
- **Annotation:** 64 docstrings across `src/ir.jl`, `src/operations.jl`,
  `src/adapters/knottheory.jl`, `src/adapters/skein.jl`
- **RSR compliance:** 0-AI-MANIFEST.a2ml, `.machine_readable/6a2/`, 14 workflows,
  SECURITY/CONTRIBUTING/CODE_OF_CONDUCT, .editorconfig
- **Architectural discipline:** Zero modifications to KnotTheory.jl or Skein.jl;
  all KRL-stack-specific logic contained here. Enforced by prompt-level constraint.
- **CI:** Clean; panic-attack assail 0 findings

## Gaps preventing higher grades

### Blocks C (deep code+folder annotation + dogfooded on home project reliably)
- No per-directory READMEs except root README.adoc.
- No EXPLAINME.adoc.
- No TEST-NEEDS.md or PROOF-NEEDS.md.
- No integration testing with the wider KRL stack yet (KRL compiler not ready).
- No benchmark suite for roundtrip performance.
- Only ~1 day of dogfooding — too early to claim C-level reliability.

### Blocks B (6+ diverse external targets)
- Requires C first.
- No JuliaHub registration.
- No external users.

## What to do for C

1. Add EXPLAINME.adoc with honest one-line summary and scope.
2. Add per-directory READMEs for `src/`, `src/adapters/`, `test/`.
3. Add TEST-NEEDS.md documenting test categories covered / uncovered.
4. Run a full week of dogfooding: use KRLAdapter in actual workflows
   (batch-convert knot tables, store via Skein, query back, verify invariants).
5. Track any bugs/surprises found; fix or document.
6. Add a benchmarks/ directory with roundtrip timing.

## What to do for B (after C)

1. Find 6+ diverse external targets with TangleIR-shaped needs.
2. Register on JuliaHub.
3. Track the 6 targets here.

## Review cycle

Reassess after first week of dogfooding, then per release.
