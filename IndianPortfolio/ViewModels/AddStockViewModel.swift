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

    /// Popular Indian stocks shown when no search query is entered.
    /// Gives the user (and reviewers) an immediate way to add a stock.
    static let popularStocks: [SymbolSearchResult] = [
        SymbolSearchResult(symbol: "RELIANCE.NS", name: "Reliance Industries Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "TCS.NS", name: "Tata Consultancy Services", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "HDFCBANK.NS", name: "HDFC Bank Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "INFY.NS", name: "Infosys Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "ICICIBANK.NS", name: "ICICI Bank Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "BHARTIARTL.NS", name: "Bharti Airtel Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "ITC.NS", name: "ITC Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "SBIN.NS", name: "State Bank of India", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "LT.NS", name: "Larsen & Toubro Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "HINDUNILVR.NS", name: "Hindustan Unilever Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "ASIANPAINT.NS", name: "Asian Paints Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "MARUTI.NS", name: "Maruti Suzuki India Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "BAJFINANCE.NS", name: "Bajaj Finance Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "WIPRO.NS", name: "Wipro Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "TATAMOTORS.NS", name: "Tata Motors Limited", exchange: "NSE", type: "EQUITY"),
        SymbolSearchResult(symbol: "ADANIENT.NS", name: "Adani Enterprises Limited", exchange: "NSE", type: "EQUITY")
    ]

    /// Results to display: live search results when there's a query,
    /// otherwise the curated popular-stocks list so the screen is never empty.
    var displayResults: [SymbolSearchResult] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2 {
            return searchResults
        }
        return Self.popularStocks
    }

    var isValid: Bool {
        selectedResult != nil && (Int(quantity) ?? 0) > 0
    }

    var quantityInt: Int {
        Int(quantity) ?? 0
    }

    /// True when the user typed a query but no Indian stocks matched.
    var showsNoResultsState: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && !isSearching && searchResults.isEmpty
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
