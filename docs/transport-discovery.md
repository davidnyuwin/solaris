# Solaris Hermes Transport Discovery

## Status

Transport discovery phase complete. The primary safe integration path is read-only CLI status enrichment. In v0.5, this path has been extensively hardened. In v0.6, we completed a robust Profile Discovery Threat Model. Live command/control, WebSocket connections, profile parsing, and REST server triggers remain deferred/future work.

---

## Current Runtime Availability

- **Dashboard API listener:** **Offline/Unavailable** (Port `9119` has no active listener).
- **FastAPI/Uvicorn availability:** **Unavailable** in the bundled Python interpreter inside `Hermes Studio.app` (`ModuleNotFoundError: No module named 'fastapi'`).
- **REST status endpoint:** **Offline/Unavailable** (Connection attempts to `http://127.0.0.1:9119/api/status` fail immediately with connection refused).
- **WebSocket availability:** **Offline/Unavailable** (Web server cannot start).
- **Event stream availability:** **Offline/Unavailable** (Event channels rely on uvicorn broker).

---

## Discovered Transport Surfaces

### REST

| Method | Path | Source-confirmed | Runtime-confirmed | Notes |
|---|---|:---:|:---:|---|
| **GET** | `/api/status` | **Yes** | **No** | Discovered in `web_server.py:569`. Returns comprehensive telemetry: versions, home path, config paths, gateway liveness state, PID, connected platforms, and active session counts. |
| **GET** | `/api/sessions` | **Yes** | **No** | Discovered in `web_server.py:822`. List active/inactive database sessions (limit, offset, total count). |
| **GET** | `/api/sessions/search` | **Yes** | **No** | Discovered in `web_server.py:844`. Performs full-text search across session message content via SQLite FTS5. |
| **GET** | `/api/sessions/{session_id}` | **Yes** | **No** | Discovered in `web_server.py:2509`. Fetches a single session's rich metadata. |
| **GET** | `/api/sessions/{session_id}/messages` | **Yes** | **No** | Discovered in `web_server.py:2536`. Retrieves chronological message histories for a session. |
| **DELETE**| `/api/sessions/{session_id}` | **Yes** | **No** | Discovered in `web_server.py:2550`. Deletes a session from the DB. |
| **GET** | `/api/logs` | **Yes** | **No** | Discovered in `web_server.py:2567`. Read and tail background logs (`agent.log` / `gateway.log`), supporting levels, lines limits, and filters. |
| **POST** | `/api/gateway/restart` | **Yes** | **No** | Discovered in `web_server.py:763`. Triggers detached gateway daemon restarts. |
| **GET** | `/api/profiles` | **Yes** | **No** | Discovered in `web_server.py:2918`. Lists all configured profiles. |
| **GET** | `/api/skills` | **Yes** | **No** | Discovered in `web_server.py:3083`. Lists all installed agent skills. |

### WebSocket

| Path | Source-confirmed | Runtime-confirmed | Notes |
|---|:---:|:---:|---|
| `/api/ws` | **Yes** | **No** | Discovered in `web_server.py:3704` and `tui_gateway/ws.py`. JSON-RPC 2.0 channel driving the TUI dispatcher verbatim. Authenticates via single-use `?ticket=` or loopback `?token=` parameter. |
| `/api/pub` | **Yes** | **No** | Discovered in `web_server.py:3735`. Publisher socket opened by the PTY-side gateway to broadcast status outputs. |
| `/api/events` | **Yes** | **No** | Discovered in `web_server.py:3763` and `tui_gateway/event_publisher.py`. Subscriber channel used by the dashboard React interface to display live tool-call feeds and logs stream. |
| `/api/pty` | **Yes** | **No** | Discovered in `web_server.py:3585`. Interactive PTY bridge driving xterm.js sessions. |

### Event Streams

| Path | Source-confirmed | Runtime-confirmed | Notes |
|---|:---:|:---:|---|
| `/api/events` | **Yes** | **No** | Broadcaster channel for fan-out of gateway events over a channel ID. |

### CLI Control Surfaces

| Command | Purpose | Runtime-confirmed | Notes |
|---|---|:---:|---|
| `hermes dashboard` | Boot the Vite web server, configure CORS, and host API router. | **Yes** | Displays CLI usage syntax help; execution fails to run server due to missing dependencies. |
| `hermes send` | Pipe text messages directly to Telegram, Discord, Slack, etc. | **Yes** | Runs cleanly. Uses the gateway's stored tokens without needing a running gateway process. |
| `hermes status` | Queries active daemon liveness and lists configured platforms. | **Yes** | Discovered in `main.py:12016`. Runs cleanly and displays active status details. |
| `hermes model` | Manage and switch active LLM profiles (Ollama, OpenAI, Anthropic). | **Yes** | Runs cleanly. |
| `hermes gateway start/stop` | Daemon service manager commands to boot background listeners. | **Yes** | Runs cleanly. |

---

## Candidate Integration Paths

### Option A: Keep Local Diagnostics as primary
* **Pros:** 
  * Operates 100% offline with zero dependencies on FastAPI/Uvicorn libraries.
  * Extremely fast, stable, and completely immune to local network listener configurations or port collisions.
  * Direct filesystem and process discovery represents real truth without relying on API health checks.
* **Cons:** 
  * Limited to read-only visibility (scraping process lists and log lines).
  * Cannot issue commands, steer sessions, or retrieve real-time event packets.
* **Risk:** 
  * Very low risk. The only potential block is future macOS sandbox permission limits.

### Option B: REST read-only integration
* **Pros:**
  * Uses standard, decoupled HTTP JSON structures instead of parsing raw local text file buffers.
* **Cons:**
  * Requires a running local web server on port `9119`.
  * Completely blocked in the default `Hermes Studio` installation because `FastAPI` and `Uvicorn` packages are missing from the python resource space.
* **Risk:**
  * Extremely high runtime failure rate unless developers manually execute `pip install fastapi uvicorn` inside the bundle interpreter.

### Option C: WebSocket/event integration
* **Pros:**
  * True real-time, bidirectional command steering and rich event visualization.
  * Mirrors the official dashboard "Chat" tab metadata stream (badges, tool calls, slash parameters).
* **Cons:**
  * Highly complex wire handshake (newline-delimited JSON-RPC 2.0, ticket token exchange, channel handshakes).
  * Totally offline in this environment.
* **Risk:**
  * Very high complexity. Unusable in default out-of-the-box configurations.

### Option D: CLI wrapper integration
* **Pros:**
  * Bypasses the missing HTTP/WebSocket network stack by using Swift `Process` to wrap local command actions (e.g. `hermes send`, `hermes status`, `hermes model get/set`).
  * Reuses the existing authenticated configuration file profiles immediately.
* **Cons:**
  * Significant process spawning overhead compared to simple HTTP network queries.
  * Requires parsing string blocks or handling stdout/stderr streams.
* **Risk:**
  * High fragility if the CLI output format ever changes.

---

## ⚡ Integration Strategy Selection

> [!IMPORTANT]
> **CLI Discovery is now the preferred integration path for Solaris.**
> While the REST and WebSocket routes have been source-confirmed, they remain **runtime-unavailable** in this Hermes Studio installation due to missing `FastAPI` and `Uvicorn` dependencies in the python bundle environment. 
> Spawning inspect-only CLI subprocesses (Option D) is highly secure, requires no local network servers, operates 100% offline, and perfectly bridges model status, active settings, and process telemetry into Solaris.

---

## Recommended Next Step
1. **Retain Local Diagnostics as the primary core:** Keep utilizing filesystem scanning and `pgrep`/`lsof` for baseline status.
2. **Implement a safe CLI Wrapper service:** Let the companion UI invoke `hermes status` and `hermes config show` directly using standard Swift `Process` executions. Parse the plain text stdout to retrieve the active model name and gateway running states. This adds real-time settings validation without requiring uvicorn network servers or missing Python libraries.

---

## Open Questions
1. Is there an official, supported way to install the optional `FastAPI` / `Uvicorn` dashboard dependencies on the user's system without contaminating the read-only `Hermes Studio.app` bundle?
2. If sandboxing is enforced in a future version of macOS, will standard `Process` executions of `/Applications/Hermes Studio.app/Contents/Resources/python/bin/python3` still be allowed from an app sandbox?
