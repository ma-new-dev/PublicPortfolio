import Foundation

@MainActor
@Observable
final class AddStockViewModel {
    var searchText = ""
    var searchResults: [SymbolSearchResult] = []
    var isSearching = false
    var selectedResult: SymbolSearchResult?
    var quantity: String = ""
    var errorMessage: String?

    private let priceService = StockPriceService()
    private var searchTask: Task<Void, Never>?

    var isValid: Bool {
        selectedResult != nil && (Int(quantity) ?? 0) > 0
    }

    var quantityInt: Int {
        Int(quantity) ?? 0
    }

    func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if Task.isCancelled { return }

                let results = try await priceService.searchSymbols(query: query)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    searchResults = []
                }
            }
        }
    }

    func reset() {
        searchText = ""
        searchResults = []
        selectedResult = nil
        quantity = ""
        errorMessage = nil
        searchTask?.cancel()
    }
}
