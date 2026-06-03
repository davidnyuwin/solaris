import Foundation

public protocol ChatHistoryStoring: Sendable {
    func load() async -> HermesChatHistoryDocument
    func save(_ document: HermesChatHistoryDocument) async throws
}

public final class ChatHistoryStore: ChatHistoryStoring, @unchecked Sendable {
    private let fileURL: URL
    private let directoryURL: URL
    private let queue = DispatchQueue(label: "com.solaris.chathistorystore", qos: .utility)
    
    // Injectable initializer for testing
    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.directoryURL = fileURL.deletingLastPathComponent()
    }
    
    // Default initializer using Application Support directory
    public init() {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTest") != nil
            
        let appSupportURL: URL
        if isTesting {
            appSupportURL = FileManager.default.temporaryDirectory
        } else {
            let appSupportURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            appSupportURL = appSupportURLs.first ?? FileManager.default.temporaryDirectory
        }
        let solarisDirectory = appSupportURL.appendingPathComponent("Solaris", isDirectory: true)
        self.directoryURL = solarisDirectory
        self.fileURL = solarisDirectory.appendingPathComponent("chat-history.json")
    }
    
    public func load() async -> HermesChatHistoryDocument {
        await withCheckedContinuation { continuation in
            queue.async {
                guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
                    continuation.resume(returning: HermesChatHistoryDocument(schemaVersion: 1, sessions: []))
                    return
                }
                
                do {
                    let data = try Data(contentsOf: self.fileURL)
                    let decoder = JSONDecoder()
                    let doc = try decoder.decode(HermesChatHistoryDocument.self, from: data)
                    continuation.resume(returning: doc)
                } catch {
                    // Corrupt JSON handling: rename the file to avoid data loss
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let corruptURL = self.directoryURL.appendingPathComponent("chat-history.corrupt.\(timestamp).json")
                    try? FileManager.default.moveItem(at: self.fileURL, to: corruptURL)
                    
                    continuation.resume(returning: HermesChatHistoryDocument(schemaVersion: 1, sessions: []))
                }
            }
        }
    }
    
    public func save(_ document: HermesChatHistoryDocument) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    // Ensure parent directory exists
                    try FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
                    
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(document)
                    
                    let tempURL = self.directoryURL.appendingPathComponent("chat-history.tmp")
                    try data.write(to: tempURL, options: .atomic)
                    
                    if FileManager.default.fileExists(atPath: self.fileURL.path) {
                        _ = try FileManager.default.replaceItemAt(self.fileURL, withItemAt: tempURL, backupItemName: nil, options: [])
                    } else {
                        try FileManager.default.moveItem(at: tempURL, to: self.fileURL)
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
