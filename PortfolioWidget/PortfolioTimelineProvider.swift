import WidgetKit
import Foundation

// MARK: - Timeline Entry

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let totalValueINR: Double
    let totalValueUSD: Double
    let exchangeRate: Double
    let isMarketOpen: Bool
    let holdings: [WidgetHolding]
    let indices: [WidgetIndex]
    let isPlaceholder: Bool

    static var placeholder: PortfolioEntry {
        PortfolioEntry(
            date: Date(),
            totalValueINR: 125_000_000,
            totalValueUSD: 1_488_095,
            exchangeRate: 0.0119,
            isMarketOpen: true,
            holdings: [
                WidgetHolding(id: "RELIANCE.NS", companyName: "Reliance Industries", currentPrice: 2450.50, changePercent: 1.25, valueUSD: 580_000, isPositive: true),
                WidgetHolding(id: "TCS.NS", companyName: "Tata Consultancy", currentPrice: 3820.00, changePercent: -0.45, valueUSD: 450_000, isPositive: false),
                WidgetHolding(id: "HDFCBANK.NS", companyName: "HDFC Bank", currentPrice: 1650.75, changePercent: 0.80, valueUSD: 320_000, isPositive: true),
            ],
            indices: [
                WidgetIndex(id: "^BSESN", name: "SENSEX", value: 79850, changePercent: 0.65, isPositive: true),
                WidgetIndex(id: "^NSEI", name: "NIFTY 50", value: 24150, changePercent: 0.52, isPositive: true),
            ],
            isPlaceholder: true
        )
    }
}

struct WidgetHolding: Identifiable {
    let id: String
    let companyName: String
    let currentPrice: Double
    let changePercent: Double
    let valueUSD: Double
    let isPositive: Bool
}

struct WidgetIndex: Identifiable {
    let id: String
    let name: String
    let value: Double
    let changePercent: Double
    let isPositive: Bool
}

// MARK: - Timeline Provider

struct PortfolioTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortfolioEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let isMarketOpen = WidgetMarketStatus.isMarketOpen
            let refreshInterval: TimeInterval = isMarketOpen ? 60 : 900
            let nextUpdate = Date().addingTimeInterval(refreshInterval)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> PortfolioEntry {
        // Load holdings from shared UserDefaults
        let sharedData = PortfolioDataStore.load()
        let sharedHoldings = sharedData?.holdings ?? []
        let isMarketOpen = WidgetMarketStatus.isMarketOpen

        guard !sharedHoldings.isEmpty else {
            // No holdings — still fetch indices
            let indices = await WidgetDataService.fetchIndices()
            let rate = await WidgetDataService.fetchExchangeRate()
            return PortfolioEntry(
                date: Date(),
                totalValueINR: 0,
                totalValueUSD: 0,
                exchangeRate: rate,
                isMarketOpen: isMarketOpen,
                holdings: [],
                indices: indices,
                isPlaceholder: false
            )
        }

        // Fetch all data concurrently
        let tickers = sharedHoldings.map(\.ticker)
        async let quotesResult = WidgetDataService.fetchQuotes(for: tickers)
        async let rateResult = WidgetDataService.fetchExchangeRate()
        async let indicesResult = WidgetDataService.fetchIndices()

        let quotes = await quotesResult
        let rate = await rateResult
        let indices = await indicesResult

        // Build widget holdings sorted by USD value descending
        var widgetHoldings: [WidgetHolding] = []
        var totalINR: Double = 0

        for sh in sharedHoldings {
            if let q = quotes[sh.ticker] {
                let valueINR = q.currentPrice * Double(sh.quantity)
                let valueUSD = rate > 0 ? valueINR * rate : 0
                totalINR += valueINR
                widgetHoldings.append(WidgetHolding(
                    id: sh.ticker,
                    companyName: sh.companyName,
                    currentPrice: q.currentPrice,
                    changePercent: q.changePercent,
                    valueUSD: valueUSD,
                    isPositive: q.isPositive
                ))
            }
        }

        widgetHoldings.sort { $0.valueUSD > $1.valueUSD }
        let totalUSD = rate > 0 ? totalINR * rate : 0

        return PortfolioEntry(
            date: Date(),
            totalValueINR: totalINR,
            totalValueUSD: totalUSD,
            exchangeRate: rate,
            isMarketOpen: isMarketOpen,
            holdings: widgetHoldings,
            indices: indices,
            isPlaceholder: false
        )
    }
}

// MARK: - Market Status (lightweight, no UIKit)

enum WidgetMarketStatus {
    static var isMarketOpen: Bool {
        let tz = TimeZone(identifier: "Asia/Kolkata")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        guard weekday >= 2 && weekday <= 6 else { return false }
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeInMinutes = hour * 60 + minute
        return timeInMinutes >= 555 && timeInMinutes <= 930 // 9:15 AM - 3:30 PM
    }
}
