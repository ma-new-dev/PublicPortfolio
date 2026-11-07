import Foundation

enum CurrencyFormatter {

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.positivePrefix = "+"
        return f
    }()

    private static func makeGroupedFormatter(decimals: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")   // Indian grouping: 1,23,456
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f
    }
    private static let grouped0 = makeGroupedFormatter(decimals: 0)
    private static let grouped2 = makeGroupedFormatter(decimals: 2)

    private static func grouped(_ value: Double, decimals: Int) -> String {
        let f = decimals == 0 ? grouped0 : grouped2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    /// Index level, no decimals (e.g. 81,234)
    static func formatIndex(_ value: Double) -> String {
        grouped(value, decimals: 0)
    }

    /// Share price. Whole rupees (e.g. ₹2,451); two decimals only for
    /// sub-₹100 stocks, where paise are a meaningful share of the price.
    static func formatINR(_ value: Double) -> String {
        "\u{20B9}" + grouped(value, decimals: abs(value) < 100 ? 2 : 0)
    }

    /// Holding / portfolio value in INR, kept short:
    /// ₹1,234 Cr · ₹12.45 Cr · ₹45.6 L · ₹56,000
    static func formatINRCrore(_ value: Double) -> String {
        let crores = value / 10_000_000
        let lakhs = value / 100_000
        if abs(crores) >= 100 {
            return "\u{20B9}" + grouped(crores, decimals: 0) + " Cr"
        } else if abs(crores) >= 1 {
            return String(format: "\u{20B9}%.2f Cr", crores)
        } else if abs(lakhs) >= 1 {
            return String(format: "\u{20B9}%.1f L", lakhs)
        } else {
            return "\u{20B9}" + grouped(value, decimals: 0)
        }
    }

    /// USD value, kept short: $1.23B · $123M · $5.80M · $456K · $780
    static func formatUSDMillion(_ value: Double) -> String {
        let a = abs(value)
        if a >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if a >= 100_000_000 {
            return String(format: "$%.0fM", value / 1_000_000)
        } else if a >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if a >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        } else {
            return String(format: "$%.0f", value)
        }
    }

    /// Format market cap in INR — uses L Cr (lakh crore) for very large values
    static func formatMarketCapINR(_ value: Double) -> String {
        let crores = value / 10_000_000
        if crores >= 100_000 {
            // e.g. ₹20.50 L Cr  (lakh crore)
            return String(format: "\u{20B9}%.2f L Cr", crores / 100_000)
        } else if crores >= 1 {
            return String(format: "\u{20B9}%.2f Cr", crores)
        } else {
            return formatINR(value)
        }
    }

    /// Format market cap in USD — uses B (billions) / M (millions)
    static func formatMarketCapUSD(_ value: Double) -> String {
        let billions = value / 1_000_000_000
        let millions = value / 1_000_000
        if billions >= 1 {
            return String(format: "$%.2fB", billions)
        } else if millions >= 1 {
            return String(format: "$%.2fM", millions)
        } else {
            return String(format: "$%.2f", value)
        }
    }

    static func formatPercent(_ value: Double) -> String {
        let formatted = percentFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted)%"
    }

    /// Signed price/index change; whole numbers once the move is ≥ 10.
    static func formatChange(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : "-"
        let decimals = abs(value) >= 10 ? 0 : 2
        return prefix + grouped(abs(value), decimals: decimals)
    }

    /// Format share quantity in millions (e.g. "1.50M" for 1500000, "0.25M" for 250000)
    static func formatSharesMillions(_ quantity: Int) -> String {
        let millions = Double(quantity) / 1_000_000
        if millions >= 1 {
            return String(format: "%.2fM", millions)
        } else if millions >= 0.01 {
            return String(format: "%.2fM", millions)
        } else {
            // Below 10K shares, just show the number
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
        }
    }
}
