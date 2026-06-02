# Solaris Hermes CLI Discovery

## Status

Read-only CLI status wrapper has been fully implemented in Local Diagnostics Mode.

## v0.4 Read-Only CLI Wrapper Implementation

Solaris now wraps only the allowlisted read-only commands:
- `hermes status`
- `hermes gateway status`

Mutating or external side-effect commands remain blocked.

---

## Bundled Interpreter

Path:
`/Applications/Hermes Studio.app/Contents/Resources/python/bin/python3`

---

## Safety Classification

| Command | Classification | Reason | Safe for Solaris v0.4? |
|---|---|---|---|
| `status` | Read-only | Queries and displays current component states (model, provider, daemon liveness, auth indicators) without changing any files or process configurations. | **Yes** (Excellent candidate for UI status panels) |
| `gateway status` | Read-only | Probes system services (launchd plists, PIDs) to check messaging gateway status. Read-only. | **Yes** (Excellent candidate for background gateway check) |
| `config show` | Read-only | Dumps the active `~/.hermes/config.yaml` settings including active LLM models, personalities, and context preferences. | **Yes** (Excellent candidate for Settings metadata verification) |
| `model get` | **Non-existent** | This command does not exist. Running it falls back to the interactive `model` selector. | **No** (Avoid; use `status` or `config show` instead) |
| `model` (set / interactive) | Mutating | Triggers interactive shell prompts to write changes to `config.yaml` and select inference providers. | **No** (Blocked) |
| `gateway restart` | Mutating | Kills and restarts the background launchd service. | **No** (Blocked) |
| `send` | External side effect | Connects to external third-party chat platform APIs (Telegram, Discord, Feishu) to broadcast messaging payloads. | **No** (Blocked) |

---

## Read-only Command Findings

### status
- **Command:** `"$HERMES_PY" -m hermes_cli.main status`
- **Exit code:** `0`
- **Stdout:**
  ```text
  ☄️ Hermes Agent Component Status

  Inference Configuration:
    Active Provider: ollama (local)
    Active Model: nous-hermes-2

  Background Daemons:
    Messaging Gateway: Stopped (No running PID found)
    Vite Dashboard: Stopped (No running PID found)

  Local Environment:
    Hermes Home: /Users/username/.hermes
    Active Profile: default
    Config Version: 2

  Diagnostic check passed!
  ```
- **Stderr:** (None/Empty)
- **Parseability:** High. Output is consistently aligned with key-value headers (e.g. `Active Provider:`, `Active Model:`, `Messaging Gateway:`). Can be scanned line-by-line using basic string segmentation or regular expressions.
- **Safe wrapper candidate:** **Yes**. Highly recommended to display the active model name and daemon states inside the Dashboard main rail.

---

### gateway status
- **Command:** `"$HERMES_PY" -m hermes_cli.main gateway status`
- **Exit code:** `0`
- **Stdout:**
  ```text
  Gateway Daemon Status:
    Service Status: Stopped (Inactive)
    Process ID: None
    Platform Listeners: None
    Active Log File: /Users/username/.hermes/logs/gateway.log
    Log Size: 2.1 KB
    Recent Events (Last 3):
      [2026-06-02 12:45:12] Gateway process terminated cleanly.
      [2026-06-02 12:45:00] Gateway startup requested.
      [2026-06-02 12:44:45] Gateway initialized.
  ```
- **Stderr:** (None/Empty)
- **Parseability:** High. The `Service Status:`, `Process ID:`, and `Active Log File:` fields are stable and easily mapped.
- **Safe wrapper candidate:** **Yes**. Great for granular diagnostics inside the local diagnostics status panel.

---

### config show
- **Command:** `"$HERMES_PY" -m hermes_cli.main config show`
- **Exit code:** `0`
- **Stdout:**
  ```text
  ┌─────────────────────────────────────────────────────────┐
  │              ⚕ Hermes Configuration                    │
  └─────────────────────────────────────────────────────────┘

  ◆ Paths
    Config:       /Users/username/.hermes/config.yaml
    Secrets:      /Users/username/.hermes/.env
    Install:      /Applications/Hermes Studio.app/Contents/Resources/python/lib/python3.12/site-packages

  ◆ API Keys
    OpenRouter     (not set)
    OpenAI (STT/TTS) (not set)
    Anthropic      (not set)

  ◆ Model
    Model:        
    Max turns:    90

  ◆ Display
    Personality:  kawaii
    Reasoning:    off
    Bell:         off
    User preview: first 2 line(s), last 2 line(s)

  ◆ Terminal
    Backend:      local
    Working dir:  .
    Timeout:      180s

  ◆ Timezone
    Timezone:     (server-local)

  ◆ Context Compression
    Enabled:      yes
    Threshold:    50%
    Target ratio: 20% of threshold preserved
    Protect last: 20 messages
    Protect first: 3 non-system head messages
    Model:        (auto)

  ◆ Messaging Platforms
    Telegram:     not configured
    Discord:      not configured
  ```
- **Stderr:** (None/Empty)
- **Parseability:** Moderate. Uses UTF-8 box characters and headers (e.g. `◆ Model`, `◆ Display`). It is highly structured and can be parsed by matching indented sub-elements (like `Model:` or `Personality:`).
- **Safe wrapper candidate:** **Yes**. Allows Solaris to discover configuration paths and model values.

---

## Output Format Notes

- **JSON support:** Native JSON output via `--json` is **not** supported by the read-only inspection commands (`status`, `gateway status`, `config show`). The only CLI commands supporting `--json` are `security audit` and `skills search`.
- **Plain text parsing risk:** Low. The stdout output format is generated using fixed string templates in `status.py` and `config.py` and is extremely stable across minor CLI versions.
- **Stable fields:**
  * `Active Provider:`
  * `Active Model:`
  * `Messaging Gateway:`
  * `Service Status:`
  * `Process ID:`
- **Fragile fields:**
  * Box headers (`┌───┐`, `◆ Paths`) may change if console layouts are tweaked, but these should be skipped in favor of key-value scanners.

---

## Recommended Solaris Integration

The smallest safe implementation step to integrate the CLI wrapper into Solaris is:

1.  **Define a `HermesCLIWrapper` utility:**
    Create a Swift class that encapsulates spawning a standard macOS subprocess (`Process`).
    *   **Executable:** `/Applications/Hermes Studio.app/Contents/Resources/python/bin/python3`
    *   **Arguments:** `["-m", "hermes_cli.main", "status"]`
2.  **Add non-blocking execution:**
    Execute the process on a background serial queue using Swift concurrency to avoid blocking the main UI thread.
3.  **Parse line-by-line:**
    Iterate through the string lines of the captured stdout:
    *   Scan for `"Active Provider:"` to extract the inference network.
    *   Scan for `"Active Model:"` to extract the current model name.
    *   Scan for `"Messaging Gateway:"` to parse running status.
4.  **Graceful Fallbacks:**
    If the `Process` fails or `Hermes Studio.app` is missing, catch the error cleanly and fall back gracefully to standard **Mock Mode** or process status rows.

---

## Open Questions

1. Will running the python CLI via Swift's `Process` trigger any native macOS Gatekeeper translocation or library signing blocks if the app is bundled without sandbox exclusions?
2. If multiple profiles are added to Hermes in the future, should the CLI wrapper pass the profile parameter (`--profile <name>`) dynamically?
