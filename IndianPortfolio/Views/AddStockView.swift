import SwiftUI
import SwiftData

struct AddStockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddStockViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.selectedResult == nil {
                    searchSection
                } else {
                    quantitySection
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.selectedResult != nil {
                        Button("Add") { addStock() }
                            .disabled(!viewModel.isValid)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Search section

    private var searchSection: some View {
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
            } else if viewModel.searchResults.isEmpty && viewModel.searchText.count >= 2 {
                Spacer()
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No Indian stocks found for \"\(viewModel.searchText)\"")
                )
                Spacer()
            } else {
                List(viewModel.searchResults) { result in
                    Button {
                        viewModel.selectedResult = result
                    } label: {
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
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Quantity section

    private var quantitySection: some View {
        VStack(spacing: 24) {
            // Selected stock info
            if let selected = viewModel.selectedResult {
                VStack(spacing: 8) {
                    Text(selected.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Text(selected.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(selected.exchange)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Button("Change") {
                        viewModel.selectedResult = nil
                        viewModel.quantity = ""
                    }
                    .font(.caption)
                }
                .padding(.top, 32)
            }

            // Quantity input
            VStack(spacing: 8) {
                Text("Number of Shares")
                    .font(.headline)

                TextField("Enter quantity", text: $viewModel.quantity)
                    .keyboardType(.numberPad)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Action

    private func addStock() {
        guard let selected = viewModel.selectedResult, viewModel.quantityInt > 0 else { return }

        let holding = StockHolding(
            ticker: selected.symbol,
            companyName: selected.name,
            exchange: selected.exchange,
            quantity: viewModel.quantityInt
        )
        modelContext.insert(holding)
        dismiss()
    }
}
