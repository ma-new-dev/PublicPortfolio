import Foundation

@MainActor
@Observable
final class StockDetailViewModel {
    var selectedRange: ChartTimeRange = .oneDay
    var priceData: [IntradayDataPoint] = []
    var volumeData: [VolumeDataPoint] = []
    var marketCap: Double? = nil
    var isLoading = false
    var errorMessage: String?

    private let priceService = StockPriceService()

    var priceChange: Double {
        guard let first = priceData.first?.price,
              let last = priceData.last?.price else { return 0 }
        return last - first
    }

    var priceChangePercent: Double {
        guard let first = priceData.first?.price, first > 0,
              let last = priceData.last?.price else { return 0 }
        return ((last - first) / first) * 100
    }

    var isPositive: Bool { priceChange >= 0 }

    var highPrice: Double {
        priceData.map(\.price).max() ?? 0
    }

    var lowPrice: Double {
        priceData.map(\.price).min() ?? 0
    }

    var totalVolume: Double {
        volumeData.reduce(0) { $0 + $1.volume }
    }

    func fetchData(for ticker: String) async {
        isLoading = true
        errorMessage = nil

        // Fetch chart data
        do {
            let result = try await priceService.fetchChartData(for: ticker, range: selectedRange)
            priceData = result.pricePoints
            volumeData = result.volumePoints
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fetch quote to get market cap (separate call so chart failure doesn't block it)
        if let quote = try? await priceService.fetchQuote(for: ticker) {
            marketCap = quote.marketCap
        }

        isLoading = false
    }

    func changeRange(to range: ChartTimeRange, ticker: String) {
        selectedRange = range
        Task {
            await fetchData(for: ticker)
        }
    }
}
