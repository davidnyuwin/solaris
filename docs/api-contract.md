# Hermes Companion — Verified API Contract

> [!IMPORTANT]
> **Status:** `VERIFIED & AUDITED` (June 2, 2026)
> This document details the verified API contracts between the **Hermes Companion macOS App** and the actual local running **Hermes Studio daemon** (parsed from the active FastAPI `web_server.py` and `main.py` source codes inside `/Applications/Hermes Studio.app`).

---

## ⚙️ Real Host & Port Discovery
*   **Daemon Executable:** `/Applications/Hermes Studio.app/Contents/Resources/python/bin/python3 -m hermes_cli.main gateway run --replace`
*   **Active Log Directory:** `/Users/dnguyen/.hermes/logs/`
*   **Real Web Server Port:** Configured dynamically from CLI args (`--port` / `-p`) or defaults. If launched via Hermes Studio, it operates on a standard port (typically `5080` or dynamic).

---

## Endpoint Catalog & Mismatch Audit

### 1. GET /api/status
*   **Purpose:** Retrieves active runtime states, daemon connection markers, and task metrics to populate the dashboard metrics view.
*   **Audit Status:** `CONFIRMED / MISMATCH`
*   **Path Mismatch:** The proposed path `/status` must be corrected to `/api/status`.
*   **Response Shape Mismatch:** 
    *   *Proposed:* Returns structured state strings (`idle`/`listening`/`processing`/`error`), uptime, and active jobs.
    *   *Verified Real Payload:*
        ```json
        {
          "version": "0.6.7",
          "release_date": "2026-05-15",
          "hermes_home": "/Users/dnguyen/.hermes",
          "config_path": "/Users/dnguyen/.hermes/config.yaml",
          "env_path": "/Users/dnguyen/.hermes/.env",
          "config_version": 2,
          "latest_config_version": 2,
          "gateway_running": true,
          "gateway_pid": 91308,
          "gateway_health_url": null,
          "gateway_state": "running",
          "gateway_platforms": {},
          "gateway_exit_reason": null,
          "gateway_updated_at": 1780400100.0,
          "active_sessions": 0,
          "auth_required": false,
          "auth_providers": []
        }
        ```
*   **Swift Model Mapping Updates:** 
    Update `HermesStatus` to accept `gateway_state: String` (e.g. `"running"`, `"stopped"`), `gateway_running: Bool`, and `active_sessions: Int` (replacing `activeJobsCount`).

---

### 2. GET /api/sessions (Proposed as GET /runs)
*   **Purpose:** Fetches the timeline of historical prompt actions and diagnostics for list and search views.
*   **Audit Status:** `MISMATCH` (Path & Wrapper Payload)
*   **Path Mismatch:** The proposed path `/runs` does not exist. The verified path is `/api/sessions` (supporting `limit` and `offset` query parameters) or `/api/sessions/search?q={query}`.
*   **Response Shape Mismatch:**
    *   *Proposed:* `[HermesRun]`
    *   *Verified Real Payload:*
        ```json
        {
          "sessions": [
            {
              "id": "session_01h9zk...",
              "started_at": 1780396500.0,
              "last_active": 1780398300.0,
              "ended_at": null,
              "is_active": true
            }
          ],
          "total": 1,
          "limit": 20,
          "offset": 0
        }
        ```
*   **Swift Model Mapping Updates:** 
    Map runs directly to the `"sessions"` list returned inside the root dict. Convert raw Epoch timestamps to `Date`.

---

### 3. GET /api/logs
*   **Purpose:** Extracts system console lines and daemon logs for real-time developer diagnostics.
*   **Audit Status:** `MISMATCH` (JSON Structure Mismatch)
*   **Path Mismatch:** Proposed `/logs` must be `/api/logs`. Supports queries: `file` (default `"agent"`), `lines` (default 100), `level`, and `search`.
*   **Response Shape Mismatch:**
    *   *Proposed:* List of structured objects (`[LogLine]`).
    *   *Verified Real Payload:*
        ```json
        {
          "file": "agent",
          "lines": [
            "2026-06-01 15:51:50,001 INFO hermes_cli.plugins: Plugin 'openai' registered...",
            "2026-06-01 15:52:01,221 INFO gateway.run: Starting Hermes Gateway..."
          ]
        }
        ```
*   **Swift Model Mapping Updates:** 
    `LogLine` must decode the `"lines"` array of raw strings and parse/tokenize timestamps and levels client-side, rather than expecting pre-structured JSON logs.

---

### 4. GET /api/providers/oauth (Proposed as GET /providers)
*   **Purpose:** Obtains performance indexes, latencies, and connectivity state of active LLM relays.
*   **Audit Status:** `MISMATCH / NOT FOUND`
*   **Path Mismatch:** The proposed `/providers` health metric path does not exist. The closest verified endpoint is `/api/providers/oauth` which lists registered authorization accounts. Capabilites and models info are located at `/api/model/info` and `/api/model/options`.
*   **Verified Model Info Payload:**
    ```json
    {
      "model_name": "nous-hermes-2",
      "provider": "openrouter",
      "auto_context_length": 204800,
      "effective_context_length": 204800,
      "supports_tools": true,
      "supports_vision": false
    }
    ```
*   **Swift Model Mapping Updates:**
    Adapt the UI to fetch `/api/model/info` to display the active LLM rather than polling a custom latencies list.

---

### 5. POST /api/sessions/{session_id}/messages (Proposed as POST /command)
*   **Purpose:** Dispatches user queries and automated prompt routines to the agent core.
*   **Audit Status:** `MISMATCH` (Session-Based Streaming)
*   **Path Mismatch:** There is no blocking, atomic `/command` POST route. Execution is session-scoped. Chat and terminal integrations operate over real-time WebSockets:
    *   `ws://127.0.0.1:5080/api/ws` — Embedded chat handler.
    *   `ws://127.0.0.1:5080/api/events` — Pub/Sub live event broadcast stream.
    *   `ws://127.0.0.1:5080/api/pty` — Interactive stdio pseudoterminal loop.
*   **Swift Integration Strategy:**
    Utilize standard `URLSessionWebSocketTask` inside `LiveHermesService` to open a socket to `/api/ws` or `/api/events` for bi-directional command processing, keeping the Siri-style orb reactive to live streaming tokens.
