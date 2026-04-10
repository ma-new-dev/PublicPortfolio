import Foundation

struct StockQuote: Identifiable {
    let id: String // ticker
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let marketCap: Double?
    let lastUpdated: Date

    var isPositive: Bool { change >= 0 }
}

struct IntradayDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let price: Double
}

struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let volume: Double
}

struct ChartDataResult {
    let pricePoints: [IntradayDataPoint]
    let volumePoints: [VolumeDataPoint]
}

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case oneDay = "1D"
    case oneMonth = "1M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case fiveYears = "5Y"

    var id: String { rawValue }

    var yahooRange: String {
        switch self {
        case .oneDay: return "1d"
        case .oneMonth: return "1mo"
        case .sixMonths: return "6mo"
        case .oneYear: return "1y"
        case .fiveYears: return "5y"
        }
    }

    var yahooInterval: String {
        switch self {
        case .oneDay: return "5m"
        case .oneMonth: return "1d"
        case .sixMonths: return "1d"
        case .oneYear: return "1wk"
        case .fiveYears: return "1mo"
        }
    }

    var xAxisFormat: Date.FormatStyle {
        switch self {
        case .oneDay:
            return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .oneMonth:
            return .dateTime.day().month(.abbreviated)
        case .sixMonths:
            return .dateTime.month(.abbreviated)
        case .oneYear:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        case .fiveYears:
            return .dateTime.year()
        }
    }
}

struct SymbolSearchResult: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let exchange: String
    let type: String
}
