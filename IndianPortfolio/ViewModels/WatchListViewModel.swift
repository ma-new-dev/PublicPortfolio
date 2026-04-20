import Foundation

@MainActor
@Observable
final class WatchListViewModel {
    var quotes: [String: StockQuote] = [:]
    var exchangeRate: Double = 0.0
    var isLoading = false

    private let priceService = StockPriceService()
    private let exchangeService = ExchangeRateService()
    private var refreshTimer: Timer?

    func refreshAll(items: [WatchListItem]) async {
        isLoading = true
        let tickers = items.map(\.ticker)

        async let fetchedQuotes = tickers.isEmpty ? [:] : priceService.fetchQuotes(for: tickers)
        async let fetchedRate = exchangeService.fetchINRToUSD()

        let newQuotes = await fetchedQuotes
        if !newQuotes.isEmpty || tickers.isEmpty {
            quotes = newQuotes
        }

        do {
            exchangeRate = try await fetchedRate
        } catch {
            // keep previous rate if available
        }

        isLoading = false
    }

    func startAutoRefresh(items: [WatchListItem]) {
        stopAutoRefresh()
        let interval = MarketStatusService.nextRefreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll(items: items)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
