# Hermes Companion macOS App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native, premium macOS control surface companion app for Hermes Agent that enables status monitoring, command execution, and real-time diagnostic reporting via a Siri-inspired glassmorphic design.

**Architecture:** MVVM (Model-View-ViewModel) architecture utilizing protocols for services to support seamless migration from Mock data to live HTTP/SSE/WebSocket APIs later. Fully structured inside a macOS-compatible Swift Package Manager (SPM) wrapper to allow easy local compilation, testing, and IDE opening.

**Tech Stack:** Swift 6, SwiftUI (using native Materials, Canvas animations, and NavigationSplitView), macOS 14+, Swift Package Manager.

---

## Directory Structure

```text
~/Documents/Projects/solaris/
├── Package.swift
├── README.md
├── .gitignore
├── docs/
│   └── plans/
│       └── 2026-06-02-hermes-companion.md
├── Sources/
│   └── HermesCompanion/
│       ├── App/
│       │   └── HermesCompanionApp.swift
│       ├── Views/
│       │   ├── MainView.swift
│       │   ├── SidebarView.swift
│       │   ├── DashboardView.swift
│       │   ├── RunsView.swift
│       │   ├── ProvidersView.swift
│       │   └── SettingsView.swift
│       ├── Components/
│       │   ├── HermesOrbView.swift
│       │   ├── QuickActionChip.swift
│       │   ├── StatusCard.swift
│       │   ├── ProviderCard.swift
│       │   ├── LogCard.swift
│       │   ├── CommandResultCard.swift
│       │   ├── ErrorCard.swift
│       │   └── CommandBar.swift
│       ├── Models/
│       │   └── HermesModels.swift
│       ├── ViewModels/
│       │   └── HermesViewModel.swift
│       ├── Services/
│       │   └── HermesService.swift
│       ├── Mock/
│       │   └── MockHermesService.swift
│       └── Utilities/
│           └── Theme.swift
└── Tests/
    └── HermesCompanionTests/
        └── HermesCompanionTests.swift
```

---

## Tasks

### Task 1: Initialize Swift Package Manager & Gitignore
**Files:**
- Create: `Package.swift`
- Create: `.gitignore`

**Step 1: Write Package.swift and .gitignore**
Initialize a standard Swift package targeted for macOS 14+ that compiles an executable app using SwiftPM's executable target definition.

`Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HermesCompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HermesCompanion", targets: ["HermesCompanion"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HermesCompanion",
            dependencies: [],
            path: "Sources/HermesCompanion"
        ),
        .testTarget(
            name: "HermesCompanionTests",
            dependencies: ["HermesCompanion"],
            path: "Tests/HermesCompanionTests"
        )
    ]
)
```

`.gitignore`:
```text
.DS_Store
/.build
/Packages
/GeneratedRecipes
.swiftpm
xcuserdata/
*.xcodeproj
```

**Step 2: Run test compilation**
Create dummy files to compile:
- Create `Sources/HermesCompanion/App/dummy.swift` with an empty main function.
- Run: `swift build`
- Expected: Build successfully with an executable.

**Step 3: Commit**
```bash
git init
git add Package.swift .gitignore
git commit -m "chore: initialize swift package structure"
```

---

### Task 2: Design Utilities, Models, and Service Protocols
**Files:**
- Create: `Sources/HermesCompanion/Utilities/Theme.swift`
- Create: `Sources/HermesCompanion/Models/HermesModels.swift`
- Create: `Sources/HermesCompanion/Services/HermesService.swift`

**Step 1: Implement Theme and Color tokens**
Define premium colors (Hermes Obsidian, Glowing Cyan, Hermes Amber, Hermes Crimson, and Deep Glass materials) and typography styles to ensure a native but futuristic, highly aesthetic control panel.

`Theme.swift`:
```swift
import SwiftUI

struct Theme {
    static let primaryBackground = Color(NSColor.windowBackgroundColor)
    static let glassOverlay = Color.white.opacity(0.05)
    
    // Core brand gradients
    static let hermesGlow = LinearGradient(
        colors: [Color("GlowPrimary"), Color("GlowSecondary")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Custom semantic colors
    static let statusOk = Color.emerald
    static let statusWarning = Color.amber
    static let statusCritical = Color.rose
}

extension Color {
    static let hermesTeal = Color(red: 0.08, green: 0.75, blue: 0.70)
    static let hermesPurple = Color(red: 0.55, green: 0.20, blue: 0.90)
    static let hermesObsidian = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let emerald = Color(red: 0.06, green: 0.72, blue: 0.41)
    static let amber = Color(red: 0.96, green: 0.60, blue: 0.00)
    static let rose = Color(red: 0.88, green: 0.16, blue: 0.32)
}
```

**Step 2: Define domain models**
Define `HermesStatus`, `HermesRun`, `ProviderHealth`, `LogLine`, and response schemas.

`HermesModels.swift`:
```swift
import Foundation

public enum HermesState: String, Codable {
    case idle = "Idle"
    case listening = "Listening"
    case processing = "Processing"
    case error = "Error"
}

public struct HermesStatus: Codable {
    public let state: HermesState
    public let uptimeSeconds: Int
    public let relayConnected: Bool
    public let activeJobsCount: Int
    
    public init(state: HermesState, uptimeSeconds: Int, relayConnected: Bool, activeJobsCount: Int) {
        self.state = state
        self.uptimeSeconds = uptimeSeconds
        self.relayConnected = relayConnected
        self.activeJobsCount = activeJobsCount
    }
}

public struct HermesRun: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let prompt: String
    public let response: String
    public let isSuccess: Bool
    public let durationMs: Int
    
    public init(id: String, timestamp: Date, prompt: String, response: String, isSuccess: Bool, durationMs: Int) {
        self.id = id
        self.timestamp = timestamp
        self.prompt = prompt
        self.response = response
        self.isSuccess = isSuccess
        self.durationMs = durationMs
    }
}

public struct ProviderHealth: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let isOnline: Bool
    public let latencyMs: Int
    public let successRate: Double
    
    public init(name: String, isOnline: Bool, latencyMs: Int, successRate: Double) {
        self.name = name
        self.isOnline = isOnline
        self.latencyMs = latencyMs
        self.successRate = successRate
    }
}

public struct LogLine: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let level: String // "INFO", "WARN", "ERROR"
    public let message: String
    
    public init(id: String, timestamp: Date, level: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct HermesResponse: Codable {
    public let responseText: String
    public let executionTimeMs: Int
    public let success: Bool
    public let createdRun: HermesRun
    
    public init(responseText: String, executionTimeMs: Int, success: Bool, createdRun: HermesRun) {
        self.responseText = responseText
        self.executionTimeMs = executionTimeMs
        self.success = success
        self.createdRun = createdRun
    }
}
```

**Step 3: Define service interfaces**
`HermesService.swift`:
```swift
import Foundation

public protocol HermesService {
    func getStatus() async throws -> HermesStatus
    func getRecentRuns() async throws -> [HermesRun]
    func getProviderHealth() async throws -> [ProviderHealth]
    func getRecentLogs() async throws -> [LogLine]
    func sendCommand(_ command: String) async throws -> HermesResponse
}
```

**Step 4: Commit**
```bash
git add Sources/HermesCompanion/Utilities/Theme.swift Sources/HermesCompanion/Models/HermesModels.swift Sources/HermesCompanion/Services/HermesService.swift
git commit -m "feat: define core models, design tokens, and service protocol"
```

---

### Task 3: Implement Mock Service
**Files:**
- Create: `Sources/HermesCompanion/Mock/MockHermesService.swift`

**Step 1: Write MockHermesService**
Create realistic mocked metrics, providers, recent runs, and status configurations that mimic latency and simulate agent transitions.

`MockHermesService.swift`:
```swift
import Foundation

public class MockHermesService: HermesService {
    private var mockRuns: [HermesRun] = [
        HermesRun(
            id: "run-001",
            timestamp: Date().addingTimeInterval(-3600 * 2),
            prompt: "Summarize top tech news from RSS feeds",
            response: "Fetched 12 feeds. Found 3 key topics: 1. Apple WWDC updates. 2. AI chip market expansion. 3. New open-source LLM releases. Compiled summary into obsidian notes.",
            isSuccess: true,
            durationMs: 4200
        ),
        HermesRun(
            id: "run-002",
            timestamp: Date().addingTimeInterval(-1800),
            prompt: "Monitor GPU temperatures and restart worker if over 85C",
            response: "Checked temperature: 76C. Health check passed. Watchdog logs updated.",
            isSuccess: true,
            durationMs: 1250
        ),
        HermesRun(
            id: "run-003",
            timestamp: Date().addingTimeInterval(-600),
            prompt: "Deploy system metrics cron jobs",
            response: "CRITICAL ERROR: Failed to install cron handler. Insufficient permissions on task schedule.",
            isSuccess: false,
            durationMs: 450
        )
    ]
    
    private var mockProviders: [ProviderHealth] = [
        ProviderHealth(name: "OpenAI API", isOnline: true, latencyMs: 280, successRate: 0.99),
        ProviderHealth(name: "Anthropic API", isOnline: true, latencyMs: 320, successRate: 0.985),
        ProviderHealth(name: "Local Llama3 (Ollama)", isOnline: true, latencyMs: 45, successRate: 1.0),
        ProviderHealth(name: "Groq Cloud Relay", isOnline: false, latencyMs: 0, successRate: 0.0)
    ]
    
    private var mockLogs: [LogLine] = [
        LogLine(id: "log-1", timestamp: Date().addingTimeInterval(-600), level: "INFO", message: "Hermes Core v1.4.2 initialized successfully."),
        LogLine(id: "log-2", timestamp: Date().addingTimeInterval(-480), level: "INFO", message: "Listening for local triggers on port 5080..."),
        LogLine(id: "log-3", timestamp: Date().addingTimeInterval(-300), level: "WARN", message: "Provider Groq Cloud Relay is currently unreachable. Swapping to backup Anthropic API."),
        LogLine(id: "log-4", timestamp: Date().addingTimeInterval(-120), level: "ERROR", message: "Cron deployment script exited with code 1.")
    ]
    
    public init() {}
    
    public func getStatus() async throws -> HermesStatus {
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms simulated network latency
        return HermesStatus(
            state: .idle,
            uptimeSeconds: 86420,
            relayConnected: true,
            activeJobsCount: 0
        )
    }
    
    public func getRecentRuns() async throws -> [HermesRun] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return mockRuns
    }
    
    public func getProviderHealth() async throws -> [ProviderHealth] {
        try await Task.sleep(nanoseconds: 250_000_000)
        return mockProviders
    }
    
    public func getRecentLogs() async throws -> [LogLine] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return mockLogs
    }
    
    public func sendCommand(_ command: String) async throws -> HermesResponse {
        try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s execution
        
        let newRun = HermesRun(
            id: "run-\(UUID().uuidString.prefix(6).lowercased())",
            timestamp: Date(),
            prompt: command,
            response: generateMockResponse(for: command),
            isSuccess: !command.contains("fail"),
            durationMs: Int.random(in: 300...1500)
        )
        
        mockRuns.insert(newRun, at: 0)
        
        // Append execution logs
        mockLogs.append(LogLine(id: UUID().uuidString, timestamp: Date(), level: newRun.isSuccess ? "INFO" : "ERROR", message: "Executed command: '\(command)' - Success: \(newRun.isSuccess)"))
        
        return HermesResponse(
            responseText: newRun.response,
            executionTimeMs: newRun.durationMs,
            success: newRun.isSuccess,
            createdRun: newRun
        )
    }
    
    private func generateMockResponse(for command: String) -> String {
        let cmd = command.lowercased()
        if cmd.contains("health") || cmd.contains("relay") {
            return "All local relays are functioning normally. Relay latency: 12ms. Core API version: 1.4.2."
        } else if cmd.contains("log") {
            return "Parsed latest 50 logs: 2 WARNINGs, 1 ERROR. Top warning: 'Rate limit threshold hit on third-party provider'. System continues operation safely."
        } else if cmd.contains("restart") {
            return "Watchdog triggered a graceful reset on Hermes daemon process. Main server back online in 142ms. Health check OK."
        } else if cmd.contains("test") {
            return "Tested 4 providers. Local Llama: 100% OK. OpenAI: 100% OK. Anthropic: 100% OK. Groq: OFFLINE."
        } else if cmd.contains("fail") {
            return "CRITICAL FAILURE: Operation aborted by host constraints. Code 403: Execution Forbidden."
        }
        return "Command received and processed by Hermes. Task executed successfully in background."
    }
}
```

**Step 2: Commit**
```bash
git add Sources/HermesCompanion/Mock/MockHermesService.swift
git commit -m "feat: implement MockHermesService with latency and logs simulation"
```

---

### Task 4: Develop Core ViewModel
**Files:**
- Create: `Sources/HermesCompanion/ViewModels/HermesViewModel.swift`

**Step 1: Implement HermesViewModel**
Manage reactive state updates, current prompt/input buffers, loaded providers, loaded runs, logs, and diagnostic operations. Connect to `HermesService`.

`HermesViewModel.swift`:
```swift
import Foundation
import Combine

@MainActor
public class HermesViewModel: ObservableObject {
    private let service: HermesService
    
    @Published var status: HermesStatus?
    @Published var runs: [HermesRun] = []
    @Published var providers: [ProviderHealth] = []
    @Published var logs: [LogLine] = []
    
    @Published var currentInput: String = ""
    @Published var isPendingResponse: Bool = false
    @Published var errorMessage: String? = nil
    
    @Published var apiEndpoint: String = "http://127.0.0.1:5080"
    
    public init(service: HermesService) {
        self.service = service
    }
    
    public func loadAllData() async {
        do {
            errorMessage = nil
            // Fetch concurrently
            async let statusFetch = service.getStatus()
            async let runsFetch = service.getRecentRuns()
            async let providersFetch = service.getProviderHealth()
            async let logsFetch = service.getRecentLogs()
            
            self.status = try await statusFetch
            self.runs = try await runsFetch
            self.providers = try await providersFetch
            self.logs = try await logsFetch
        } catch {
            errorMessage = "Failed to synchronize status with Hermes Agent: \(error.localizedDescription)"
        }
    }
    
    public func sendCommand() async {
        let command = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        currentInput = ""
        isPendingResponse = true
        errorMessage = nil
        
        // Simulating immediate transition of visual state orb
        if let currentStatus = status {
            status = HermesStatus(
                state: .processing,
                uptimeSeconds: currentStatus.uptimeSeconds,
                relayConnected: currentStatus.relayConnected,
                activeJobsCount: currentStatus.activeJobsCount + 1
            )
        }
        
        do {
            let response = try await service.sendCommand(command)
            
            // Reload all lists and update states
            async let runsFetch = service.getRecentRuns()
            async let logsFetch = service.getRecentLogs()
            self.runs = try await runsFetch
            self.logs = try await logsFetch
            
            status = try await service.getStatus()
        } catch {
            errorMessage = "Execution failed: \(error.localizedDescription)"
            if let currentStatus = status {
                status = HermesStatus(
                    state: .error,
                    uptimeSeconds: currentStatus.uptimeSeconds,
                    relayConnected: currentStatus.relayConnected,
                    activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                )
            }
        }
        
        isPendingResponse = false
    }
    
    public func executeQuickAction(_ actionName: String) async {
        currentInput = actionName
        await sendCommand()
    }
}
```

**Step 2: Commit**
```bash
git add Sources/HermesCompanion/ViewModels/HermesViewModel.swift
git commit -m "feat: implement HermesViewModel supporting async command flow"
```

---

### Task 5: Build Reusable Cards & Components
**Files:**
- Create: `Sources/HermesCompanion/Components/HermesOrbView.swift`
- Create: `Sources/HermesCompanion/Components/QuickActionChip.swift`
- Create: `Sources/HermesCompanion/Components/StatusCard.swift`
- Create: `Sources/HermesCompanion/Components/ProviderCard.swift`
- Create: `Sources/HermesCompanion/Components/LogCard.swift`
- Create: `Sources/HermesCompanion/Components/CommandResultCard.swift`
- Create: `Sources/HermesCompanion/Components/ErrorCard.swift`
- Create: `Sources/HermesCompanion/Components/CommandBar.swift`

**Step 1: Write Custom Siri-Inspired Abstract Orb (HermesOrbView.swift)**
Use overlapping circles, scaling animations, and glowing radial gradients to create an interactive central visual representing agent thinking, listening, or error states.

`HermesOrbView.swift`:
```swift
import SwiftUI

struct HermesOrbView: View {
    let state: HermesState
    @State private var scale: CGFloat = 1.0
    @State private var rotate: Double = 0.0
    
    var body: some View {
        ZStack {
            // Glow backdrop
            Circle()
                .fill(orbColor.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 20)
                .scaleEffect(scale * 1.2)
            
            // Outer dynamic breathing ring
            Circle()
                .stroke(orbColor.opacity(0.4), lineWidth: 2)
                .frame(width: 110, height: 110)
                .scaleEffect(scale)
            
            // Rotating gradient core representing intelligence
            Circle()
                .fill(
                    LinearGradient(
                        colors: [orbColor, orbColor.opacity(0.5), orbColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(rotate))
                .shadow(color: orbColor.opacity(0.5), radius: 10)
            
            // Central core glyph
            Image(systemName: "bolt.horizontal.fill")
                .foregroundColor(.white)
                .font(.system(size: 24, weight: .bold))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                rotate = 360.0
            }
        }
    }
    
    private var orbColor: Color {
        switch state {
        case .idle: return .hermesTeal
        case .listening: return .hermesPurple
        case .processing: return .amber
        case .error: return .rose
        }
    }
}
```

**Step 2: Create Action Chip (QuickActionChip.swift)**
Provide custom hover-enabled diagnostic command chips.

`QuickActionChip.swift`:
```swift
import SwiftUI

struct QuickActionChip: View {
    let label: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovered
            }
        }
    }
}
```

**Step 3: Create status/uptime card (StatusCard.swift)**
Calendar/Status overview widget.

`StatusCard.swift`:
```swift
import SwiftUI

struct StatusCard: View {
    let status: HermesStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HERMES METRICS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("State")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 8, height: 8)
                        Text(status.state.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uptime")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatUptime(status.uptimeSeconds))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Jobs")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(status.activeJobsCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private var stateColor: Color {
        switch status.state {
        case .idle: return .emerald
        case .listening: return .hermesPurple
        case .processing: return .amber
        case .error: return .rose
        }
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}
```

**Step 4: Create Provider Health view component (ProviderCard.swift)**
Display online latencies.

`ProviderCard.swift`:
```swift
import SwiftUI

struct ProviderCard: View {
    let provider: ProviderHealth
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Text(provider.isOnline ? "Online • \(provider.latencyMs)ms latency" : "Offline")
                    .font(.system(size: 11))
                    .foregroundColor(provider.isOnline ? .white.opacity(0.6) : .rose.opacity(0.8))
            }
            Spacer()
            
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(provider.successRate * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text("success")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Circle()
                    .fill(provider.isOnline ? Color.emerald : Color.rose)
                    .frame(width: 8, height: 8)
                    .shadow(color: provider.isOnline ? Color.emerald.opacity(0.5) : Color.rose.opacity(0.5), radius: 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
```

**Step 5: Create Log component view (LogCard.swift)**
Format warning/info logs dynamically.

`LogCard.swift`:
```swift
import SwiftUI

struct LogCard: View {
    let log: LogLine
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(log.level)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .cornerRadius(4)
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                
                Text(formatTimestamp(log.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private var badgeColor: Color {
        switch log.level {
        case "ERROR": return .rose
        case "WARN": return .amber
        default: return .hermesTeal
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
```

**Step 6: Write CommandResultCard.swift**
Highlight duration, prompts and details.

`CommandResultCard.swift`:
```swift
import SwiftUI

struct CommandResultCard: View {
    let run: HermesRun
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.hermesTeal)
                    Text(run.prompt)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(run.durationMs)ms")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Circle()
                        .fill(run.isSuccess ? Color.emerald : Color.rose)
                        .frame(width: 6, height: 6)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            Text(run.response)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: false)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
```

**Step 7: Write ErrorCard.swift**
Warning component for general control surface errors.

`ErrorCard.swift`:
```swift
import SwiftUI

struct ErrorCard: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.rose)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Alert")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.rose.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.rose.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
```

**Step 8: Write Glassmorphic Bottom CommandBar (CommandBar.swift)**
Contains send actions, placeholder indicators for attachments and voice, and modern focus glows.

`CommandBar.swift`:
```swift
import SwiftUI

struct CommandBar: View {
    @Binding var text: String
    let isPending: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                Image(systemName: "paperclip")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            TextField("Ask Hermes a command...", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 13))
                .onSubmit {
                    if !isPending && !text.isEmpty {
                        onSend()
                    }
                }
            
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            Button(action: onSend) {
                if isPending {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.hermesTeal)
                        .font(.system(size: 20))
                }
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty || isPending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
```

**Step 9: Commit**
```bash
git add Sources/HermesCompanion/Components/*
git commit -m "feat: implement all reusable cards and premium components"
```

---

### Task 6: Build Sidebar and App Views
**Files:**
- Create: `Sources/HermesCompanion/Views/SidebarView.swift`
- Create: `Sources/HermesCompanion/Views/DashboardView.swift`
- Create: `Sources/HermesCompanion/Views/RunsView.swift`
- Create: `Sources/HermesCompanion/Views/ProvidersView.swift`
- Create: `Sources/HermesCompanion/Views/SettingsView.swift`
- Create: `Sources/HermesCompanion/Views/MainView.swift`

**Step 1: Write SidebarView**
Native-looking sidebar containing system run statuses, logs, configuration options.

`SidebarView.swift`:
```swift
import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case runs = "Recent Runs"
    case providers = "Provider Health"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "bolt.horizontal.circle.fill"
        case .runs: return "doc.text.magnifyingglass"
        case .providers: return "network"
        case .settings: return "gearshape.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    
    var body: some View {
        List(selection: $selection) {
            Section("Monitor") {
                ForEach([NavigationItem.dashboard, .runs, .providers]) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                    }
                }
            }
            
            Section("Configure") {
                NavigationLink(value: NavigationItem.settings) {
                    Label(NavigationItem.settings.rawValue, systemImage: NavigationItem.settings.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}
```

**Step 2: Write DashboardView.swift**
Contains the central premium Orb element, quick-actions list, short metrics overview, and scrolling run cards.

`DashboardView.swift`:
```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: HermesViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HermesOrbView(state: viewModel.status?.state ?? .idle)
                    .padding(.top, 10)
                
                Text(viewModel.isPendingResponse ? "Hermes is processing..." : "Hermes is listening")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                if let status = viewModel.status {
                    StatusCard(status: status)
                        .padding(.horizontal)
                }
            }
            
            // Quick action chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickActionChip(label: "Check relay health", icon: "bolt.fill") {
                        Task { await viewModel.executeQuickAction("Check relay health") }
                    }
                    QuickActionChip(label: "Summarize logs", icon: "list.bullet.rectangle") {
                        Task { await viewModel.executeQuickAction("Summarize latest logs") }
                    }
                    QuickActionChip(label: "Restart watchdog", icon: "arrow.clockwise") {
                        Task { await viewModel.executeQuickAction("Restart watchdog") }
                    }
                    QuickActionChip(label: "Test providers", icon: "network") {
                        Task { await viewModel.executeQuickAction("Test providers") }
                    }
                }
                .padding(.horizontal)
            }
            
            // Diagnostic Timeline / Mini-Runs
            VStack(alignment: .leading, spacing: 10) {
                Text("DIAGNOSTIC TIMELINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let error = viewModel.errorMessage {
                            ErrorCard(message: error)
                        }
                        
                        ForEach(viewModel.runs.prefix(2)) { run in
                            CommandResultCard(run: run)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Float command box
            CommandBar(text: $viewModel.currentInput, isPending: viewModel.isPendingResponse) {
                Task { await viewModel.sendCommand() }
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color.hermesObsidian.ignoresSafeArea())
    }
}
```

**Step 3: Write RunsView.swift**
Detailed recent runs view listing logs, times, duration, input/output logs.

`RunsView.swift`:
```swift
import SwiftUI

struct RunsView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var query: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                TextField("Filter runs...", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    let filtered = viewModel.runs.filter {
                        query.isEmpty || $0.prompt.localizedCaseInsensitiveContains(query) || $0.response.localizedCaseInsensitiveContains(query)
                    }
                    
                    ForEach(filtered) { run in
                        CommandResultCard(run: run)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color.hermesObsidian.ignoresSafeArea())
    }
}
```

**Step 4: Write ProvidersView.swift**
Full panel lists providers with latency reports and full logs console view beneath it.

`ProvidersView.swift`:
```swift
import SwiftUI

struct ProvidersView: View {
    @ObservedObject var viewModel: HermesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider Health Status")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .padding([.top, .horizontal])
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.providers) { provider in
                        ProviderCard(provider: provider)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingested Diagnostic Logs")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 10)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.logs) { log in
                                LogCard(log: log)
                                if log.id != viewModel.logs.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color.hermesObsidian.ignoresSafeArea())
    }
}
```

**Step 5: Write SettingsView.swift**
Contains settings forms, enabling connection endpoint mapping to replace mock endpoints.

`SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var showingSaveAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Hermes Integration Endpoint").foregroundColor(.white.opacity(0.5))) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Server Endpoint URL", text: $viewModel.apiEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                    
                    Text("Specify the URL of your local Hermes Agent API relay daemon. E.g. http://localhost:5080.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("App Preference").foregroundColor(.white.opacity(0.5))) {
                Toggle("Launch at Login", isOn: .constant(true))
                Toggle("Keep Window Floating on Top", isOn: .constant(false))
            }
            
            Section {
                Button("Save and Reload Services") {
                    showingSaveAlert = true
                    Task {
                        await viewModel.loadAllData()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.hermesTeal)
            }
        }
        .formStyle(.grouped)
        .background(Color.hermesObsidian.ignoresSafeArea())
        .alert("Settings Updated", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Endpoint updated to \(viewModel.apiEndpoint). Services will sync using this pathway in the future.")
        }
    }
}
```

**Step 6: Write MainView.swift**
Wrap navigation sidebar alongside layout panels using a clean double-column `NavigationSplitView`.

`MainView.swift`:
```swift
import SwiftUI

struct MainView: View {
    @StateObject var viewModel = HermesViewModel(service: MockHermesService())
    @State private var navigationSelection: NavigationItem? = .dashboard
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $navigationSelection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch navigationSelection {
                case .dashboard:
                    DashboardView(viewModel: viewModel)
                case .runs:
                    RunsView(viewModel: viewModel)
                case .providers:
                    ProvidersView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
                case .none:
                    Text("Select an option")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .navigationTitle(navigationSelection?.rawValue ?? "Hermes Companion")
        }
        .task {
            await viewModel.loadAllData()
        }
        .preferredColorScheme(.dark)
    }
}
```

**Step 7: Commit**
```bash
git add Sources/HermesCompanion/Views/*
git commit -m "feat: implement full application views and sidebar navigation"
```

---

### Task 7: Setup App Entrypoint & Tests
**Files:**
- Create: `Sources/HermesCompanion/App/HermesCompanionApp.swift`
- Create: `Tests/HermesCompanionTests/HermesCompanionTests.swift`

**Step 1: Write application entry point (HermesCompanionApp.swift)**
Use `@main` struct with standard App structure so compiler can execute the target.

`HermesCompanionApp.swift`:
```swift
import SwiftUI

@main
struct HermesCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
```

**Step 2: Implement dynamic unit testing (HermesCompanionTests.swift)**
Ensure mock services latency, custom prompt triggers, state operations execute flawlessly.

`HermesCompanionTests.swift`:
```swift
import XCTest
@testable import HermesCompanion

@MainActor
final class HermesCompanionTests: XCTestCase {
    
    func testMockServiceLoad() async throws {
        let service = MockHermesService()
        let status = try await service.getStatus()
        XCTAssertEqual(status.state, .idle)
        XCTAssertTrue(status.relayConnected)
    }
    
    func testSendCommandFlow() async throws {
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        XCTAssertEqual(viewModel.runs.count, 3)
        
        viewModel.currentInput = "Check relay health"
        await viewModel.sendCommand()
        
        XCTAssertEqual(viewModel.runs.count, 4)
        XCTAssertTrue(viewModel.runs[0].prompt == "Check relay health")
        XCTAssertTrue(viewModel.runs[0].isSuccess)
    }
    
    func testQuickActionCommand() async throws {
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        await viewModel.executeQuickAction("test providers")
        
        XCTAssertEqual(viewModel.runs.count, 4)
        XCTAssertEqual(viewModel.runs[0].prompt, "test providers")
        XCTAssertTrue(viewModel.runs[0].response.contains("Tested 4 providers"))
    }
}
```

**Step 3: Run compilation and test execution**
Run: `swift test`
Expected: Tests pass cleanly.

**Step 4: Commit**
```bash
git add Sources/HermesCompanion/App/HermesCompanionApp.swift Tests/HermesCompanionTests/HermesCompanionTests.swift
git commit -m "feat: add App entrypoint and comprehensive unit tests"
```

---

### Task 8: Generate GitHub Repository Polish (README & Docs)
**Files:**
- Create: `README.md`

**Step 1: Write README.md**
Provide high-quality setups, roadmap integrations, SSE stream notes, local REST mappings, architectural separation diagrams, and license markers to make the project instantly attractive on GitHub.

`README.md`:
```markdown
# Hermes Companion ☄️

An elegant, open-source macOS native control surface and diagnostic panel for **Hermes Agent**. Inspired by native macOS assistants, it provides soft glassmorphism, responsive diagnostic visualizations, and low-latency interaction cards to control your local workflows.

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
git clone https://github.com/your-username/solaris.git
cd solaris
swift run
```

### Run Tests
```bash
swift test
```

---

## 🔌 Connection Map: Real API Integration

The app relies on `HermesService` protocol definition. To wire in your actual local server:

1. Replace `MockHermesService()` instantiation in `MainView.swift` with a production service:
```swift
struct LiveHermesService: HermesService {
    let endpoint: URL
    
    func getStatus() async throws -> HermesStatus {
        let (data, _) = try await URLSession.shared.data(from: endpoint.appendingPathComponent("/status"))
        return try JSONDecoder().decode(HermesStatus.self, from: data)
    }
    // ... implement recent runs, logs, and sendCommand via SSE or REST
}
```
2. Configure your custom endpoint under **Settings** view in-app.

---

## 🗺️ Roadmap
- [ ] Connect Live local daemon via WebSocket / Server-Sent Events (SSE).
- [ ] Add active system telemetry graphs for token-per-second counters.
- [ ] Implement local database backup for runs timeline.
- [ ] Build global floating hotkey HUD (Command + Shift + H) to wake up the orb.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
```

**Step 2: Commit**
```bash
git add README.md
git commit -m "docs: write premium GitHub-ready README"
```

---
## Handoff

Plan completed. Ready for step-by-step execution.
