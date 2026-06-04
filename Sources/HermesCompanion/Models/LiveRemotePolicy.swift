import Foundation

// MARK: - Live Remote Policy

/// Controls whether live remote operations are available.
/// Default is `.disabled`. Changing this value at runtime takes
/// effect on the next command — no cached connections survive.
///
/// Safety contract (SOLARIS-ADR-001):
/// - `.disabled`: All live remote operations disabled. Mock/local diagnostics only.
/// - `.readOnlyProbes`: Read-only probes (which, version, status, tunnel-status) with user opt-in.
/// - `.developerFull`: All operations allowed. **DEBUG builds only** — never in release.
public enum LiveRemotePolicy: String, Codable, Equatable, Sendable, CaseIterable {
    /// All live remote operations disabled. Mock mode only.
    case disabled

    /// Read-only probes allowed with user opt-in.
    /// whichHermes, hermesVersion, hermesStatus, tunnelStatus only.
    case readOnlyProbes

    /// All operations allowed (DEBUG builds only, never in release).
    /// Includes restart, chat, tunnel start/stop.
    #if DEBUG
    case developerFull
    #endif

    /// The UserDefaults key for persisting the policy.
    public static let storageKey = "LiveRemotePolicy"

    /// Load the current policy from UserDefaults, defaulting to `.disabled`.
    public static func load() -> LiveRemotePolicy {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else {
            return .disabled
        }
        return LiveRemotePolicy(rawValue: raw) ?? .disabled
    }

    /// Persist the policy to UserDefaults.
    public func save() {
        UserDefaults.standard.set(rawValue, forKey: LiveRemotePolicy.storageKey)
    }
}

// MARK: - Live Remote Operations

/// All possible live remote operations, including forbidden ones.
/// Forbidden cases exist so the policy evaluator can explicitly reject them
/// and tests can prove they are unreachable.
public enum LiveRemoteOperation: String, Codable, Equatable, Sendable, CaseIterable {
    // Read-only probes (allowed in release with opt-in)
    case findHermesBinary
    case hermesVersion
    case hermesStatus
    case tunnelStatus

    // Destructive/interactive (DEBUG-only)
    case hermesRestart
    case hermesChat
    case tunnelStart
    case tunnelStop

    // Permanently forbidden (never allowed)
    case arbitraryCommand
    case filesystemBrowse
    case environmentDump
    case configDump
}

// MARK: - Policy Decision

/// Result of a policy evaluation — either allowed or blocked with a reason.
public enum LiveRemoteDecision: Equatable, Sendable {
    case allowed
    case blocked(reason: LiveRemoteBlockReason)
}

/// Reasons why a live remote operation was blocked.
public enum LiveRemoteBlockReason: String, Codable, Equatable, Sendable, CaseIterable {
    /// Policy is `.disabled` — all live operations blocked.
    case policyDisabled
    /// User has not yet confirmed the probe opt-in dialog.
    case requiresUserApproval
    /// Operation requires DEBUG build and/or developer toggle.
    case debugOnly
    /// Operation is permanently forbidden by the safety contract.
    case forbidden
    /// Input validation failed (invalid host, empty fields).
    case invalidInput
    /// Operation is blocked in release builds by compile-time gate.
    case releaseBuildBlocked
}

// MARK: - Policy Evaluator

/// Pure function evaluator — deterministic, no side effects, no execution.
/// Does not run any commands. Only evaluates policy rules.
public struct LiveRemotePolicyEvaluator: Sendable {

    /// Evaluate whether a given operation is permitted under the current policy.
    ///
    /// - Parameters:
    ///   - operation: The operation to evaluate.
    ///   - policy: The current live remote policy.
    ///   - userApproved: Whether the user has confirmed the opt-in dialog.
    ///   - isDeveloperRemoteEnabled: Whether the DEBUG-only developer toggle is on.
    ///   - isValidHost: Whether the remote host configuration passes validation.
    /// - Returns: A `LiveRemoteDecision` — `.allowed` or `.blocked(reason:)`.
    public static func canExecute(
        _ operation: LiveRemoteOperation,
        policy: LiveRemotePolicy,
        userApproved: Bool,
        isDeveloperRemoteEnabled: Bool,
        isValidHost: Bool = true
    ) -> LiveRemoteDecision {
        // 1. Forbidden operations are always blocked regardless of policy.
        switch operation {
        case .arbitraryCommand, .filesystemBrowse, .environmentDump, .configDump:
            return .blocked(reason: .forbidden)
        default:
            break
        }

        // 2. Policy disabled blocks everything.
        if policy == .disabled {
            return .blocked(reason: .policyDisabled)
        }

        // 3. Input validation.
        if !isValidHost {
            return .blocked(reason: .invalidInput)
        }

        // 4. Read-only probes: allowed in .readOnlyProbes with user approval.
        let readOnlyProbes: Set<LiveRemoteOperation> = [
            .findHermesBinary, .hermesVersion, .hermesStatus, .tunnelStatus
        ]

        if readOnlyProbes.contains(operation) {
            if policy == .readOnlyProbes && !userApproved {
                return .blocked(reason: .requiresUserApproval)
            }
            return .allowed
        }

        // 5. Destructive/interactive operations.
        switch operation {
        case .hermesRestart, .hermesChat, .tunnelStart, .tunnelStop:
            // In DEBUG, require .developerFull + developer toggle.
            #if DEBUG
            if policy == .developerFull && isDeveloperRemoteEnabled {
                return .allowed
            }
            return .blocked(reason: .debugOnly)
            #else
            // Release: always blocked by compile-time gate.
            return .blocked(reason: .releaseBuildBlocked)
            #endif

        default:
            // Should never reach here — all cases handled above.
            return .blocked(reason: .forbidden)
        }
    }
}
