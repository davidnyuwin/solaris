import SwiftUI

public struct RunsView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var query: String = ""
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left pane: Session list
            VStack(alignment: .leading, spacing: 0) {
                // Header with "New Chat"
                HStack {
                    Text("Chat History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.createNewSession()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("New Chat Session")
                }
                .padding()
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.sessions.isEmpty {
                            Text("No sessions")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.top, 40)
                        } else {
                            // Sort by updatedAt descending so newest is at top
                            ForEach(viewModel.sessions.sorted(by: { $0.updatedAt > $1.updatedAt })) { session in
                                SessionRow(
                                    session: session,
                                    isActive: viewModel.activeSessionID == session.id,
                                    onSelect: {
                                        viewModel.selectSession(id: session.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 240)
            .background(Color.black.opacity(0.15))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Right pane: the existing RunsView runs list
            VStack(alignment: .leading, spacing: 0) {
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.rose)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Button(action: {
                            viewModel.errorMessage = nil
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.rose.opacity(0.15))
                    .cornerRadius(8)
                    .padding([.horizontal, .top])
                }
                
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
                        
                        if filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No runs matched your query")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.top, 80)
                        } else {
                            ForEach(filtered) { run in
                                CommandResultCard(run: run)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color.clear)
        }
        .background(Color.clear)
    }
}

struct SessionRow: View {
    let session: HermesChatSession
    let isActive: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(.system(size: 13, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? .white : .white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Text("\(session.runs.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                
                if let lastRun = session.runs.last, let preview = lastRun.promptPreview {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Text(session.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Color.white.opacity(0.08) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.hermesPurple.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
