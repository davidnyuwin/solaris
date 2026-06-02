# Hermes Companion — Proposed API Contract

> [!IMPORTANT]
> **Status:** `PROPOSED` (Unverified)
> This document outlines the proposed interface contracts between the **Hermes Companion macOS App** and the **Hermes Agent local daemon**. These contracts are hypothetical definitions based on current application requirements and must be verified against the actual Hermes CLI/Daemon API before implementation.

---

## Endpoint Catalog

### 1. GET /status
*   **Purpose:** Retrieves active runtime states, daemon connection markers, and task metrics to populate the dashboard metrics view.
*   **Status:** `PROPOSED`
*   **Request:**
    *   **Method:** `GET`
    *   **Path:** `/status`
    *   **Headers:** `Accept: application/json`
*   **Response JSON Example:**
    ```json
    {
      "state": "Idle",
      "uptimeSeconds": 86420,
      "relayConnected": true,
      "activeJobsCount": 0
    }
    ```
*   **Swift Model Mapping:** `HermesStatus` (defined in `HermesModels.swift`)
*   **Open Questions:**
    *   Does the daemon report its current state as `"Idle"`, `"Listening"`, `"Processing"`, or `"Error"`, or does it use standard HTTP code status symbols?
    *   Is `uptimeSeconds` an integer representing raw seconds, or does the daemon return a formatted ISO-8601 server start timestamp?
    *   Are jobs tracked actively by the server, or do we need to calculate them client-side?

---

### 2. GET /runs
*   **Purpose:** Fetches the timeline of historical prompt actions and diagnostics for list and search views.
*   **Status:** `PROPOSED`
*   **Request:**
    *   **Method:** `GET`
    *   **Path:** `/runs`
    *   **Headers:** `Accept: application/json`
*   **Response JSON Example:**
    ```json
    [
      {
        "id": "run-001",
        "timestamp": "2026-06-02T07:35:00Z",
        "prompt": "Summarize top tech news from RSS feeds",
        "response": "Fetched 12 feeds. Compiled summary into obsidian notes.",
        "isSuccess": true,
        "durationMs": 4200
      }
    ]
    ```
*   **Swift Model Mapping:** `[HermesRun]` (defined in `HermesModels.swift`)
*   **Open Questions:**
    *   Does the daemon persist run logs natively, or does the companion app need to implement local SQLite/CoreData history caching?
    *   Is the list paginated? If so, what are the limit and cursor query parameters?
    *   What timestamp formats does the server output? (ISO-8601 UTC is assumed).

---

### 3. GET /providers
*   **Purpose:** Obtains performance indexes, latencies, and connectivity state of active LLM relays.
*   **Status:** `PROPOSED`
*   **Request:**
    *   **Method:** `GET`
    *   **Path:** `/providers`
    *   **Headers:** `Accept: application/json`
*   **Response JSON Example:**
    ```json
    [
      {
        "name": "OpenAI API",
        "isOnline": true,
        "latencyMs": 280,
        "successRate": 0.99
      },
      {
        "name": "Groq Cloud Relay",
        "isOnline": false,
        "latencyMs": 0,
        "successRate": 0.0
      }
    ]
    ```
*   **Swift Model Mapping:** `[ProviderHealth]` (defined in `HermesModels.swift`)
*   **Open Questions:**
    *   Does Hermes dynamically ping providers on-demand, or are success rates and latency averages calculated from historical run logs?
    *   Are the provider configurations customizable through the GUI, or are they read-only profiles managed solely by the daemon files?

---

### 4. GET /logs
*   **Purpose:** Extracts system console lines and daemon logs for real-time developer diagnostics.
*   **Status:** `PROPOSED`
*   **Request:**
    *   **Method:** `GET`
    *   **Path:** `/logs`
    *   **Headers:** `Accept: application/json`
*   **Response JSON Example:**
    ```json
    [
      {
        "id": "log-1",
        "timestamp": "2026-06-02T07:34:00Z",
        "level": "INFO",
        "message": "Hermes Core initialized successfully."
      },
      {
        "id": "log-3",
        "timestamp": "2026-06-02T07:35:00Z",
        "level": "WARN",
        "message": "Provider Groq Cloud Relay is currently unreachable."
      }
    ]
    ```
*   **Swift Model Mapping:** `[LogLine]` (defined in `HermesModels.swift`)
*   **Open Questions:**
    *   Does the `/logs` route support log levels filtering (e.g. `?level=error`)?
    *   Is there a real-time log streaming alternative (e.g., WebSockets or Server-Sent Events `/logs/stream`)?
    *   What is the maximum buffer size of lines returned?

---

### 5. POST /command
*   **Purpose:** Dispatches user queries and automated prompt routines to the agent core.
*   **Status:** `PROPOSED`
*   **Request:**
    *   **Method:** `POST`
    *   **Path:** `/command`
    *   **Headers:** `Content-Type: application/json`, `Accept: application/json`
    *   **Body:**
        ```json
        {
          "command": "Check relay health"
        }
        ```
*   **Response JSON Example:**
    ```json
    {
      "responseText": "All local relays are functioning normally. Relay latency: 12ms.",
      "executionTimeMs": 680,
      "success": true,
      "createdRun": {
        "id": "run-f92ka1",
        "timestamp": "2026-06-02T07:55:00Z",
        "prompt": "Check relay health",
        "response": "All local relays are functioning normally. Relay latency: 12ms.",
        "isSuccess": true,
        "durationMs": 680
      }
    }
    ```
*   **Swift Model Mapping:** `HermesResponse` (defined in `HermesModels.swift`)
*   **Open Questions:**
    *   Does `/command` block and run synchronously until the agent completes the work, or does it return an immediate `202 Accepted` status with a task ID to poll?
    *   Does the interface support partial streaming responses (chunked transfer encoding) for text synthesis visualization?
    *   Are files and visual inputs handled inside this endpoint (e.g. multipart/form-data), or is there a separate asset uploads pipeline?
