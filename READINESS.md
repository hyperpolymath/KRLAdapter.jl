<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Component Readiness — KRLAdapter.jl

**Current Grade:** C
**Assessed:** 2026-04-05 (updated after iteration 3)
**Standard:** [CRG v2.0 STRICT](../standards/component-readiness-grades/)

## Grade rationale (evidence for C — promoted from D after 3 iterations)

Works reliably on own project + annotated + dogfooded via its own test suite.

### Evidence

- **Tests:** 5,405 passing (unit + E2E + property-based + fuzz smoke)
- **Annotation:** 64 docstrings + EXPLAINME.adoc + TEST-NEEDS.md + per-directory
  READMEs (`src/`, `src/adapters/`, `test/`, `benchmark/`, `examples/`)
- **Examples:** 4 runnable examples, all verified to execute
- **Benchmarks:** Baseline established for 14 operations (μs-scale)
- **RSR compliance:** 0-AI-MANIFEST.a2ml, `.machine_readable/6a2/`, 14 workflows,
  SECURITY/CONTRIBUTING/CODE_OF_CONDUCT, .editorconfig
- **Architectural discipline:** Zero modifications to KnotTheory.jl or Skein.jl.
  Enforced by session-level constraint memory.
- **Dogfooding:** Self-dogfood extensive — 11 algebraic properties × 100 iterations,
  5 fuzz loops × 200-500 iterations. External-project dogfood still ~1 day (this
  limits how strongly "C" can be claimed).
- **CI:** Clean; panic-attack assail 0 findings

## Gaps preventing higher grades

### Blocks B (6+ diverse external targets)
- No JuliaHub registration yet.
- No external users beyond own test suite.
- Only 1 day of use in real workflows beyond the test suite.

## What would push toward B

1. Find 6+ diverse external targets with TangleIR-shaped needs (knot theorists,
   topology researchers, compositional DSL builders).
2. Register on JuliaHub General registry.
3. Track the 6 targets here with per-target trial evidence.
4. Collect + fold back external bug reports.

## Iteration history

### Iteration 0 (D grade — initial commit)
51 tests, root README only, no EXPLAINME, no examples, no benchmarks.

### Iteration 1 (still D — 2026-04-05)
Added: EXPLAINME.adoc, examples/ (4 runnable), benchmark/benchmarks.jl baseline.

### Iteration 2 (still D — 2026-04-05)
Added: test/property_test.jl (11 properties × 100 iter), test/fuzz_smoke.jl
(5 loops × 200-500 iter), TEST-NEEDS.md. Test count: 51 → 5,405.

### Iteration 3 (promoted to C — 2026-04-05)
Added: per-directory READMEs for src/, src/adapters/, test/, benchmark/.
Now has deep code+folder annotation per CRG v2 STRICT C criterion.

## Review cycle

Reassess if external-target evidence accumulates (→ B), or if dogfooding
reveals problems that demote back to D.
