import Foundation

@MainActor
@Observable
final class StockDetailViewModel {
    var selectedRange: ChartTimeRange = .oneDay
    var priceData: [IntradayDataPoint] = []
    var volumeData: [VolumeDataPoint] = []
    /// Close immediately before the selected range — baseline for the range change.
    var rangeBaseline: Double?
    /// Fresh quote fetched by the detail screen itself (so it never shows a stale snapshot).
    var liveQuote: StockQuote?
    var marketCap: Double? = nil
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private let priceService = StockPriceService()
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Baseline: previous close before the range (matches the "day change" shown
    /// elsewhere for 1D). Falls back to the first point.
    private var baseline: Double? {
        // For 1D use the official previous close from the quote, so the chart
        // change matches the day change shown on the header and list rows.
        if selectedRange == .oneDay, let pc = liveQuote?.previousClose, pc > 0 { return pc }
        if let b = rangeBaseline, b > 0 { return b }
        return priceData.first?.price
    }

    private var lastPrice: Double? {
        if selectedRange == .oneDay, let live = liveQuote?.currentPrice { return live }
        return priceData.last?.price
    }

    var priceChange: Double {
        guard let first = baseline, let last = lastPrice else { return 0 }
        return last - first
    }

    var priceChangePercent: Double {
        guard let first = baseline, first > 0, let last = lastPrice else { return 0 }
        return ((last - first) / first) * 100
    }

    var isPositive: Bool { priceChange >= 0 }

    var highPrice: Double { priceData.map(\.price).max() ?? 0 }
    var lowPrice: Double { priceData.map(\.price).min() ?? 0 }
    var totalVolume: Double { volumeData.reduce(0) { $0 + $1.volume } }
    var hasVolume: Bool { totalVolume > 0 }

    func fetchData(for ticker: String, includeMarketCap: Bool = true) async {
        isLoading = true
        errorMessage = nil
        let range = selectedRange

        async let chartResult = priceService.fetchChartData(for: ticker, range: range)
        async let quoteResult = priceService.fetchQuoteIfAvailable(for: ticker)

        do {
            let result = try await chartResult
            // Ignore results for a range the user has already switched away from.
            guard range == selectedRange else { return }
            priceData = result.pricePoints
            volumeData = result.volumePoints
            rangeBaseline = result.previousClose
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }

        if let quote = await quoteResult {
            liveQuote = quote
        }

        if includeMarketCap, marketCap == nil {
            if let cap = liveQuote?.marketCap, cap > 0 {
                marketCap = cap
            } else {
                marketCap = await priceService.fetchMarketCap(for: ticker, price: liveQuote?.currentPrice)
            }
        }

        if range == selectedRange { isLoading = false }
    }

    func changeRange(to range: ChartTimeRange, ticker: String, includeMarketCap: Bool = true) {
        guard range != selectedRange else { return }
        selectedRange = range
        loadTask?.cancel()
        loadTask = Task {
            await fetchData(for: ticker, includeMarketCap: includeMarketCap)
        }
    }
}
