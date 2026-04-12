# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 for Julia ecosystem consistency)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
Groove integration — application-agnostic observability augmentation.

## Two-layer separation (architectural principle)

This file implements the **extrinsic** layer.  KRLAdapter.jl's core behaviour
(TangleIR operations, QuandleDB queries, VerisimCore wiring) lives in the
adapter files and works regardless of whether Groove is active.

This file adds *optional* observability: KRLAdapter emits OTLP spans that
PanLL's ObservabilityEngine can ingest, discovered via the Groove protocol.

    KRLAdapter.jl (Julia)
      │  instruments: store_ir_verisim!, query_ir_verisim, prove_consonance,
      │               query_equivalence, classify_knot, fetch_knot
      │  emits: OTLP spans (HTTP POST to collector, fire-and-forget)
      │
      ▼  Groove discovery (GET /groove/capabilities at well-known port)
      │
    PanLL ObservabilityEngine.res
         ingests via ObservabilityCmd → UpdateObservability → Panel-W

## Groove protocol

A Groove-aware service exposes a tiny HTTP endpoint that advertises its
capabilities. PanLL probes well-known ports on startup. When it finds
KRLAdapter's Groove endpoint, observability panels appear automatically.
Neither system needs the other to function.

## OTLP format

Spans follow the standard OpenTelemetry Protocol JSON format, identical to
the format used by PanLL's own `ObservabilityEngine.res`:

    POST <collector_url>
    Content-Type: application/json
    {"resourceSpans": [{"resource": {...}, "scopeSpans": [{"spans": [...]}]}]}

## Groove port assignment

KRLAdapter.jl: 6482 (next after Vext 6480)
Known assignments: Burble 6473, Vext 6480, VeriSimDB 8080, QuandleDB 8080.

## Usage

    using KRLAdapter
    emitter = GrooveEmitter()             # defaults to localhost:4318 OTLP
    start_groove_server(emitter)          # starts discovery at :6482 (async)
    @groove_trace emitter "krl/fetch_knot" begin
        result = fetch_knot(db, "3_1")
    end

Or call `emit_span` directly for manual instrumentation.
"""

using HTTP
using JSON3
using Dates
using UUIDs

export GrooveEmitter, emit_span, start_groove_server, @groove_trace

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

const GROOVE_DEFAULT_PORT     = 6482
const OTLP_DEFAULT_HOST       = "localhost"
const OTLP_DEFAULT_PORT       = 4318         # Standard OTLP HTTP port
const OTLP_DEFAULT_PATH       = "/v1/traces"
const SERVICE_NAME            = "krl-adapter"
const SERVICE_VERSION         = "0.1.0"
const SCOPE_NAME              = "krladapter.groove"
const SCOPE_VERSION           = "1.0.0"

# Groove capability declaration (consumed by PanLL on discovery).
const GROOVE_CAPABILITIES = Dict(
    "service"   => SERVICE_NAME,
    "version"   => SERVICE_VERSION,
    "port"      => GROOVE_DEFAULT_PORT,
    "offers"    => ["trace-source"],
    "consumes"  => ["panll-observability"],
    "otlp"      => Dict(
        "protocol" => "http/json",
        "path"     => OTLP_DEFAULT_PATH,
    ),
)

# ---------------------------------------------------------------------------
# GrooveEmitter
# ---------------------------------------------------------------------------

"""
    GrooveEmitter(; otlp_url, groove_port, enabled)

Configuration for Groove/OTLP observability emission.

# Fields
- `otlp_url::String`: full URL of the OTLP trace collector endpoint
  (default: `"http://localhost:4318/v1/traces"`)
- `groove_port::Int`: port for the Groove discovery HTTP server
  (default: 6482)
- `enabled::Bool`: set `false` to disable all emission without code changes
  (default: `true`)

# Constructors

    GrooveEmitter()
    GrooveEmitter(otlp_url="http://localhost:4318/v1/traces")
    GrooveEmitter(otlp_url=..., groove_port=6482, enabled=true)
"""
struct GrooveEmitter
    otlp_url::String
    groove_port::Int
    enabled::Bool
end

function GrooveEmitter(;
    otlp_url    = "http://$(OTLP_DEFAULT_HOST):$(OTLP_DEFAULT_PORT)$(OTLP_DEFAULT_PATH)",
    groove_port = GROOVE_DEFAULT_PORT,
    enabled     = true,
)
    GrooveEmitter(otlp_url, groove_port, enabled)
end

# ---------------------------------------------------------------------------
# OTLP span helpers
# ---------------------------------------------------------------------------

"""
    _random_trace_id() -> String

Generate a random 32-character hex string (128-bit trace ID).
Same format as PanLL's ObservabilityEngine.randomTraceId().
"""
_random_trace_id() = bytes2hex(rand(UInt8, 16))

"""
    _random_span_id() -> String

Generate a random 16-character hex string (64-bit span ID).
Same format as PanLL's ObservabilityEngine.randomSpanId().
"""
_random_span_id() = bytes2hex(rand(UInt8, 8))

"""
    _now_nano() -> String

Current Unix time in nanoseconds as a string (OTLP format).
"""
_now_nano() = string(round(Int64, time() * 1_000_000_000))

"""
    _ms_to_nano(ms) -> String

Convert a duration in milliseconds to a nanosecond string for OTLP.
"""
_ms_to_nano(ms::Float64) = string(round(Int64, ms * 1_000_000))

# ---------------------------------------------------------------------------
# emit_span
# ---------------------------------------------------------------------------

"""
    emit_span(emitter, operation, start_time, duration_ms; attrs=Dict())

Emit a single OTLP span to the configured collector.

The call is **fire-and-forget** — failures are silently swallowed so that
observability never affects correctness of core operations.

# Arguments
- `emitter::GrooveEmitter`: configured emitter
- `operation::String`: span operation name, e.g. `"krl/query_equivalence"`
- `start_time::Float64`: Unix timestamp (seconds) of span start (`time()`)
- `duration_ms::Float64`: wall-clock duration in milliseconds
- `attrs::Dict{String,Any}`: additional span attributes (merged with defaults)

# Attributes automatically added
- `"service.name"` = `"krl-adapter"`
- `"krl.operation"` = `operation`
- `"krl.duration_ms"` = `duration_ms`
"""
function emit_span(emitter::GrooveEmitter, operation::String,
                   start_time::Float64, duration_ms::Float64;
                   attrs::Dict{String,Any}=Dict{String,Any}())
    emitter.enabled || return

    trace_id     = _random_trace_id()
    span_id      = _random_span_id()
    start_nano   = string(round(Int64, start_time * 1_000_000_000))
    end_nano     = string(round(Int64, (start_time + duration_ms / 1000) * 1_000_000_000))
    duration_nano = _ms_to_nano(duration_ms)

    # Build attributes list: defaults + caller-supplied extras.
    default_attrs = Dict{String,Any}(
        "service.name"      => SERVICE_NAME,
        "krl.operation"     => operation,
        "krl.duration_ms"   => duration_ms,
    )
    merged = merge(default_attrs, attrs)
    attr_json = join([
        """{"key":$(JSON3.write(k)),"value":{"$(v isa String ? "string" : "double")Value":$(JSON3.write(v))}}"""
        for (k, v) in merged
    ], ",")

    payload = """
{"resourceSpans":[{"resource":{"attributes":[
{"key":"service.name","value":{"stringValue":"$(SERVICE_NAME)"}},
{"key":"service.version","value":{"stringValue":"$(SERVICE_VERSION)"}}
]},"scopeSpans":[{"scope":{"name":"$(SCOPE_NAME)","version":"$(SCOPE_VERSION)"},"spans":[
{"traceId":"$(trace_id)","spanId":"$(span_id)","operationName":"$(operation)",
"startTimeUnixNano":"$(start_nano)","endTimeUnixNano":"$(end_nano)",
"durationNano":"$(duration_nano)",
"status":{"code":"STATUS_CODE_OK"},
"attributes":[$(attr_json)]}
]}]}]}
"""

    # Fire-and-forget: errors in observability must not affect the caller.
    try
        HTTP.post(emitter.otlp_url,
                  ["Content-Type" => "application/json",
                   "Accept"       => "application/json"],
                  payload; connect_timeout=1, readtimeout=2)
    catch
        # Silently swallow — collector may not be running.
    end
    nothing
end

# ---------------------------------------------------------------------------
# @groove_trace macro
# ---------------------------------------------------------------------------

"""
    @groove_trace emitter operation expr

Time `expr` and emit an OTLP span via `emitter` with the given `operation`
name.  Returns the value of `expr` unchanged.

    result = @groove_trace emitter "krl/query_equivalence" begin
        query_equivalence(db, ir)
    end

On error the span is emitted with `"krl.error" => true` before re-throwing.
"""
macro groove_trace(emitter, operation, expr)
    quote
        local _em   = $(esc(emitter))
        local _op   = $(esc(operation))
        local _t0   = time()
        local _ok   = true
        local _result
        try
            _result = $(esc(expr))
        catch _err
            _ok = false
            local _dur = (time() - _t0) * 1000.0
            emit_span(_em, _op, _t0, _dur;
                      attrs=Dict{String,Any}("krl.error" => true,
                                             "krl.error_type" => string(typeof(_err))))
            rethrow(_err)
        end
        local _dur = (time() - _t0) * 1000.0
        emit_span(_em, _op, _t0, _dur)
        _result
    end
end

# ---------------------------------------------------------------------------
# Groove discovery server
# ---------------------------------------------------------------------------

"""
    start_groove_server(emitter; blocking=false) -> Union{Nothing, Task}

Start a tiny HTTP server at `emitter.groove_port` that answers Groove
capability discovery probes.

PanLL probes well-known ports (including 6482) on startup. When it finds this
endpoint, observability panels appear automatically without any configuration
on either side.

Returns a `Task` running the server loop when `blocking=false` (default).
Pass `blocking=true` to block the caller (useful for scripts).

## Endpoints served

- `GET /groove/capabilities` → JSON capability declaration
- `GET /health`              → `{"status":"ok","service":"krl-adapter"}`
"""
function start_groove_server(emitter::GrooveEmitter; blocking::Bool=false)
    emitter.enabled || return nothing

    cap_json = JSON3.write(GROOVE_CAPABILITIES)

    function handle(req::HTTP.Request)
        path = HTTP.URI(req.target).path
        if path == "/groove/capabilities"
            return HTTP.Response(200,
                ["Content-Type" => "application/json"],
                cap_json)
        elseif path == "/health"
            return HTTP.Response(200,
                ["Content-Type" => "application/json"],
                """{"status":"ok","service":"$(SERVICE_NAME)"}""")
        else
            return HTTP.Response(404, "Not found")
        end
    end

    server_fn = () -> begin
        try
            HTTP.serve(handle, emitter.groove_port; verbose=false)
        catch e
            @warn "KRLAdapter Groove server stopped" exception=e
        end
    end

    if blocking
        server_fn()
        return nothing
    else
        return Threads.@spawn server_fn()
    end
end
