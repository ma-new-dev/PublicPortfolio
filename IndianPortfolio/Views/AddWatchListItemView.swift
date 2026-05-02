import SwiftUI
import SwiftData

struct AddWatchListItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddStockViewModel()

    // Tickers already on the watchlist, to prevent duplicates
    let existingTickers: Set<String>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search company or ticker...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.searchText) { _, _ in
                            viewModel.search()
                        }
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            viewModel.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if viewModel.showsNoResultsState {
                    Spacer()
                    ContentUnavailableView(
                        "No Indian Stocks Found",
                        systemImage: "magnifyingglass",
                        description: Text("No NSE/BSE matches for \"\(viewModel.searchText)\".\nTry: Reliance, TCS, Infosys, HDFC, ITC")
                    )
                    Spacer()
                } else {
                    List {
                        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                            Section {
                                EmptyView()
                            } header: {
                                Text("Popular Indian Stocks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(viewModel.displayResults) { result in
                            Button {
                                addToWatchList(result)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        HStack {
                                            Text(result.symbol)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(result.exchange)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.blue)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    if existingTickers.contains(result.symbol) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 8)
                                    }
                                }
                            }
                            .disabled(existingTickers.contains(result.symbol))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to Watch List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addToWatchList(_ result: SymbolSearchResult) {
        guard !existingTickers.contains(result.symbol) else { return }
        let item = WatchListItem(
            ticker: result.symbol,
            companyName: result.name,
            exchange: result.exchange
        )
        modelContext.insert(item)
        dismiss()
    }
}
