# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- Manual refresh control for Local Diagnostics
- Last checked timestamp for diagnostics refreshes
- Refreshing/error states for diagnostics updates
- Pause/resume control for diagnostics log display
- Copy redacted diagnostics summary action
- Conservative auto-refresh interval selector for Local Diagnostics (Manual / 30 sec / 1 min / 5 min)
- Cancellation-aware diagnostics refresh scheduler (stops on view disappear, skips overlapping sweeps)
- Persistent default-on Privacy Mode for diagnostics views
- Accessibility labels, hints, and values for Local Diagnostics controls and status cards

### Security
- Copied diagnostics summaries redact local paths, process IDs, and token-like strings
- Auto-refresh uses only existing read-only diagnostics paths
- Auto-refresh prevents overlapping refresh sweeps
- Privacy Mode remains default-on via `@AppStorage("DiagnosticsPrivacyModeEnabled")`

---

## v0.6.0 - Profile discovery threat model

### Added
- Threat model for future Local Profiles Discovery
- Safety classification for potential Hermes config/profile fields
- Integration option analysis for profile discovery approaches
- Guardrails for future config/profile-related work

### Security
- Confirms Solaris must not read `~/.hermes/config.yaml` directly
- Confirms Solaris must not surface `hermes config show`
- Blocks raw display of API keys, tokens, webhooks, authorization headers, channel IDs, account IDs, private URLs, and absolute local paths
- Requires explicit allowlists and redaction before any future profile metadata implementation

### Decision
- Local Profiles Discovery is intentionally deferred.
- The only currently safe local integration path remains the existing read-only CLI status wrapper.
- No profile/config reading is implemented in this release.

### Notes
- v0.6.0 is a documentation/security milestone.
- Future profile discovery requires a safe Hermes-provided summary command or an explicitly redacted, opt-in metadata pathway.

---

## v0.5.0 - Read-only CLI hardening

### Added
- Sanitized parser fixtures for Hermes CLI output
- CI-backed parser tests for read-only Hermes CLI parsing
- CLI availability/failure state handling
- Local Diagnostics CLI status row
- Package version alignment for `Solaris-v0.5.0-dev.zip`

### Changed
- Hardened parsing for missing fields, empty output, timeout, non-zero exit, and unexpected CLI output
- Improved privacy redaction for local paths in parsed CLI output
- Updated GitHub Actions packaging artifact to use the v0.5 development package name

### Security
- Maintains strict read-only CLI allowlist
- Does not execute shell commands
- Does not accept arbitrary CLI arguments
- Does not call `hermes send`, `hermes model`, `model set`, `gateway restart`, `gateway stop`, or `hermes config show`

### Notes
- Local `swift test` may fail when only Command Line Tools are installed because XCTest is unavailable.
- GitHub Actions macOS runners execute parser tests successfully using full Xcode.
- Live command/control remains unimplemented.
- Local Profiles Discovery is intentionally deferred.

---

## [0.4.0] - 2026-06-02

### Added
- Read-only Hermes CLI executor using Swift `Process`
- Strict allowlist for safe CLI commands
- Defensive plain-text parsers for `hermes status` and `hermes gateway status`
- Local Diagnostics enrichment for active provider, active model, gateway state, and recent gateway events
- CLI output path redaction for local privacy

### Security
- Blocks mutating or external side-effect commands, including `hermes send`, `hermes model set`, and gateway lifecycle commands
- Does not use shell execution
- Does not accept arbitrary user-provided command arguments
- Does not surface `hermes config show` in UI

### Notes
- Hermes CLI does not currently provide JSON output for these read-only commands.
- Parsing is based on stable text prefixes and degrades gracefully if output changes.
- This is not live command/control.
- WebSocket and command transport remain unimplemented.

---

## [0.3.0] - 2026-06-02

### Added
- Local `.app` bundle packaging workflow
- Solaris app icon bundling pipeline
- Optional ad-hoc signing for local code integrity
- Local ZIP artifact generation
- GitHub Actions CI for build and packaging validation
- CI artifact upload for development testing

### Notes
- The app bundle is not notarized.
- The app bundle is not Developer ID signed.
- The app is not sandboxed.
- Ad-hoc signing is for local integrity only.
- Local Diagnostics Mode may require future design changes before sandboxing is viable.

---

## [0.2.0] - 2026-06-02

This release introduces **Solaris v0.2 Visual Polish**, significantly closing layout, material, and visual gaps against our original design concept mockups.

### Added
- Polished Dashboard hero layout with context rail
- Volumetric Solaris orb
- Glassmorphic app backdrop
- Local Diagnostics interface with grouped panels
- Monospaced diagnostics log console
- Severity badges and process status rows
- Privacy Mode for local diagnostics details
- Custom Settings interface with mode cards and endpoint panel
- Runtime screenshots for Dashboard, Local Diagnostics, and Settings
- Default and strict smoke test modes
- Targeted secret scan script

### Changed
- Replaced default Settings form with custom Solaris cards
- Renamed provider-focused UI language to Local Diagnostics where appropriate
- Improved README presentation using actual runtime screenshots

### Notes
- Mock Mode remains the safest default mode.
- Local Diagnostics Mode is useful today.
- Experimental REST Mode remains read-only and requires a running Hermes dashboard API.
- WebSocket and live command transport are not implemented yet.

---

## [0.1.0] - 2026-06-02

This is the initial public release of **Solaris**, a native macOS companion and control surface for Hermes Agent.

### Added
- **Visual Design:** Polished Siri-style assistant interface with glassmorphism, animated ambient orb reflecting system states, and structured diagnostic cards.
- **Mock Mode:** A robust in-memory mock service layer utilizing a local Swift actor (`MockHermesService`) to return simulated daemon telemetry, prompt runs, and log streams.
- **Local Diagnostics Mode:** A completely offline, non-network diagnostics scanner (`LocalHermesDiagnosticsService`) inspecting machine state using standard `/usr/bin/pgrep`, `/bin/ps`, and `/usr/sbin/lsof` commands. Directly reads and parses live log files from `~/.hermes/logs/agent.log` and `~/.hermes/logs/gateway.log` into the UI log viewer.
- **Experimental REST Mode:** A verified live service layer (`LiveHermesService`) mapped and audited against the underlying Hermes Studio FastAPI codebase, prepared to ingest REST resources when the local web API is running.
- **Developer Settings View:** A grouping section allowing developers to picker-select between the three integration modes (Mock, Experimental REST, Local Diagnostics) and reload active states on the fly.
- **Security Safeguards:** Added a robust `SECURITY.md` guideline and warning framework strictly against committing credentials, PIDs, or system log files.
