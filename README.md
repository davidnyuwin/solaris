# Hermes Companion ☄️

An elegant, open-source macOS native control surface and diagnostic panel for **Hermes Agent**. Inspired by native macOS assistant designs, it provides soft glassmorphism, responsive diagnostic visualizations, and low-latency interaction cards to control your local workflows.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![macOS: 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)
![Swift: 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)

---

## 🎨 Visual Design & Inspiration

Hermes Companion is built as a **desktop control panel** rather than a generic chat shell:
- **Abstract Ambient Orb**: A glowing, breathing SwiftUI canvas visualizing the current Hermes state (*listening, processing, speaking, or error*).
- **Glassmorphic Sidebar**: Translucent macOS native material listing active hosts, connections, and health configurations.
- **Structured Cards**: Distinct responsive tiles displaying provider latency metrics, parsed error logs, and execution summaries.
- **Capsule Command Bar**: Quick bottom command bar with micro-actions and attachment slots.

---

## ⚙️ Architecture

The app is structured strictly around **MVVM (Model-View-ViewModel)** and uses Swift concurrency (`async/await`) and service protocols.

```text
Sources/HermesCompanion/
  ├── App/             # @main App Entry Point
  ├── Views/           # NavigationSplitView and full pages (Dashboard, Settings, etc.)
  ├── Components/      # Animated Orb, Cards (Provider, Log, Result, CommandBar)
  ├── Models/          # Plain struct schemas (HermesStatus, ProviderHealth, LogLine)
  ├── ViewModels/      # Main UI state controller handling commands & action signals
  └── Services/        # Protocol-defined network adapters (Mock & Production API pathways)
```

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0 or newer.
- Xcode 15.0+ or command-line Swift toolchain.

### Build and Run with Terminal
To clone and run immediately from your macOS shell:
```bash
# Clone the repository
git clone https://github.com/your-username/solaris.git
cd solaris

# Compile and run the app
swift run
```

### Run Tests
If your local toolchain is connected to a full Xcode app bundle, you can execute standard unit tests:
```bash
swift test
```

---

## 🔌 Connection Map: Three Service Integration Modes

The app uses a `DynamicHermesService` orchestrator that switches the underlying integration engine dynamically depending on your choice in the in-app **Settings**:

1.  **Mock Mode (Default):** Safely isolated inside a local Swift actor (`MockHermesService`) for offline design iterations and public demos. Returns beautiful, realistic simulated metrics, active timeline logs, and quick actions.
2.  **Experimental REST Mode:** Connects to the local web server endpoint on `http://127.0.0.1:9119` using `LiveHermesService`. Fully mapped and validated against the Hermes Studio daemon code, but currently offline due to missing server-side dependencies (`fastapi` / `uvicorn`) in this local installation.
3.  **Local Diagnostics Mode:** A completely offline, non-network diagnostic scanner (`LocalHermesDiagnosticsService`). It leverages safe shell process inspection (`pgrep`/`ps`) and filesystem scanning to discover if the background gateway daemon is running, inspects `lsof` to scan port listeners, and directly reads and tokenizes live logging from `~/.hermes/logs/agent.log` and `~/.hermes/logs/gateway.log` to populate the diagnostic log terminal in real time.

---

## 🔍 Diagnostic Testing & Smoke Tests

To verify endpoint connectivity without relying on standard unit test compilations, a lightweight bash test utility is provided:

```bash
# Execute local REST endpoint probes
./scripts/smoke-test.sh
```

### ⚠️ Phase 1 Boundaries & Technical Limitations
*   **Local Web Server Offline:** Direct system diagnostic checks confirmed that the bundled Python interpreter inside `/Applications/Hermes Studio.app` is **missing the FastAPI and Uvicorn packages**. Consequently, the local dashboard REST server cannot start and port **`9119`** does not listen. 
*   **Mock Mode Default:** Because the local REST API is unavailable, the application operates in **Mock Data Mode** by default to maintain active UI/UX iterations. `LiveHermesService` remains fully implemented and verified against the daemon codebase, serving as a future-compatible integration once the Python dependencies are resolved.
*   **Read-Only Scope:** Phase 1 integration maps status values, session timelines, and trace console outputs over REST.
*   **Commands Unimplemented:** Sending command prompts in live mode is currently blocked; all submissions report a custom `"Live command transport not implemented yet"` response.
*   **Mocked Telemetries:** Active model performance latency health (`ProviderHealth`) remains safely mocked until a dedicated server health-check API is confirmed.

---

## 🗺️ Roadmap
- [ ] Connect Live local daemon via WebSocket / Server-Sent Events (SSE).
- [ ] Add active system telemetry graphs for token-per-second counters.
- [ ] Implement local database backup for runs timeline.
- [ ] Build global floating hotkey HUD (Command + Shift + H) to wake up the orb.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
