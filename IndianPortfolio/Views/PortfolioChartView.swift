import SwiftUI
import Charts

struct PortfolioChartView: View {
    let dataPoints: [IntradayDataPoint]

    private var minValue: Double {
        (dataPoints.map(\.price).min() ?? 0) * 0.999
    }

    private var maxValue: Double {
        (dataPoints.map(\.price).max() ?? 0) * 1.001
    }

    private var isPositive: Bool {
        guard let first = dataPoints.first?.price,
              let last = dataPoints.last?.price else { return true }
        return last >= first
    }

    var body: some View {
        if dataPoints.isEmpty {
            ContentUnavailableView(
                "No Chart Data",
                systemImage: "chart.line.downtrend.xyaxis",
                description: Text("Chart data will appear when the market is open")
            )
            .frame(height: 200)
        } else {
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.price)
                )
                .foregroundStyle(isPositive ? Color.green : Color.red)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            (isPositive ? Color.green : Color.red).opacity(0.3),
                            (isPositive ? Color.green : Color.red).opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: minValue...maxValue)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(CurrencyFormatter.formatINR(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }
}
