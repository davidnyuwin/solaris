# Solaris Profile Discovery Threat Model

## Status

Threat model only. No profile discovery implementation exists in the Solaris application.

---

## Scope

This document evaluates the security surface and potential vulnerabilities of introducing **Local Profiles Discovery** inside Solaris. This feature would allow Solaris to inspect, list, and summarize local Hermes Companion configurations, profile lists, and provider directories to display host parameters under **Local Diagnostics Mode**.

---

## Non-Goals

*   **No Mutating Controls:** This threat model does not evaluate command-sending, profile-switching, model-setting, or credential-injection. Mutating operations remain blocked.
*   **No Network Transmission:** All diagnostics remain completely isolated and offline. No local profile telemetry will be transmitted over HTTP, WebSocket, or third-party relays.
*   **No Auto-loading of Raw Secrets:** Solaris will never read, ingest, decrypt, or cache raw passwords, tokens, API keys, or private platform secrets.

---

## Source Inspection Summary

We inspected the Python resources and site-packages bundled within `Hermes Studio.app` to trace how profile metadata is loaded:
*   **Package Path:** `/Applications/Hermes Studio.app/Contents/Resources/python/lib/python3.12/site-packages`
*   **Configuration Schema:** Stored within `hermes_cli/config.py` and managed via YAML parsing (`yaml.safe_load`). Config metadata lists paths, OpenAI/Anthropic/OpenRouter API credentials, and display overrides.
*   **Profile Metadata:** Defined inside `hermes_cli/profiles.py` in the `ProfileInfo` dataclass:
    *   `name`: str
    *   `path`: Path (Absolute host profile path)
    *   `is_default`: bool
    *   `gateway_running`: bool
    *   `model`: Optional[str]
    *   `provider`: Optional[str]
    *   `has_env`: bool
    *   `skill_count`: int
*   **Environment Secrets:** Private platform tokens and credentials (e.g. Telegram tokens, Discord credentials, Feishu keys) are stored under a separate `.env` file (`~/.hermes/.env` or `<profile_dir>/.env`) and are kept out of `config.yaml` to minimize exposure.

---

## Potential Sensitive Data

Our audit identified several categories of sensitive data that are present in the local Hermes environment:
1.  **API Credentials:** `Anthropic`, `OpenAI`, and `OpenRouter` API key tokens config parameters.
2.  **Platform Tokens:** Telegram bot tokens, Discord client secrets, and Feishu webhook keys.
3.  **Local Machine Paths:** Absolute user home paths (`/Users/username/.hermes`) exposing specific developers' names.
4.  **Process Details:** Running daemon process IDs (PIDs) and platform listeners.
5.  **Channel Details:** Specific Discord server channels, Feishu group chat IDs, or Telegram chat IDs where messages are piped.

---

## Field Safety Classification

To guarantee data integrity and absolute privacy, all local Hermes variables are classified below:

| Field / Pattern | Classification | Reason | Display Policy |
|---|---|---|---|
| `profile_count` | **Safe Metadata** | Aggregate count of installed profiles; contains no private details. | Fully Visible |
| `is_default` | **Safe Metadata** | Boolean state flag for default profile indicator. | Fully Visible |
| `skill_count` | **Safe Metadata** | Integer count of loaded skills. | Fully Visible |
| `active_provider` | **Safe Metadata** | Generic inference host network label (e.g., `ollama`, `openai`). | Fully Visible |
| `active_model` | **Safe Metadata** | Common LLM model identifiers (e.g., `nous-hermes-2`). | Fully Visible |
| `config_version` | **Safe Metadata** | Versioning tag of local configuration. | Fully Visible |
| `profile_name` | **Conditional** | Might contain personal names (e.g. `david-personal`). | Render directly, but redact absolute paths containing it. |
| `model_url` | **Conditional** | Private network address / Ollama custom endpoints. | Redact to host-only or hide fully in Privacy Mode. |
| `absolute_paths` | **Conditional / Redact** | Leaks host username and machine file structures. | Must be converted to relative `~/...` representations. |
| `api_keys` | **Sensitive / Blocked** | Raw key authorization strings allowing third-party API usage. | **NEVER READ or DISPLAY** |
| `tokens` | **Sensitive / Blocked** | Bot or client authorization tokens. | **NEVER READ or DISPLAY** |
| `webhook_secrets`| **Sensitive / Blocked** | API target URLs containing secure endpoint hashes. | **NEVER READ or DISPLAY** |
| `channel_ids` | **Sensitive / Blocked** | Targets and chat routing IDs. | **NEVER READ or DISPLAY** |
| `env_variables` | **Sensitive / Blocked** | Environment parameters containing active secrets. | **NEVER READ or DISPLAY** |

---

## Integration Options

We evaluated five implementation approaches for profiles discovery in Solaris:

### Option A: No Profile Discovery Yet (Intentional Deferral)
*   **Pros:** 100% immune to data leak threats, zero codebase overhead, absolute security.
*   **Cons:** Users cannot see their configured profiles list or resource usage statistics in UI.
*   **Risk:** **Zero**.

### Option B: Direct Sanitized YAML Parsing
*   **Pros:** Bypasses subprocess execution by parsing local files directly.
*   **Cons:** Vulnerable to YAML injection payloads, requires massive defensive parser validation code, and will fail instantly under Apple App Sandboxing due to restricted filesystem access policies.
*   **Risk:** **Extremely High**.

### Option C: CLI Safe Summary Only (Status Wrapper)
*   **Pros:** Solaris wraps only `hermes status` and `hermes gateway status` to pull safe, generic model/provider details. All authentication, secrets loading, and parsing are kept isolated inside the official, secure Hermes CLI space.
*   **Cons:** Limited to the narrow parameters printed by the CLI.
*   **Risk:** **Extremely Low**.

### Option D: User-Selected Import with Redaction Preview
*   **Pros:** Sandboxing compatible via native macOS `NSOpenPanel`.
*   **Cons:** Friction-heavy UX, still requires complex YAML parsing code and carries leakage risk.
*   **Risk:** **Moderate**.

### Option E: Manual Safe Metadata Only
*   **Pros:** Immune to filesystem reading issues, extremely secure.
*   **Cons:** Stale configurations, high manual entry friction.
*   **Risk:** **Low**.

---

## Recommended Approach

> [!IMPORTANT]
> **We strongly recommend Option A (No profile discovery yet) combined with Option C (CLI-only Safe Summary).**
> Direct reading of `config.yaml` or parsing raw profile directories (Option B & D) poses unacceptable security and sandboxing risks. 
> Wrapping allowlisted inspect-only CLI status targets (`hermes status` and `hermes gateway status`) using Swift `Process` is the only safe way to obtain local diagnostic telemetry. 
> This approach encapsulates all credential handling inside the official Hermes environment, ensures 100% compliance with macOS Gatekeeper and future sandbox constraints, and completely eliminates the risk of private token leaks.

---

## Required Guardrails Before Implementation

If any config/profile discovery is implemented in future phases, the following strict guardrails are **mandatory**:
1.  **Block YAML Readers:** The main Solaris app must **never** instantiate YAML parsers (`YAMLEncoder`, `YAMLDecoder`) to read `~/.hermes/config.yaml` or `.env` files directly.
2.  **Enforce Whitelists:** All parsed keys must pass against a strict, hardcoded safe metadata whitelist.
3.  **Mandatory Path Redaction:** Any absolute path string parsed from stdout/stderr must pass through the `redactPath(_:)` utility.
4.  **Automatic Privacy Mode:** All custom profile labels or custom model endpoint URLs must be automatically hidden when Privacy Mode is activated in the UI.
5.  **Audit Logs:** Solaris must log any process execution command to verify that only allowlisted status probes are run.

---

## Open Questions

1.  Will future versions of Hermes CLI provide a structured, read-only `--json` status dump specifically for local integrations to bypass plain-text parsing entirely?
2.  Under strict App Store sandboxing, will a user-authorized security-scoped bookmark to `~/.hermes/` still permit child process executions to access the active bundle configurations?
