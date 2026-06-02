# Remote Hermes Host — Transport Matrix

Investigation date: 2026-06-02

---

## Transport Summary

| # | Transport | Requires Dashboard | Requires SSH | Interactive Chat | Implementation Risk | Auth Method | v0.9 Verdict |
|---|-----------|------------------:|------------:|-----------------:|-------------------:|-----------:|-------------:|
| 1 | SSH read-only command runner | ❌ No | ✅ Yes | ❌ No | Low (Process + ssh) | macOS SSH agent | **Batch 1** |
| 2 | SSH one-shot `hermes chat -q` | ❌ No | ✅ Yes | ⚠️ Limited (per-command) | Medium (CLI parsing) | macOS SSH agent | Batch 2 |
| 3 | SSH PTY running `hermes` | ❌ No | ✅ Yes | ✅ Yes | High (PTY bridge) | macOS SSH agent | Batch 3 |
| 4 | SSH tunnel → local WS `/api/pty` | ✅ Yes (remote) | ⚠️ Tunnel only | ✅ Yes | High (tunnel + WS client) | SSH tunnel + session token | Future |
| 5 | Local dashboard WebSocket `/api/pty` | ✅ Yes (local) | ❌ No | ✅ Yes | High (FastAPI missing) | Session token | **Blocked** |
| 6 | Custom Solaris bridge daemon | ❌ No | ⚠️ Optional | ✅ Yes | High (custom daemon) | Custom auth | Future |

---

## Detailed Assessment

### 1. SSH Read-Only Command Runner

**How it works:**
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
process.arguments = ["user@host", "hermes status"]
```

**Safety:**
- ✅ Command allowlist enforced in Swift code.
- ✅ Uses system SSH agent — no keys stored in Solaris.
- ✅ No remote state mutation.
- ✅ No external platform messaging.

**Implementation:**
- New `SSHCommandExecutor` service implementing `HermesService` protocol.
- Command allowlist as a `Set<String>` with prefix matching.
- Timeout handling per command.
- Output redaction for PII/paths/tokens.

**Risk:** Low.

### 2. SSH One-Shot `hermes chat -q`

**How it works:**
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
process.arguments = ["user@host", "hermes", "chat", "-q", "prompt text"]
```

**Safety:**
- ✅ No external platform messaging (uses LLM provider, not gateway).
- ⚠️ YOLO mode auto-approves hooks/tools — harmless prompts only.
- ✅ Uses system SSH agent.
- ⚠️ Response may contain PII — must redact.

**Implementation:**
- Prompt allowlist or user confirmation.
- Timeout handling.
- Output redaction.
- Response parsing (strip ANSI, tool call artifacts).

**Risk:** Medium.

### 3. SSH PTY Running `hermes`

**How it works:**
```text
Solaris → SSH PTY → hermes (interactive) → response stream
```

**Safety:**
- ✅ No dashboard dependency.
- ✅ Full Hermes environment on the remote host.
- ✅ Uses system SSH agent.

**Implementation:**
- Needs PTY bridge (e.g., SwiftNIO or custom `forkpty` wrapper).
- ANSI escape sequence handling or raw stream pass-through.
- Terminal resize event forwarding.
- Session lifecycle management.

**Risk:** High (complexity).

### 4. SSH Tunnel → Local Dashboard WebSocket

**How it works:**
```bash
ssh -L 9119:localhost:9119 user@host
# Then connect to ws://127.0.0.1:9119/api/pty
```

**Safety:**
- ✅ Dashboard auth token required.
- ⚠️ Depends on remote dashboard running with `--tui`.

**Implementation:**
- SSH tunnel management from Swift.
- WebSocket client.
- Session token acquisition.
- PTY stream parsing.

**Risk:** High (tunnel + WS complexity).

### 5. Local Dashboard WebSocket

**Status:** Blocked.
**Reason:** FastAPI is not installed in the bundled Hermes Studio Python
environment.  The dashboard cannot start.
**Reopens when:** FastAPI ships with Hermes Studio or is installed in a
separate venv.

### 6. Custom Solaris Bridge Daemon

**Status:** Documented for future consideration.
**Reopens when:** SSH paths are exhausted and a richer protocol is needed.

---

## Recommendations

| Priority | Transport | Batch | When |
|----------|-----------|-------|------|
| 1 | SSH read-only command runner | 1 | v0.9 |
| 2 | SSH one-shot `hermes chat -q` | 2 | v0.9 |
| 3 | SSH PTY running `hermes` | 3 | v0.9+ |
| — | Local dashboard WebSocket | — | Blocked indefinitely |
| — | Custom bridge daemon | — | Future if needed |
