# Architecture Decision: Live Remote Execution Safety Contract

**ADR ID:** SOLARIS-ADR-001
**Created:** 2026-06-04
**Status:** Approved (draft for review)
**Applies to:** Solaris v0.11+
**Supersedes:** v0.10 Phase 7 safety gates (extends, does not replace)

---

## 1. Decision Summary

Solaris v0.11 may add release-build live remote probes for **read-only Hermes availability checks only**. Restart, tunnel, stdin/chat dispatch, long-running commands, filesystem discovery, and arbitrary SSH remain **blocked in release builds**.

The default policy is **disabled**. The user must explicitly opt in. A kill switch immediately reverts to mock mode.

---

## 2. Current Capability Inventory

### 2.1 Existing command enum (`RemoteHermesCommand`)

| Case | Category | Current gate | v0.11 proposal |
|------|----------|-------------|----------------|
| `whichHermes` | Read-only probe | `#if !DEBUG` blocked | Release-allowed (opt-in) |
| `hermesVersion` | Read-only probe | `#if !DEBUG` blocked | Release-allowed (opt-in) |
| `hermesStatus` | Read-only probe | `#if !DEBUG` blocked | Release-allowed (opt-in) |
| `hermesChat` | Stdin dispatch | `EnableDeveloperRemoteChat` + `#if DEBUG` | DEBUG-only (no change) |
| `hermesRestart` | Destructive | `#if !DEBUG` blocked | DEBUG-only (no change) |
| `tunnelStart` | Long-running | `#if !DEBUG` blocked | DEBUG-only (no change) |
| `tunnelStop` | Destructive | `#if !DEBUG` blocked | DEBUG-only (no change) |
| `tunnelStatus` | Read-only probe | Not yet gated separately | Release-allowed (opt-in) |

### 2.2 Existing safety gates

1. **Command enum allowlist**: `RemoteHermesCommand` is a fixed enum — no string-based commands.
2. **SSH direct execution**: `/usr/bin/ssh` used directly, never through a shell.
3. **Shell metacharacter sanitisation**: `verifiedBase()` rejects ` ;|&\`$<>()[]{}#'\"!\\`.
4. **`BatchMode=yes`**: Prevents interactive password prompting.
5. **Stdin cap**: 16KB maximum enforced in `RemoteSSHExecutor`.
6. **`#if !DEBUG` release guard**: All live remote paths return early with `.liveChecksDisabled` in release builds.
7. **`EnableDeveloperRemoteChat`**: Additional UserDefaults gate for chat, only exposed in DEBUG builds.
8. **Mock mode**: `HermesServiceMode.mock` routes all operations through `MockRemoteCommandRunner`.
9. **Output redaction**: `OutputSanitiser` redacts credentialed URLs, bearer tokens, PEM keys, ANSI OSC sequences, and secrets. Streaming holdback prevents partial secret leakage.
10. **Metadata-only logging**: `RemoteCommandInputMetadata` captures byte count, command type, and timestamp — never raw payload content.

### 2.3 Gaps identified

| Gap | Severity | Resolution |
|-----|----------|------------|
| No user opt-in mechanism for release read-only probes | Medium | Add `LiveRemotePolicy` with explicit opt-in |
| No kill switch beyond `#if DEBUG` compile-time gate | Medium | Add runtime disable that reverts to mock |
| No per-probe confirmation in UI | Low | Add confirmation before first probe |
| Tunnel status not separately gated | Low | Gate with same policy as other probes |
| No timeout differentiation for probes vs. long-running | Low | Probes get short timeout (8s), long-running stays DEBUG-only |

---

## 3. Allowed Operations

### 3.1 Release builds (with user opt-in)

Allowed only when `LiveRemotePolicy == .readOnly` and user has confirmed:

- **`which hermes`** — check if Hermes binary exists on remote host. Output is summarized to `hermesFound: Bool` — the full path is never stored or displayed. See Section 5.5 for path disclosure policy.
- **`hermes --version`** — read Hermes version string (first line only).
- **`hermes status`** — read Hermes daemon status summary (first line only).
- **`tunnel-status`** — read tunnel status (if tunnel was started externally). This is a hermes subcommand query — it cannot start, stop, or modify tunnels. See Section 5.6 for query-only guarantee.

**Note:** `hermes gateway status` is NOT currently available in the execution enum (`RemoteHermesCommand`). It exists only in `RemoteCommandBuilder.AllowedRemoteCommand`, which is not in the live execution path. Adding it requires a new `RemoteHermesCommand` case and a separate approval step.

**Properties of allowed operations:**
- Read-only: produce no side effects on the remote host.
- Bounded output: exit immediately with finite stdout/stderr.
- No stdin: none of the allowed operations accept input.
- Short-lived: expected completion within 8 seconds.
- Summarised output: only the first line of stdout is captured; the rest is discarded.

### 3.2 Explicitly forbidden in release builds

| Operation | Reason |
|-----------|--------|
| `hermes restart` | Modifies remote daemon state |
| `hermes chat` | Sends stdin data, produces unbounded output |
| `tunnel-start` | Long-running SSH session, modifies network state |
| `tunnel-stop` | Terminates remote tunnel, modifies state |
| Arbitrary SSH command text | Violates enum-only contract |
| Shell strings (`sh -c`, bash) | Unbounded command execution |
| Remote filesystem browsing | No command for it exists; must stay that way |
| Environment variable dumping | No command for it; must stay that way |
| Config file scraping | No command for it; must stay that way |
| Package installs | No command for it; must stay that way |
| Service modification | No command for it; must stay that way |

### 3.3 DEBUG-only operations

Available only when:
- Build is `DEBUG` **and**
- `EnableDeveloperRemoteChat` is true **and**
- User explicitly enabled the developer console toggle

- `hermes restart`
- `hermes chat` (stdin dispatch)
- `tunnel-start`
- `tunnel-stop`

---

## 4. Policy Design

### 4.1 `LiveRemotePolicy` enum

```swift
/// Controls whether live remote operations are available.
/// Default is `.disabled`. Changing this value at runtime takes
/// effect on the next command — no cached connections survive.
enum LiveRemotePolicy: String, CaseIterable, Codable {
    /// All live remote operations disabled. Mock mode only.
    case disabled

    /// Read-only probes allowed with user opt-in.
    /// whichHermes, hermesVersion, hermesStatus, tunnelStatus.
    /// Note: gatewayStatus requires a new RemoteHermesCommand case (see Section 3.1 note).
    case readOnly

    /// All operations allowed (DEBUG builds only, never in release).
    /// Includes restart, chat, tunnel start/stop.
    case full
}
```

### 4.2 Policy enforcement

```swift
// In RemoteSSHExecutor or a policy wrapper:
func canExecute(_ command: RemoteHermesCommand, policy: LiveRemotePolicy) -> Bool {
    #if !DEBUG
    guard policy == .readOnly else { return false }
    #else
    guard policy != .disabled else { return false }
    #endif

    switch command {
    case .whichHermes, .hermesVersion, .hermesStatus, .tunnelStatus:
        return true  // Read-only probes allowed in both .readOnly and .full
    #if DEBUG
    case .hermesChat, .hermesRestart, .tunnelStart, .tunnelStop:
        return policy == .full
    #else
    case .hermesChat, .hermesRestart, .tunnelStart, .tunnelStop:
        return false  // Never in release
    #endif
    }
}
```

### 4.3 Compile-time reinforcement

The `#if !DEBUG` guard remains as the ultimate safety net. Even if `LiveRemotePolicy` is somehow set to `.full` in a release build, the compile-time guard prevents destructive operations.

---

## 5. Command Contract

### 5.1 Command shape

All remote commands are represented as `RemoteHermesCommand` enum cases — **never as free-form strings**.

Each case maps to a **fixed argument array** returned by `remoteArguments()`:
- No user input becomes an SSH option.
- No command accepts arbitrary remote command text.
- The `hermesCommandBase` field is sanitised for shell metacharacters.

### 5.2 Input validation

| Input | Validation | Applied at |
|-------|-----------|-----------|
| Remote host | `isValidRemoteHost()` — rejects brackets, colons, shell metacharacters (IPv6 bracketed allowed in v0.11) | `RemoteTunnelRequest` |
| Username | Non-empty string (no metacharacter validation currently — consider adding) | `RemoteHostSettings` |
| Port | Integer, default 22 | `RemoteHostSettings` |
| Identity file path | String, optional | `RemoteHostSettings` |
| `hermesCommandBase` | Shell metacharacter sanitisation via `verifiedBase()` | `RemoteHermesCommand` |
| Stdin data | 16KB cap | `RemoteSSHExecutor` |
| Tunnel request | Port range + host validation | `RemoteTunnelRequest` |

### 5.2.1 `hermesCommandBase` trust model

The `hermesCommandBase` field is user-controlled and could point to any executable on the remote host (e.g., `/opt/hermes/bin/hermes-cli` or a custom path). This is intentional — it supports custom Hermes installations.

**Safety argument:** Even if `hermesCommandBase` points to a non-Hermes executable, the fixed argument structure prevents destructive operations:
- `which <base>` — returns a path (informational only)
- `<base> --version` — returns a version string (informational only)
- `<base> status` — likely returns an error (no side effects)

The user already has SSH access to the remote host. Solaris does not elevate their privileges.

**Risk acknowledged:** Information disclosure from a different tool's `--version` output. Acceptable for a tool where the user operates on their own infrastructure.

### 5.3 Output contract

All remote output is a structured `RemoteSSHResult`:

```swift
public struct RemoteSSHResult: Sendable {
    public let command: RemoteHermesCommand
    public let exitCode: Int32
    public let stdout: String        // Must be sanitised before display
    public let stderr: String        // Must be sanitised before display
    public let duration: TimeInterval
    public let timedOut: Bool
}
```

Errors are typed (`ExecutorError`: `.invalidSettings`, `.commandNotAllowed`, `.executionFailed`, `.timedOut`).

### 5.4 Streaming output

Streaming uses `RemoteSSHStreamEvent` enum (DEBUG-only for chat/tunnel — not available in release):
- `.stdout(String)` — sanitised via `StreamingOutputSanitiser`
- `.stderr(String)` — sanitised via `StreamingOutputSanitiser`
- `.status(String)`, `.completed(exitCode:)`, `.failed(String)`, `.timedOut`

### 5.5 `which hermes` path disclosure policy

`which hermes` returns the full filesystem path of the Hermes binary (e.g., `/home/user/.local/bin/hermes`).

**Current behaviour (safe):** The code extracts only a boolean `hermesFound` from the `which` result — the path itself is never stored in `RemoteHermesStatusSnapshot` or displayed in the UI. Error messages from failed `which` are passed through `sanitiseSSHError()`, which redacts filesystem paths.

**Design decision:** Path disclosure is acceptable because:
1. The user already has SSH access to the remote host.
2. The full path is consumed only as a boolean and discarded.
3. Error messages have paths redacted to `[path]`.

This policy must be preserved in Phase 3B when live probes are wired into release builds.

### 5.6 `tunnel-status` query-only guarantee

`tunnel-status` maps to the argument array `["tunnel-status"]` — a fixed hermes subcommand.
- It cannot start tunnels (that requires `tunnel-start`).
- It cannot stop tunnels (that requires `tunnel-stop`).
- It cannot modify SSH configuration or network state.
- It produces bounded stdout (status text) and exits.

This is distinct from SSH tunnel operations (`-L` flag in `tunnelStart`), which remain DEBUG-only.

### 5.7 Dead code note: `RemoteCommandBuilder`

`RemoteCommandBuilder` and its `AllowedRemoteCommand` enum exist in the codebase but are **not in the live execution path**. `RemoteSSHExecutor` uses its own `RemoteHermesCommand` enum and `remoteArguments()` method. `RemoteCommandBuilder` should be consolidated or removed to avoid developer confusion during Phase 3A.

---

## 6. User Approval Model

### 6.1 Opt-in flow

1. User opens Settings → Remote Host Mode.
2. User configures host, username, port, identity file.
3. User taps "Enable Live Remote Checks".
4. Confirmation dialog appears:

   > **Enable Live Remote Probes?**
   >
   > Solaris can run a small read-only probe to check whether Hermes is available on the selected remote host. It will not run arbitrary commands or modify the remote system.
   >
   > Allowed probes: check Hermes binary, version, and status only.
   >
   > **[Cancel]** **[Enable Read-Only Probes]**

5. On confirm: `LiveRemotePolicy` set to `.readOnly`.
6. A persistent indicator appears: "Live Remote: Read-Only Active".

### 6.2 Per-probe confirmation (optional, conservative)

On first probe after opt-in, show a one-time confirmation:

> **Run Remote Probe?**
>
> This will connect to `[host]` via SSH and run `which hermes`.
> No commands will be executed beyond the read-only probe.
>
> **[Cancel]** **[Run Probe]**

After first successful probe, subsequent probes run without per-action confirmation (reduces friction for repeated status checks).

### 6.3 Blocked operation display

For operations blocked by policy:

> This operation is disabled in release builds.

For operations blocked by policy + DEBUG:

> This operation is disabled. Enable it in Developer Console (DEBUG builds only).

### 6.4 UI must never suggest general SSH capability

The Settings UI labels must say:
- "Remote Hermes Status" — not "Remote SSH Terminal"
- "Check Hermes Availability" — not "Run Remote Command"
- No general-purpose command input field exists or will exist.

---

## 7. Logging and Redaction Policy

### 7.1 What is logged

| Data | Format | Example |
|------|--------|---------|
| Command type | Enum case name | `whichHermes` |
| Timestamp | ISO 8601 | `2026-06-04T02:30:00Z` |
| Duration | Seconds | `0.847` |
| Exit code | Int32 | `0` |
| Stdout/stderr length | Character count | `142` |
| Connection state | Enum case | `heartbeatPassed` |
| Stdin metadata (DEBUG only) | `RemoteCommandInputMetadata` | byte count, sanitised first-line hint |

### 7.2 What is NOT logged

- Raw stdin payload content.
- SSH private key material or passphrases.
- Bearer tokens, API keys, Authorization headers, Cookie headers.
- Credentialed URLs (only after redaction).
- Raw unbounded stdout/stderr.
- Remote environment variables.
- SSH agent socket paths.
- Remote filesystem contents.
- User passwords or credential material of any kind.

### 7.3 Redaction path

All remote output passes through `OutputSanitiser.sanitise()` or `StreamingOutputSanitiser.appendAndSanitise()` before:
- Display in the UI.
- Storage in any log.
- Return to caller.

Redaction covers:
- Credentialed URLs: `https://user:pass@host` → `https://[REDACTED_CREDENTIALS]@host`
- Bearer tokens: `Authorization: Bearer sk-...` → `Authorization: Bearer [REDACTED_BEARER_TOKEN]`
- PEM private keys: full block redaction
- Secret assignments: `SECRET=xxx` → `SECRET=[REDACTED_SECRET]`
- ANSI OSC sequences: stripped
- Output truncation: 100KB hard cap

### 7.4 Output bounds

| Dimension | Limit |
|-----------|-------|
| Single stdout/stderr result | 100KB (truncated) |
| Streaming chunk size | 4096 bytes |
| Streaming holdback buffer | Flush on newline or 4KB |
| Persistent log entries | Sanitised summary only |
| Stdin payload | 16KB hard cap |

---

## 8. Failure States and Recovery

### 8.1 Failure state machine

| State | Meaning | Recovery |
|-------|---------|----------|
| `.notConfigured` | No remote host set | User configures host |
| `.localValidationFailed` | Host/username invalid locally | User fixes settings |
| `.sshPreflightFailed` | SSH agent/key issue | User fixes SSH setup |
| `.liveChecksDisabled` | Policy is `.disabled` | User enables live remote |
| `.verifying` | Probe in progress | Wait or cancel |
| `.heartbeatPassed` | Probe succeeded | Normal operation |
| `.heartbeatFailed` | Probe failed (SSH/network) | Retry (max 3) or go offline |
| `.retryExhausted` | 3 retries failed | Display error, suggest manual check |

### 8.2 Retry policy

- **Probes**: Max 3 retries with exponential backoff (1s, 2s, 4s).
- **Long-running operations (DEBUG only)**: No automatic retry — user must re-initiate.
- **Authentication failure**: No retry — user must fix credentials.
- **Timeout**: Single retry only (the timeout may be transient).

### 8.3 Timeout policy

| Operation | Timeout | Rationale |
|-----------|---------|-----------|
| Read-only probes | 8 seconds | Fast commands, bounded output |
| SSH connect | 5 seconds | `ConnectTimeout=5` in SSH options |
| Stdin/chat (DEBUG only) | 30 seconds | May need time for response |
| Tunnel operations (DEBUG only) | 30 seconds | SSH tunnel establishment |

### 8.4 Specific failure messages (sanitised)

| Failure | User-facing message |
|---------|-------------------|
| Host unreachable | "Could not connect to remote host. Check that the host is online and accessible." |
| Auth failed | "SSH authentication failed. Verify your key is loaded in ssh-agent." |
| Hermes not found | "Hermes was not found on the remote host. Install Hermes or update the command path." |
| Hermes not running | "Hermes is installed but not running on the remote host." |
| Timeout | "Remote probe timed out. The host may be slow or unreachable." |
| Network error | "A network error occurred. Check your connection and try again." |

All messages are static strings — no dynamic content from remote output.

---

## 9. Kill Switch

### 9.1 Design

A single `AppStorage("LiveRemotePolicy")` setting controls live remote access.

- Setting to `.disabled` immediately reverts to mock mode.
- Takes effect on the **next command** — no cached live connections survive.
- Does **not** require app restart.
- Visible in Settings as "Live Remote: Disabled / Read-Only / Full".

### 9.2 Compile-time reinforcement

Even with the runtime kill switch, `#if !DEBUG` remains the ultimate guard:
- Release builds cannot reach `.full` policy — the compile-time guard blocks destructive operations regardless of policy value.
- If the policy is somehow corrupted to `.full` in a release build, the `#if !DEBUG` check returns `.liveChecksDisabled`.

### 9.3 Default on fresh install

`LiveRemotePolicy` defaults to `.disabled`. The user must explicitly opt in.

### 9.4 Rollback strategy

If a live remote execution bug is discovered in production:
1. Set default to `.disabled` in the next point release.
2. Add a server-side kill switch check (future: check a static URL for a disable flag).
3. Ship a hotfix that adds additional guards.
4. The `#if !DEBUG` compile-time gate is always present and cannot be removed by configuration.

---

## 10. Test Plan

### 10.1 Unit tests (required before implementation)

| Test | Purpose |
|------|---------|
| `testLiveRemotePolicyDisabledBlocksAll` | `.disabled` blocks every command |
| `testLiveRemotePolicyReadOnlyAllowsProbes` | `.readOnly` allows `which`, `version`, `status` |
| `testLiveRemotePolicyReadOnlyBlocksDestructive` | `.readOnly` blocks `restart`, `chat`, `tunnel` |
| `testLiveRemotePolicyFullRequiresDebug` | `.full` only works in `#if DEBUG` |
| `testCommandEnumContainsNoArbitraryCommand` | `RemoteHermesCommand` has no free-form case |
| `testCommandArgumentsContainNoUserSSHOptions` | `remoteArguments()` never produces `-o` or `--` from user input |
| `testShellMetacharacterRejection` | `verifiedBase()` rejects all forbidden characters |
| `testStdinCapEnforced` | >16KB stdin rejected |
| `testOutputSanitiserCredentialedURL` | Credentialed URLs redacted |
| `testOutputSanitiserBearerToken` | Bearer tokens redacted |
| `testOutputSanitiserPEMKey` | PEM blocks redacted |
| `testReleaseGateBlocksRestartInRelease` | `#if !DEBUG` blocks restart |
| `testReleaseGateBlocksChatInRelease` | `#if !DEBUG` blocks chat |
| `testReleaseGateBlocksTunnelInRelease` | `#if !DEBUG` blocks tunnel |
| `testLiveRemotePolicyDefaultIsDisabled` | Fresh install has `.disabled` |
| `testIPv6BracketedHostAccepted` | v0.11 bracket validation (already exists) |
| `testIPv6UnbracketedRejected` | Unbracketed IPv6 rejected (already exists) |

### 10.2 No-go tests (must pass before any implementation)

These tests must be written and passing before Phase 3 implementation begins:

| No-go test | Assertion |
|------------|-----------|
| `testArbitrarySSHCommandRejected` | No code path accepts free-form SSH commands |
| `testShellMetacharactersNeverReachSSH` | `; \| & \` $ ( )` never appear in SSH arguments |
| `testReleaseBuildNeverRunsRestart` | `restartRemoteDaemon` returns `.liveChecksDisabled` in release |
| `testReleaseBuildNeverRunsChat` | Chat path returns error in release |
| `testReleaseBuildNeverStartsTunnel` | Tunnel start returns `.liveChecksDisabled` in release |
| `testReleaseBuildNeverStopsTunnel` | Tunnel stop returns `.liveChecksDisabled` in release (separate gate) |
| `testRawSecretNeverLogged` | `RemoteCommandInputMetadata` never contains raw stdin |
| `testRawStdoutNeverLogged` | Log entries contain only sanitised summaries |
| `testLiveRemotePolicyCannotBeFullInRelease` | Even with UserDefaults override, release blocks `.full` |
| `testWhichHermesPathNotStored` | `which hermes` output is boolean only — path never in snapshot or UI |
| `testTunnelStatusIsQueryOnly` | `tunnel-status` arguments cannot start/stop tunnels |
| `testUserConfirmationRequiredBeforeProbe` | First probe requires confirmation dialog (policy gate) |
| `testEnvConfigDumpingForbidden` | No enum case exists for env, printenv, cat, or config reading |
| `testFilesystemBrowsingForbidden` | No enum case exists for ls, find, or filesystem commands |

### 10.3 CI checks

- All existing 171 tests must continue to pass.
- New no-go tests must pass.
- `secret-scan.sh` must pass.
- `smoke-test.sh` must pass.
- `swift build` and `swift build -c release` must pass.

### 10.4 Manual smoke checks

| Check | Method |
|-------|--------|
| Release build shows "Live checks disabled" | Build release, open app, check remote section |
| DEBUG build respects policy toggle | Toggle policy, verify probe behaviour |
| Kill switch works | Set to `.disabled`, verify immediate mock reversion |
| Output redaction in UI | Run probe against host that returns sensitive data |

---

## 11. Implementation Phases

### Phase 3A: Policy infrastructure (first code batch)
- Add `LiveRemotePolicy` enum.
- Add `AppStorage("LiveRemotePolicy")` to `HermesViewModel`.
- Add policy check in `RemoteSSHExecutor` (or a policy wrapper).
- Write all no-go tests.
- **Scope restriction:** Phase 3A does NOT remove or modify existing `#if !DEBUG` release blocks. It adds policy infrastructure alongside them. Phase 3B is the step that wires read-only probes through the live path.
- **Gate:** All no-go tests pass before proceeding.

### Phase 3B: Release probe enablement
- Add opt-in UI (Settings toggle + confirmation dialog).
- Route `whichHermes`, `hermesVersion`, `hermesStatus` through live path when policy is `.readOnly`.
- Add per-probe confirmation for first use.
- Add "Live Remote: Read-Only Active" indicator.
- **Gate:** CI passes, no-go tests still pass, manual smoke check passes.

### Phase 3C: Kill switch and diagnostics
- Wire the kill switch to immediately revert to mock mode.
- Add connection state logging with sanitised output.
- Add timeout differentiation for probes vs. long-running.
- **Gate:** Full test suite passes, manual kill switch test passes.

### Phase 3D (future, separate approval): Remote Hermes discovery
- Sequential probe flow: `which` → `version` → `status`.
- UI integration for discovery results.
- **Gate:** Phase 3A–3C complete and stable.

---

## 12. Explicit Non-Goals

These are **out of scope** for v0.11 and must not be implemented without a separate architecture decision:

1. **Arbitrary SSH command execution** — Solaris is not a terminal emulator.
2. **Remote filesystem browsing** — no `ls`, `find`, `cat` on remote host.
3. **Remote environment inspection** — no `env`, `printenv`, remote config reading.
4. **Remote package management** — no `apt`, `brew`, `pip` on remote host.
5. **Remote service management beyond Hermes** — no `systemctl`, `launchctl`.
6. **Remote port forwarding beyond documented tunnel** — no dynamic port allocation.
7. **Multi-hop SSH** — no `ProxyJump`, `ProxyCommand`.
8. **SSH key management** — no key generation, passphrase handling, agent management.
9. **Remote shell sessions** — no interactive shells, PTY allocation, or terminal emulation.
10. **Credential storage** — Solaris never stores SSH passwords, passphrases, or private key material.
11. **Server-side kill switch** — future consideration, not in v0.11.
12. **Remote Hermes installation** — Solaris checks for Hermes but never installs it.

---

## 13. Review and Approval

This document must be reviewed and approved before any Phase 3 implementation begins.

**Reviewers:** (to be assigned)
**Approval date:** (pending)
**Approval criteria:**
- [ ] Release allowlist reviewed and accepted
- [ ] DEBUG-only operations reviewed and accepted
- [ ] Forbidden operations reviewed and accepted
- [ ] Kill switch design reviewed and accepted
- [ ] No-go tests reviewed and accepted
- [ ] User approval model reviewed and accepted
- [ ] Logging/redaction policy reviewed and accepted
- [ ] Non-goals acknowledged

---

*Solaris v0.11 Phase 3 — Live Remote Execution Architecture Gate*
*This document is the authoritative safety contract for live remote execution.*
