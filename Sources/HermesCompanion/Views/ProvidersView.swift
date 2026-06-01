import SwiftUI

public struct ProvidersView: View {
    @ObservedObject var viewModel: HermesViewModel
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
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
                            if viewModel.logs.isEmpty {
                                Text("No logs available")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(viewModel.logs) { log in
                                    LogCard(log: log)
                                    if log.id != viewModel.logs.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.06))
                                    }
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
