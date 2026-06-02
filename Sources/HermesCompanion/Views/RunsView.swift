import SwiftUI

public struct RunsView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var query: String = ""
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
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
}
