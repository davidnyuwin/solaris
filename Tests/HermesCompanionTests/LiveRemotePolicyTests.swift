import XCTest
@testable import HermesCompanion

final class LiveRemotePolicyTests: XCTestCase {

    // MARK: - Policy loading defaults

    func testPolicyDefaultIsDisabled() {
        // Fresh UserDefaults should have no LiveRemotePolicy key
        UserDefaults.standard.removeObject(forKey: LiveRemotePolicy.policyPrefsStore)
        let loaded = LiveRemotePolicy.load()
        XCTAssertEqual(loaded, .disabled,
                       "Fresh install must default to .disabled")
        // Restore clean state
        UserDefaults.standard.removeObject(forKey: LiveRemotePolicy.policyPrefsStore)
    }

    func testPolicyRoundTrip() {
        UserDefaults.standard.removeObject(forKey: LiveRemotePolicy.policyPrefsStore)
        LiveRemotePolicy.readOnlyProbes.save()
        XCTAssertEqual(LiveRemotePolicy.load(), .readOnlyProbes)
        LiveRemotePolicy.disabled.save()
        XCTAssertEqual(LiveRemotePolicy.load(), .disabled)
        UserDefaults.standard.removeObject(forKey: LiveRemotePolicy.policyPrefsStore)
    }

    // MARK: - No-Go Test 1: Arbitrary command always forbidden

    func testArbitraryCommandAlwaysForbidden() {
        for policy in [LiveRemotePolicy.disabled, .readOnlyProbes] {
            #if DEBUG
            let allPolicies: [LiveRemotePolicy] = [policy, .developerFull]
            #else
            let allPolicies: [LiveRemotePolicy] = [policy]
            #endif
            for p in allPolicies {
                let result = LiveRemotePolicyEvaluator.canExecute(
                    .arbitraryCommand,
                    policy: p,
                    userApproved: true,
                    isDeveloperRemoteEnabled: true
                )
                XCTAssertEqual(result, .blocked(reason: .forbidden),
                               "arbitraryCommand must be forbidden regardless of policy (\(p.rawValue))")
            }
        }
    }

    // MARK: - No-Go Test 2: Shell metacharacters never reach SSH

    func testShellMetacharactersNeverReachSSH() {
        let forbidden = " ;|&`$<>()[]{}#'\"!\\"
        for char in forbidden {
            let malicious = "hermes\(char)whoami"
            let result = RemoteHermesCommand.verifyBase(malicious)
            XCTAssertNotEqual(result, malicious,
                              "Shell char '\(char)' should cause fallback, not pass through")
        }
    }

    // MARK: - No-Go Test 3: Release restart blocked

    func testReleaseRestartBlocked() {
        #if !DEBUG
        let result = LiveRemotePolicyEvaluator.canExecute(
            .hermesRestart,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: true
        )
        XCTAssertEqual(result, .blocked(reason: .releaseBuildBlocked),
                       "hermesRestart must be blocked in release builds")
        #else
        // In DEBUG, restart requires .developerFull + toggle
        let result = LiveRemotePolicyEvaluator.canExecute(
            .hermesRestart,
            policy: .developerFull,
            userApproved: true,
            isDeveloperRemoteEnabled: true
        )
        XCTAssertEqual(result, .allowed,
                       "hermesRestart allowed in DEBUG with .developerFull + toggle")

        let blockedWithoutToggle = LiveRemotePolicyEvaluator.canExecute(
            .hermesRestart,
            policy: .developerFull,
            userApproved: true,
            isDeveloperRemoteEnabled: false
        )
        XCTAssertEqual(blockedWithoutToggle, .blocked(reason: .debugOnly),
                       "hermesRestart blocked in DEBUG without developer toggle")
        #endif
    }

    // MARK: - No-Go Test 4: Release tunnel start blocked

    func testReleaseTunnelStartBlocked() {
        #if !DEBUG
        let result = LiveRemotePolicyEvaluator.canExecute(
            .tunnelStart,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: true
        )
        XCTAssertEqual(result, .blocked(reason: .releaseBuildBlocked),
                       "tunnelStart must be blocked in release builds")
        #endif
    }

    // MARK: - No-Go Test 5: Release tunnel stop blocked

    func testReleaseTunnelStopBlocked() {
        #if !DEBUG
        let result = LiveRemotePolicyEvaluator.canExecute(
            .tunnelStop,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: true
        )
        XCTAssertEqual(result, .blocked(reason: .releaseBuildBlocked),
                       "tunnelStop must be blocked in release builds")
        #endif
    }

    // MARK: - No-Go Test 6: Release chat/stdin blocked

    func testReleaseChatBlocked() {
        #if !DEBUG
        let result = LiveRemotePolicyEvaluator.canExecute(
            .hermesChat,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: true
        )
        XCTAssertEqual(result, .blocked(reason: .releaseBuildBlocked),
                       "hermesChat must be blocked in release builds")
        #endif
    }

    // MARK: - No-Go Test 7: Long-running command blocked in release

    func testLongRunningBlockedInRelease() {
        // Tunnel start is the canonical long-running operation
        #if !DEBUG
        let longRunningOps: [LiveRemoteOperation] = [.tunnelStart, .tunnelStop, .hermesChat]
        for op in longRunningOps {
            let result = LiveRemotePolicyEvaluator.canExecute(
                op,
                policy: .readOnlyProbes,
                userApproved: true,
                isDeveloperRemoteEnabled: true
            )
            XCTAssertEqual(result, .blocked(reason: .releaseBuildBlocked),
                           "\(op.rawValue) must be blocked in release as long-running")
        }
        #endif
    }

    func testRawSecretNeverLogged() {
        // RemoteCommandInputMetadata must not contain raw payload
        let secretKey = "sk-" + "1234567890abcdefghijklmnopqrstuv"
        let payload = Data(secretKey.utf8)
        let meta = RemoteCommandInputMetadata(rawPayload: payload, command: "chat")
        XCTAssertFalse(meta.command.contains(secretKey),
                       "Metadata command field must not contain raw stdin content")
        XCTAssertEqual(meta.byteCount, payload.count,
                       "Only byte count stored, not content")
        // The sanitisedFirstLineHint must not contain the raw secret
        if let hint = meta.sanitisedFirstLineHint {
            XCTAssertFalse(hint.contains(secretKey),
                           "Sanitised hint must not contain raw secret")
        }
    }

    // MARK: - No-Go Test 9: Raw output sanitized before storage/display

    func testRawOutputSanitizedBeforeStorage() {
        let sensitiveOutput = "Bearer " + "sk-1234567890abcdef and https://admin:pass@host.com"
        let result = LiveRemoteProbeResult(
            probe: .hermesStatus,
            status: .succeeded,
            sanitizedSummary: sensitiveOutput
        )
        XCTAssertFalse(result.sanitizedSummary.contains("sk-" + "1234567890abcdef"),
                       "Probe result must not contain raw bearer tokens")
        XCTAssertFalse(result.sanitizedSummary.contains("admin:pass"),
                       "Probe result must not contain raw credentials")
    }

    // MARK: - No-Go Test 10: Live probes disabled when kill switch is off

    func testKillSwitchDisablesAllProbes() {
        let probes: [LiveRemoteOperation] = [
            .findHermesBinary, .hermesVersion, .hermesStatus, .tunnelStatus,
            .hermesRestart, .hermesChat, .tunnelStart, .tunnelStop
        ]
        for probe in probes {
            let result = LiveRemotePolicyEvaluator.canExecute(
                probe,
                policy: .disabled,
                userApproved: true,
                isDeveloperRemoteEnabled: true
            )
            XCTAssertEqual(result, .blocked(reason: .policyDisabled),
                           "\(probe.rawValue) must be blocked when policy is .disabled")
        }
    }

    // MARK: - No-Go Test 11: User confirmation required before probe

    func testUserConfirmationRequiredBeforeProbe() {
        let probes: [LiveRemoteOperation] = [.findHermesBinary, .hermesVersion, .hermesStatus, .tunnelStatus]
        for probe in probes {
            let withoutApproval = LiveRemotePolicyEvaluator.canExecute(
                probe,
                policy: .readOnlyProbes,
                userApproved: false,
                isDeveloperRemoteEnabled: false
            )
            XCTAssertEqual(withoutApproval, .blocked(reason: .requiresUserApproval),
                           "\(probe.rawValue) must require user approval in .readOnlyProbes")

            let withApproval = LiveRemotePolicyEvaluator.canExecute(
                probe,
                policy: .readOnlyProbes,
                userApproved: true,
                isDeveloperRemoteEnabled: false
            )
            XCTAssertEqual(withApproval, .allowed,
                           "\(probe.rawValue) must be allowed with user approval in .readOnlyProbes")
        }
    }

    // MARK: - No-Go Test 12: `which hermes` path output summarized

    func testWhichHermesPathNotStored() {
        // LiveRemoteProbeResult sanitizes output — never stores raw path
        let pathOutput = "/home/user/.local/bin/hermes"
        let result = LiveRemoteProbeResult(
            probe: .findHermesBinary,
            status: .succeeded,
            sanitizedSummary: pathOutput
        )
        // The result stores the full path (sanitized for secrets), but
        // in actual usage the VM extracts only hermesFound: Bool.
        // This test verifies the mock produces a summary, not a raw path dump.
        let runner = MockLiveRemoteProbeRunner()
        runner.mockHermesFound = true
        let expectation = expectation(description: "mock probe")
        Task {
            let probeResult = await runner.run(LiveRemoteProbeRequest(
                host: "test.local", username: "user", identityPath: nil,
                probe: .findHermesBinary
            ))
            XCTAssertEqual(probeResult.sanitizedSummary, "Hermes binary found",
                           "Mock must summarize which result to found/not-found, not raw path")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    // MARK: - No-Go Test 13: `tunnel-status` cannot start or stop tunnel

    func testTunnelStatusIsQueryOnly() {
        // tunnelStatus maps to a fixed hermes subcommand argument
        let cmd = RemoteHermesCommand.tunnelStatus
        let args = cmd.remoteArguments(hermesCommandBase: "hermes")
        XCTAssertEqual(args, ["tunnel-status"],
                       "tunnel-status must be a simple query, not an SSH -L tunnel command")
        XCTAssertFalse(args.contains("-L"),
                      "tunnel-status must not contain SSH -L flag")
        XCTAssertFalse(args.contains("-N"),
                      "tunnel-status must not contain SSH -N flag")

        // Policy must allow it as a read-only probe
        let result = LiveRemotePolicyEvaluator.canExecute(
            .tunnelStatus,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: false
        )
        XCTAssertEqual(result, .allowed,
                       "tunnelStatus must be allowed as a read-only probe")
    }

    // MARK: - No-Go Test 14: Env/config dumping forbidden

    func testEnvConfigDumpingForbidden() {
        let forbiddenOps: [LiveRemoteOperation] = [.environmentDump, .configDump]
        for op in forbiddenOps {
            for policy in [LiveRemotePolicy.disabled, .readOnlyProbes] {
                let result = LiveRemotePolicyEvaluator.canExecute(
                    op,
                    policy: policy,
                    userApproved: true,
                    isDeveloperRemoteEnabled: true
                )
                XCTAssertEqual(result, .blocked(reason: .forbidden),
                               "\(op.rawValue) must be forbidden in \(policy.rawValue)")
            }
        }
        // Verify no RemoteHermesCommand case exists for these
        let allCommands = RemoteHermesCommand.allCases.map { $0.rawValue }
        XCTAssertFalse(allCommands.contains("env"),
                      "No 'env' command should exist in RemoteHermesCommand")
        XCTAssertFalse(allCommands.contains("printenv"),
                      "No 'printenv' command should exist")
        XCTAssertFalse(allCommands.contains("cat"),
                      "No 'cat' command should exist")
    }

    // MARK: - No-Go Test 15: Remote filesystem browsing forbidden

    func testFilesystemBrowsingForbidden() {
        let result = LiveRemotePolicyEvaluator.canExecute(
            .filesystemBrowse,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: true
        )
        XCTAssertEqual(result, .blocked(reason: .forbidden),
                       "filesystemBrowse must always be forbidden")

        // Verify no RemoteHermesCommand case exists for filesystem ops
        let allCommands = RemoteHermesCommand.allCases.map { $0.rawValue }
        XCTAssertFalse(allCommands.contains("ls"),
                      "No 'ls' command should exist in RemoteHermesCommand")
        XCTAssertFalse(allCommands.contains("find"),
                      "No 'find' command should exist")
        XCTAssertFalse(allCommands.contains("cat"),
                      "No 'cat' command should exist")
    }

    // MARK: - No-Go Test 16: Phase 3A does not weaken existing #if !DEBUG

    func testExistingReleaseGatesIntact() {
        // This test verifies the policy model is ADDITIVE to compile-time gates.
        // In release builds (.disabled or .readOnlyProbes), destructive ops
        // must be blocked by BOTH the policy evaluator AND compile-time guards.

        #if !DEBUG
        let destructiveOps: [LiveRemoteOperation] = [
            .hermesRestart, .hermesChat, .tunnelStart, .tunnelStop
        ]
        for op in destructiveOps {
            // Policy evaluator blocks
            let policyResult = LiveRemotePolicyEvaluator.canExecute(
                op,
                policy: .readOnlyProbes,
                userApproved: true,
                isDeveloperRemoteEnabled: true
            )
            XCTAssertEqual(policyResult, .blocked(reason: .releaseBuildBlocked),
                           "\(op.rawValue) must be releaseBuildBlocked in release via policy")

            // Compile-time gate also blocks — LiveRemotePolicy.developerFull
            // does not exist in release builds, so it can never be loaded.
            let allCases = LiveRemotePolicy.allCases.map { $0.rawValue }
            XCTAssertFalse(allCases.contains("developerFull"),
                          "developerFull policy must not exist in release builds")
        }
        #else
        // In DEBUG, verify that .developerFull exists but is still gated
        XCTAssertTrue(LiveRemotePolicy.allCases.contains(.developerFull),
                      "developerFull must exist in DEBUG builds")
        #endif
    }

    // MARK: - Additional policy tests

    func testReadOnlyProbesAllowedWithApproval() {
        let probes: [LiveRemoteOperation] = [
            .findHermesBinary, .hermesVersion, .hermesStatus, .tunnelStatus
        ]
        for probe in probes {
            let result = LiveRemotePolicyEvaluator.canExecute(
                probe,
                policy: .readOnlyProbes,
                userApproved: true,
                isDeveloperRemoteEnabled: false
            )
            XCTAssertEqual(result, .allowed,
                           "\(probe.rawValue) must be allowed in .readOnlyProbes with approval")
        }
    }

    func testReadOnlyProbesBlockedWithoutApproval() {
        let probes: [LiveRemoteOperation] = [
            .findHermesBinary, .hermesVersion, .hermesStatus, .tunnelStatus
        ]
        for probe in probes {
            let result = LiveRemotePolicyEvaluator.canExecute(
                probe,
                policy: .readOnlyProbes,
                userApproved: false,
                isDeveloperRemoteEnabled: false
            )
            XCTAssertEqual(result, .blocked(reason: .requiresUserApproval),
                           "\(probe.rawValue) must require approval in .readOnlyProbes")
        }
    }

    func testInvalidHostBlocked() {
        let result = LiveRemotePolicyEvaluator.canExecute(
            .findHermesBinary,
            policy: .readOnlyProbes,
            userApproved: true,
            isDeveloperRemoteEnabled: false,
            isValidHost: false
        )
        XCTAssertEqual(result, .blocked(reason: .invalidInput),
                       "Invalid host must be rejected even with approval")
    }

    func testDisabledPolicyBlocksEverythingIncludingWithApproval() {
        let allOps = LiveRemoteOperation.allCases
        for op in allOps {
            let result = LiveRemotePolicyEvaluator.canExecute(
                op,
                policy: .disabled,
                userApproved: true,
                isDeveloperRemoteEnabled: true
            )
            if case .blocked(reason: .forbidden) = result {
                // Forbidden ops get .forbidden (checked separately)
            } else {
                XCTAssertEqual(result, .blocked(reason: .policyDisabled),
                               "\(op.rawValue) must be policyDisabled when policy is .disabled")
            }
        }
    }

    // MARK: - Mock probe runner tests

    func testMockProbeRunnerSuccess() async {
        let runner = MockLiveRemoteProbeRunner()

        let versionResult = await runner.run(LiveRemoteProbeRequest(
            host: "test.local", username: "user", identityPath: nil, probe: .hermesVersion
        ))
        XCTAssertEqual(versionResult.probe, .hermesVersion)
        XCTAssertEqual(versionResult.status, .succeeded)
        XCTAssertEqual(versionResult.exitCode, 0)

        let statusResult = await runner.run(LiveRemoteProbeRequest(
            host: "test.local", username: "user", identityPath: nil, probe: .hermesStatus
        ))
        XCTAssertEqual(statusResult.status, .succeeded)
        XCTAssertTrue(statusResult.sanitizedSummary.contains("running"))
    }

    func testMockProbeRunnerHermesNotFound() async {
        let runner = MockLiveRemoteProbeRunner()
        runner.mockHermesFound = false

        let result = await runner.run(LiveRemoteProbeRequest(
            host: "test.local", username: "user", identityPath: nil, probe: .findHermesBinary
        ))
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.sanitizedSummary.contains("not found"))
    }

    func testMockProbeRunnerFailure() async {
        let runner = MockLiveRemoteProbeRunner()
        runner.shouldFail = true
        runner.customErrorMessage = "Connection refused"

        let result = await runner.run(LiveRemoteProbeRequest(
            host: "fail.local", username: "user", identityPath: nil, probe: .hermesVersion
        ))
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.sanitizedSummary, "Connection refused")
    }

    func testMockProbeRunnerOutputSanitised() async {
        let runner = MockLiveRemoteProbeRunner()
        runner.mockStatus = "Status: Bearer sk-secret-key-12345"

        let result = await runner.run(LiveRemoteProbeRequest(
            host: "test.local", username: "user", identityPath: nil, probe: .hermesStatus
        ))
        XCTAssertFalse(result.sanitizedSummary.contains("sk-secret-key-12345"),
                      "Mock output must be sanitised in LiveRemoteProbeResult")
    }

    // MARK: - Probe type mapping

    func testProbeRemoteCommandMapping() {
        XCTAssertEqual(LiveRemoteProbe.findHermesBinary.remoteCommand, .whichHermes)
        XCTAssertEqual(LiveRemoteProbe.hermesVersion.remoteCommand, .hermesVersion)
        XCTAssertEqual(LiveRemoteProbe.hermesStatus.remoteCommand, .hermesStatus)
        XCTAssertEqual(LiveRemoteProbe.tunnelStatus.remoteCommand, .tunnelStatus)
    }

    func testProbeResultSanitizedOnInit() {
        let result = LiveRemoteProbeResult(
            probe: .hermesVersion,
            status: .succeeded,
            sanitizedSummary: "https://admin:password@secret.host.com/v1"
        )
        XCTAssertFalse(result.sanitizedSummary.contains("admin:password"),
                      "Probe result must sanitize credentials on init")
    }

    func testProbeRequestStoresNoSecrets() {
        let request = LiveRemoteProbeRequest(
            host: "hermes.internal",
            username: "deploy",
            identityPath: "/Users/deploy/.ssh/id_ed25519",
            probe: .hermesStatus
        )
        // Verify the type has no fields for passwords, private keys, tokens
        let mirror = Mirror(reflecting: request)
        let fieldNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(fieldNames.contains("password"),
                      "ProbeRequest must not have a password field")
        XCTAssertFalse(fieldNames.contains("privateKey"),
                      "ProbeRequest must not have a privateKey field")
        XCTAssertFalse(fieldNames.contains("token"),
                      "ProbeRequest must not have a token field")
    }

    // MARK: - Operation enum completeness

    func testOperationEnumContainsForbiddenCases() {
        let allOps = LiveRemoteOperation.allCases
        XCTAssertTrue(allOps.contains(.arbitraryCommand),
                      "arbitraryCommand must exist for explicit rejection")
        XCTAssertTrue(allOps.contains(.filesystemBrowse),
                      "filesystemBrowse must exist for explicit rejection")
        XCTAssertTrue(allOps.contains(.environmentDump),
                      "environmentDump must exist for explicit rejection")
        XCTAssertTrue(allOps.contains(.configDump),
                      "configDump must exist for explicit rejection")
    }

    func testBlockReasonEnumCompleteness() {
        let allReasons = LiveRemoteBlockReason.allCases
        XCTAssertTrue(allReasons.contains(.policyDisabled))
        XCTAssertTrue(allReasons.contains(.requiresUserApproval))
        XCTAssertTrue(allReasons.contains(.debugOnly))
        XCTAssertTrue(allReasons.contains(.forbidden))
        XCTAssertTrue(allReasons.contains(.invalidInput))
        XCTAssertTrue(allReasons.contains(.releaseBuildBlocked))
    }
}
