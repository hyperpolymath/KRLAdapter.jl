# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
QuandleDB adapter — nqc KQL pathway (Task #6, Phase 5).

## Architecture

KRLAdapter.jl uses the QuandleDB HTTP server directly, mirroring the wire
protocol established by the `nqc` Gleam client (nextgen-databases/nqc):

    POST /api/query       {query: "<KRL text>", format: "krl"}  → JSON
    GET  /api/knots/<name>                                       → JSON
    GET  /api/semantic-equivalents/<name>                        → JSON

The nqc profile for QuandleDB (`kql_profile()`) lists `/kql/execute` as the
execute path and port 8082. The current QuandleDB server implementation uses
`/api/query` and defaults to port 8080.  `NqcQuandleDB()` defaults to 8080.
When the server migrates to the nqc-canonical path, update `execute_path`.

## Read-only contract

The QuandleDB HTTP server is **read-only** by design. Mutations (inserting new
knots) go through Skein.jl directly, outside this adapter. `store_knot!`
raises `QuandleDBReadOnlyError` to make this constraint explicit.

## Prerequisite

HTTP.jl and JSON3.jl must be loaded (they are package deps).  The QuandleDB
server must be running and reachable at the configured host:port.

## KRL query format

Queries use the KRL pipeline syntax (see quandledb/spec/grammar.ebnf):

    from knots
    | filter name == "3_1"
    | return name, crossing_number, jones_polynomial

Equivalence queries use `find_equivalent` with a knot reference:

    from knots
    | find_equivalent "3_1" via [jones, alexander]
    | return equivalences with provenance
"""

using HTTP
using JSON3
using UUIDs

export AbstractQuandleDB, QuandleDBNotWiredError, QuandleDBReadOnlyError
export query_equivalence, classify_knot, fetch_knot, store_knot!
export NqcQuandleDB, EquivalenceResult

# ---------------------------------------------------------------------------
# Abstract interface
# ---------------------------------------------------------------------------

"""
    AbstractQuandleDB

Marker supertype for concrete QuandleDB client implementations.
Subtype this to supply a custom client (e.g. mock for testing).
For the real QuandleDB HTTP server, use `NqcQuandleDB`.
"""
abstract type AbstractQuandleDB end

"""
    QuandleDBNotWiredError

Thrown by stub methods when no concrete `AbstractQuandleDB` method is
defined for the given type.
"""
struct QuandleDBNotWiredError <: Exception
    method_name::String
end

function Base.showerror(io::IO, e::QuandleDBNotWiredError)
    print(io, "QuandleDBNotWiredError: $(e.method_name) called on a type ",
          "that has not overridden this method.\n\n")
    print(io, "Use NqcQuandleDB() for the real QuandleDB HTTP server, or\n")
    print(io, "subtype AbstractQuandleDB and implement the 4 methods.")
end

"""
    QuandleDBReadOnlyError

Thrown by `store_knot!` because the QuandleDB HTTP server is read-only.
Mutations go through Skein.jl directly.
"""
struct QuandleDBReadOnlyError <: Exception end

function Base.showerror(io::IO, ::QuandleDBReadOnlyError)
    print(io, "QuandleDBReadOnlyError: The QuandleDB HTTP server is read-only ",
          "by design.\n\n")
    print(io, "To insert knots into QuandleDB, use Skein.jl directly:\n")
    print(io, "  using Skein; db = SkeinDB(path); store_ir!(db, ir)\n")
    print(io, "The QuandleDB server's semantic index is updated lazily on next query.")
end

# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------

"""
    EquivalenceResult

Candidates returned by `query_equivalence`.

# Fields
- `name::String`: knot name used as the query reference
- `strong_candidates::Vector{String}`: topologically very likely equivalents
- `weak_candidates::Vector{String}`: plausible but lower-confidence candidates
- `combined_candidates::Vector{String}`: union of strong + weak
- `descriptor_hash::Union{String,Nothing}`: quandle descriptor hash for the query knot
- `quandle_key::Union{String,Nothing}`: quandle-key for the query knot
"""
struct EquivalenceResult
    name::String
    strong_candidates::Vector{String}
    weak_candidates::Vector{String}
    combined_candidates::Vector{String}
    descriptor_hash::Union{String,Nothing}
    quandle_key::Union{String,Nothing}
end

# ---------------------------------------------------------------------------
# Stub methods
# ---------------------------------------------------------------------------

"""
    query_equivalence(db::AbstractQuandleDB, ir::TangleIR) -> EquivalenceResult

Query QuandleDB for knots that are structurally equivalent to the given IR.

Uses `/api/semantic-equivalents/<name>` when the IR carries a `:knot_name`
in its metadata; otherwise falls back to a KRL `find_equivalent` query using
the Gauss code encoded in `:gauss_code` metadata (if available).

## Stub behaviour
Throws `QuandleDBNotWiredError`. Overridden by `NqcQuandleDB`.
"""
function query_equivalence(db::AbstractQuandleDB, ir::TangleIR)
    throw(QuandleDBNotWiredError("query_equivalence"))
end

"""
    classify_knot(db::AbstractQuandleDB, ir::TangleIR) -> Dict{String,Any}

Retrieve the full knot record for the knot represented by the IR.
Returns a Dict with fields such as `name`, `crossing_number`, `writhe`,
`jones_polynomial`, `alexander_polynomial`, etc.

Returns `nothing` if the knot is not found in QuandleDB.

## Stub behaviour
Throws `QuandleDBNotWiredError`. Overridden by `NqcQuandleDB`.
"""
function classify_knot(db::AbstractQuandleDB, ir::TangleIR)
    throw(QuandleDBNotWiredError("classify_knot"))
end

"""
    fetch_knot(db::AbstractQuandleDB, name::String) -> Union{Dict{String,Any}, Nothing}

Fetch a knot record from QuandleDB by canonical knot name (e.g. `"3_1"`,
`"trefoil"`).  Returns `nothing` when the knot is not found.

## Stub behaviour
Throws `QuandleDBNotWiredError`. Overridden by `NqcQuandleDB`.
"""
function fetch_knot(db::AbstractQuandleDB, name::String)
    throw(QuandleDBNotWiredError("fetch_knot"))
end

"""
    store_knot!(db::AbstractQuandleDB, ir::TangleIR; kwargs...) -> UUID

Always throws `QuandleDBReadOnlyError` — the QuandleDB HTTP server is
read-only. Insert knots via Skein.jl directly.
"""
function store_knot!(db::AbstractQuandleDB, ir::TangleIR; kwargs...)
    throw(QuandleDBReadOnlyError())
end

# ---------------------------------------------------------------------------
# Concrete: NqcQuandleDB
# ---------------------------------------------------------------------------

"""
    NqcQuandleDB(host="localhost", port=8080)

Concrete QuandleDB client wired to the QuandleDB HTTP server via the nqc
wire protocol.

## Port note

The nqc `kql_profile()` lists port 8082; the QuandleDB server defaults to
8080. Pass `port=8082` if your deployment uses the nqc-canonical port.

## Constructors

    NqcQuandleDB()                    # localhost:8080
    NqcQuandleDB("localhost", 8082)   # explicit port
"""
struct NqcQuandleDB <: AbstractQuandleDB
    host::String
    port::Int
end

NqcQuandleDB() = NqcQuandleDB("localhost", 8080)

# Helpers

_base_url(db::NqcQuandleDB) = "http://$(db.host):$(db.port)"

"""
    _krl_post(db, query; format="krl", max_rows=500) -> Dict

POST a KRL (or SQL) query to `/api/query` and return the parsed JSON response.
Raises on HTTP error or JSON parse failure.
"""
function _krl_post(db::NqcQuandleDB, query::String;
                   format::String="krl", max_rows::Int=500)
    url  = "$(_base_url(db))/api/query"
    body = JSON3.write(Dict("query" => query, "format" => format,
                            "max_rows" => max_rows))
    resp = try
        HTTP.post(url, ["Content-Type" => "application/json",
                        "Accept"       => "application/json"], body)
    catch e
        error("QuandleDB HTTP request failed: $e")
    end
    resp.status >= 400 && error("QuandleDB server error $(resp.status): $(String(resp.body))")
    JSON3.read(String(resp.body), Dict{String, Any})
end

"""
    _rest_get(db, path) -> Union{Dict, Nothing}

GET `path` from the QuandleDB server and return parsed JSON, or `nothing`
on 404.  Raises on other HTTP errors.
"""
function _rest_get(db::NqcQuandleDB, path::String)
    url  = "$(_base_url(db))$path"
    resp = try
        HTTP.get(url, ["Accept" => "application/json"]; status_exception=false)
    catch e
        error("QuandleDB HTTP request failed: $e")
    end
    resp.status == 404 && return nothing
    resp.status >= 400 && error("QuandleDB server error $(resp.status): $(String(resp.body))")
    JSON3.read(String(resp.body), Dict{String, Any})
end

# Derive a knot name or Gauss code from TangleIR metadata for query routing.

function _resolve_knot_ref(ir::TangleIR)
    # Prefer explicit knot name stored in metadata by parser/lowering.
    kn = get(ir.metadata.extra, :knot_name, nothing)
    !isnothing(kn) && return (:name, string(kn))

    # Fall back to Gauss code if available.
    gc = get(ir.metadata.extra, :gauss_code, nothing)
    if !isnothing(gc)
        codes = join(string.(gc), ", ")
        return (:gauss, "gauss($codes)")
    end

    # Last resort: use the DT code array if present.
    dt = get(ir.metadata.extra, :dt_code, nothing)
    !isnothing(dt) && return (:dt, dt)

    return (:unknown, nothing)
end

# ---------------------------------------------------------------------------
# NqcQuandleDB method implementations
# ---------------------------------------------------------------------------

function query_equivalence(db::NqcQuandleDB, ir::TangleIR)
    kind, ref = _resolve_knot_ref(ir)

    if kind == :name
        # Fast path: use the dedicated semantic-equivalents endpoint.
        data = _rest_get(db, "/api/semantic-equivalents/$(ref)")
        if isnothing(data)
            # Knot name not in QuandleDB — return empty result.
            return EquivalenceResult(string(ref), String[], String[], String[], nothing, nothing)
        end
        return EquivalenceResult(
            get(data, "name", string(ref)),
            String.(get(data, "strong_candidates", String[])),
            String.(get(data, "weak_candidates",  String[])),
            String.(get(data, "combined_candidates", String[])),
            get(data, "descriptor_hash", nothing),
            get(data, "quandle_key",     nothing),
        )
    elseif kind == :gauss
        # Use KRL find_equivalent pipeline with Gauss code literal.
        krl = """
from knots
| find_equivalent $(ref) via [jones, alexander]
| return equivalences with provenance
"""
        data  = _krl_post(db, krl)
        rows  = get(data, "rows", Any[])
        names = [string(get(r, "name", "?")) for r in rows]
        return EquivalenceResult(
            "gauss-query",
            names, String[], names, nothing, nothing,
        )
    else
        # No usable knot reference in IR — return empty result with explanation.
        return EquivalenceResult(
            "unknown",
            String[], String[], String[], nothing, nothing,
        )
    end
end

function classify_knot(db::NqcQuandleDB, ir::TangleIR)
    kind, ref = _resolve_knot_ref(ir)

    if kind == :name
        # Fetch from the REST endpoint for a single knot.
        return _rest_get(db, "/api/knots/$(ref)")
    elseif kind == :gauss
        # KRL pipeline: filter by Gauss code via semantic fingerprint.
        krl = """
from knots
| find_equivalent $(ref) via [jones, alexander, crossing_number]
| take 1
| return name, crossing_number, writhe, jones_polynomial, alexander_polynomial
"""
        data = _krl_post(db, krl)
        rows = get(data, "rows", Any[])
        isempty(rows) && return nothing
        return Dict{String,Any}(string(k) => v for (k, v) in pairs(rows[1]))
    else
        return nothing
    end
end

function fetch_knot(db::NqcQuandleDB, name::String)
    _rest_get(db, "/api/knots/$(name)")
end

# store_knot! inherits the read-only stub from AbstractQuandleDB — no override needed.
