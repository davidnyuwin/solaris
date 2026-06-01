import Foundation
import Combine

@MainActor
public class HermesViewModel: ObservableObject {
    private let service: any HermesService
    
    @Published public var status: HermesStatus?
    @Published public var runs: [HermesRun] = []
    @Published public var providers: [ProviderHealth] = []
    @Published public var logs: [LogLine] = []
    
    @Published public var currentInput: String = ""
    @Published public var isPendingResponse: Bool = false
    @Published public var errorMessage: String? = nil
    
    @Published public var apiEndpoint: String = "http://127.0.0.1:5080"
    
    public init(service: any HermesService) {
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
