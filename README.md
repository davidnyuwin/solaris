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

## 🔌 Connection Map: Real API Integration

The app uses `DynamicHermesService` by default. This proxy dynamically switches between the mock data provider and the live REST integration depending on the **Developer Mock Data Mode** toggle in your in-app **Settings**:

*   **Mock Service (default):** Safely isolated inside a local Swift actor (`MockHermesService`) for offline design iterations.
*   **Live REST Service (`LiveHermesService`):** Connects directly to the verified Hermes Studio local endpoint at **`http://127.0.0.1:9119`**.

During **Phase 1**, the live service supports:
1. `GET /api/status` mapped from raw DTOs to local `HermesStatus` states.
2. `GET /api/sessions` (runs history) mapped to lists of `HermesRun`.
3. `GET /api/logs` mapped and parsed into diagnostic `LogLine` consoles.

*Note: Live command submissions and chat sessions are disabled or marked offline in Phase 1 pending future WebSocket integration.*

---

## 🗺️ Roadmap
- [ ] Connect Live local daemon via WebSocket / Server-Sent Events (SSE).
- [ ] Add active system telemetry graphs for token-per-second counters.
- [ ] Implement local database backup for runs timeline.
- [ ] Build global floating hotkey HUD (Command + Shift + H) to wake up the orb.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
