import SwiftUI

// MARK: - Diagnostics Menu Commands

/// Adds a "Diagnostics" menu to the macOS menu bar with a ⌘R shortcut for
/// safe, read-only diagnostics refresh. The command is only enabled when the
/// Local Diagnostics view is active and no refresh is already running.
struct DiagnosticsCommands: Commands {
    @FocusedValue(\.hermesViewModel) private var viewModel: HermesViewModel?
    @FocusedValue(\.navigationSelection) private var navigationSelection: NavigationItem?

    /// True only when Local Diagnostics is the active view and the viewModel is reachable.
    private var isDiagnosticsActive: Bool {
        navigationSelection == .providers && viewModel != nil
    }

    /// True when a refresh is currently in progress (prevents double-triggering).
    private var isRefreshing: Bool {
        viewModel?.isRefreshingDiagnostics ?? false
    }

    var body: some Commands {
        CommandMenu("Diagnostics") {
            Button("Refresh Diagnostics") {
                guard isDiagnosticsActive, !isRefreshing, let vm = viewModel else { return }
                Task {
                    await vm.refreshDiagnostics()
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!isDiagnosticsActive || isRefreshing)
            .accessibilityLabel("Refresh local diagnostics")
            .accessibilityHint("Runs read-only diagnostics checks. Keyboard shortcut Command R.")

            Divider()

            Button("Export Redacted Diagnostics\u{2026}") {
                guard isDiagnosticsActive, let vm = viewModel else { return }
                vm.exportRedactedDiagnosticsSummary()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!isDiagnosticsActive)
            .accessibilityLabel("Export redacted diagnostics summary to file")
            .accessibilityHint("Saves a privacy-safe diagnostics summary to a text file. Keyboard shortcut Command Shift E.")

            Divider()

            Button(viewModel?.isDiagnosticsLogPaused == true ? "Resume Diagnostics Logs" : "Pause Diagnostics Logs") {
                guard isDiagnosticsActive, let vm = viewModel else { return }
                vm.toggleDiagnosticsLogPause()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!isDiagnosticsActive)
            .accessibilityLabel(viewModel?.isDiagnosticsLogPaused == true ? "Resume diagnostics log updates" : "Pause diagnostics log updates")
            .accessibilityHint("Freezes or resumes the visible diagnostics log display. Keyboard shortcut Command Shift P.")
        }
    }
}
