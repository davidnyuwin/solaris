# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
