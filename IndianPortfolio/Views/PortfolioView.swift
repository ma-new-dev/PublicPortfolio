import SwiftUI
import SwiftData
import CoreData

/// Portfolio screen.
///
/// Uses a plain `NavigationSplitView` and lets iOS decide how many columns to
/// show (the same approach as MA Compass): two columns wherever the system
/// considers the window wide (unfolded inner display, iPad, Mac, large iPhones
/// in landscape), and a single collapsed stack on phone-width windows (cover
/// display, regular iPhones) where tapping a row pushes the detail.
struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \StockHolding.dateAdded, order: .reverse) private var holdings: [StockHolding]
    @State private var viewModel = PortfolioViewModel()
    @State private var showingAddSheet = false
    @State private var selectedHolding: StockHolding?
    @State private var isEditing = false
    @State private var isSyncingFromCloud = false

    /// Deduplicated holdings — keeps only the first (newest) entry per ticker
    private var uniqueHoldings: [StockHolding] {
        var seen = Set<String>()
        return holdings.filter { seen.insert($0.ticker).inserted }
    }

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    /// Phone-width window in landscape (e.g. cover display turned sideways).
    private var isPhoneLandscape: Bool { !isRegularWidth && verticalSizeClass == .compact }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Portfolio")
                .navigationBarTitleDisplayMode(isPhoneLandscape ? .inline : .automatic)
                .toolbar { toolbarItems }
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
        } detail: {
            NavigationStack {
                if let holding = selectedHolding {
                    StockDetailView(
                        holding: holding,
                        quote: viewModel.quotes[holding.ticker],
                        exchangeRate: viewModel.exchangeRate,
                        onDelete: { deleteHolding(holding) }
                    )
                    .id(holding.id)
                } else {
                    MarketOverviewView(
                        viewModel: viewModel,
                        holdings: uniqueHoldings,
                        onSelect: { selectedHolding = $0 }
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddSheet) {
            AddStockView()
                .presentationDetents([.large])
        }
        .task {
            removeDuplicates()
            await viewModel.refreshAll(holdings: uniqueHoldings)
            viewModel.startAutoRefresh(holdings: uniqueHoldings)
        }
        .onChange(of: holdings) { _, _ in
            removeDuplicates()
            Task { await viewModel.refreshAll(holdings: uniqueHoldings) }
            viewModel.startAutoRefresh(holdings: uniqueHoldings)
        }
        .onChange(of: viewModel.sortOption) { _, _ in
            viewModel.persistSortOption()
        }
        .onChange(of: scenePhase) { _, phase in
            // Don't poll in the background; refresh immediately on return.
            if phase == .active {
                Task { await viewModel.refreshAll(holdings: uniqueHoldings) }
                viewModel.startAutoRefresh(holdings: uniqueHoldings)
            } else if phase == .background {
                viewModel.stopAutoRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSPersistentCloudKitContainer.eventChangedNotification
        )) { notification in
            handleCloudKitEvent(notification)
        }
    }

    // MARK: - Sidebar (also the whole screen on phone-width windows)

    @ViewBuilder
    private var sidebar: some View {
        if uniqueHoldings.isEmpty {
            emptyState(showIndices: true)
        } else if isPhoneLandscape {
            landscapeContent
        } else {
            VStack(spacing: 0) {
                statusHeader
                indicesRow
                holdingsList
                portfolioFooter
            }
        }
    }

    /// Landscape on a phone-width window: summary on the left, list on the right.
    private var landscapeContent: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.indices) { index in
                        indexLink(index)
                    }
                    totalsView(large: false)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(12)
            }
            .frame(width: 280)
            .safeAreaInset(edge: .top, spacing: 0) { statusHeader }

            Divider()

            holdingsList
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            sortMenu
            if !uniqueHoldings.isEmpty {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation { isEditing.toggle() }
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Button {
                    Task { await viewModel.refreshAll(holdings: uniqueHoldings) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh prices")
            }
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add stock")
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Header pieces

    private var statusHeader: some View {
        VStack(spacing: 0) {
            MarketStatusBar(
                isMarketOpen: viewModel.isMarketOpen,
                exchangeRate: viewModel.exchangeRate,
                lastUpdated: viewModel.lastRefreshed,
                isSyncing: isSyncingFromCloud
            )
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
            }
        }
    }

    private var indicesRow: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.indices) { index in
                indexLink(index)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func indexLink(_ index: MarketIndex) -> some View {
        NavigationLink {
            IndexDetailView(index: index)
        } label: {
            IndexTile(index: index)
        }
        .buttonStyle(.plain)
    }

    private func totalsView(large: Bool) -> some View {
        PortfolioTotalsView(
            totalINR: viewModel.totalValueINR(for: uniqueHoldings),
            totalUSD: viewModel.totalValueUSD(for: uniqueHoldings),
            dayChangeINR: viewModel.dayChangeINR(for: uniqueHoldings),
            dayChangePercent: viewModel.dayChangePercent(for: uniqueHoldings),
            exchangeRate: viewModel.exchangeRate,
            large: large
        )
    }

    // MARK: - Empty state

    private func emptyState(showIndices: Bool) -> some View {
        VStack(spacing: 0) {
            if showIndices {
                statusHeader
                indicesRow
            }
            Spacer()
            ContentUnavailableView {
                Label("No Holdings", systemImage: "chart.bar.doc.horizontal")
            } description: {
                Text("Add Indian stocks to your portfolio to track their fair market value.")
            } actions: {
                Button("Add Stock") { showingAddSheet = true }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }

    // MARK: - Holdings list

    private var holdingsList: some View {
        List(selection: $selectedHolding) {
            if isRegularWidth {
                Section {
                    Button {
                        selectedHolding = nil
                    } label: {
                        Label("Market Overview", systemImage: "chart.xyaxis.line")
                    }
                }
            }

            Section("Holdings (\(uniqueHoldings.count))") {
                ForEach(viewModel.sortedHoldings(uniqueHoldings), id: \.id) { holding in
                    row(for: holding)
                        .tag(holding)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteHolding(holding)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete { offsets in
                    let sorted = viewModel.sortedHoldings(uniqueHoldings)
                    for index in offsets where index < sorted.count {
                        deleteHolding(sorted[index])
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .refreshable {
            await viewModel.refreshAll(holdings: uniqueHoldings)
        }
    }

    private func row(for holding: StockHolding) -> some View {
        StockRowView(
            holding: holding,
            quote: viewModel.quotes[holding.ticker],
            exchangeRate: viewModel.exchangeRate
        )
    }

    private var portfolioFooter: some View {
        VStack(spacing: 0) {
            Divider()
            totalsView(large: false)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    /// Handle a CloudKit sync event — shows a spinner while importing and
    /// triggers a dedup + refresh pass once the import finishes.
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return }

        if event.type == .import {
            if event.endDate == nil {
                isSyncingFromCloud = true
            } else {
                isSyncingFromCloud = false
                Task { @MainActor in
                    removeDuplicates()
                    await viewModel.refreshAll(holdings: uniqueHoldings)
                }
            }
        } else if event.endDate != nil {
            isSyncingFromCloud = false
        }
    }

    /// Delete a holding and all its duplicates (same ticker)
    private func deleteHolding(_ holding: StockHolding) {
        let ticker = holding.ticker
        if selectedHolding?.ticker == ticker {
            selectedHolding = nil
        }
        for h in holdings where h.ticker == ticker {
            modelContext.delete(h)
        }
    }

    /// Remove duplicate entries from the database, keeping the newest per ticker
    private func removeDuplicates() {
        var seen = Set<String>()
        for holding in holdings {
            if !seen.insert(holding.ticker).inserted {
                modelContext.delete(holding)
            }
        }
    }
}

// MARK: - Market overview (detail column on wide screens)

struct MarketOverviewView: View {
    let viewModel: PortfolioViewModel
    let holdings: [StockHolding]
    let onSelect: (StockHolding) -> Void

    struct Mover: Identifiable {
        let holding: StockHolding
        let quote: StockQuote
        var id: UUID { holding.id }
    }

    private var quoted: [Mover] {
        holdings.compactMap { h in
            guard let q = viewModel.quotes[h.ticker] else { return nil }
            return Mover(holding: h, quote: q)
        }
    }

    private var gainers: [Mover] {
        Array(quoted.filter { $0.quote.changePercent > 0 }
            .sorted { $0.quote.changePercent > $1.quote.changePercent }
            .prefix(5))
    }

    private var losers: [Mover] {
        Array(quoted.filter { $0.quote.changePercent < 0 }
            .sorted { $0.quote.changePercent < $1.quote.changePercent }
            .prefix(5))
    }

    private var largest: [StockHolding] {
        Array(holdings.sorted { viewModel.holdingValueINR(for: $0) > viewModel.holdingValueINR(for: $1) }
            .prefix(6))
    }

    var body: some View {
        AdaptiveScrollView { isWide in
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(viewModel.indices) { index in
                        NavigationLink {
                            IndexDetailView(index: index)
                        } label: {
                            IndexTile(index: index, large: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !holdings.isEmpty {
                    PortfolioTotalsView(
                        totalINR: viewModel.totalValueINR(for: holdings),
                        totalUSD: viewModel.totalValueUSD(for: holdings),
                        dayChangeINR: viewModel.dayChangeINR(for: holdings),
                        dayChangePercent: viewModel.dayChangePercent(for: holdings),
                        exchangeRate: viewModel.exchangeRate,
                        large: true
                    )
                    .cardBackground()

                    AdaptiveColumns(isWide: isWide) {
                        allocationCard
                    } secondary: {
                        moversCard(title: "Top Gainers Today", items: gainers)
                        moversCard(title: "Top Losers Today", items: losers)
                    }
                }
            }
        }
        .navigationTitle("Market Overview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var allocationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Largest Holdings")
                .font(.headline)
            ForEach(largest, id: \.id) { holding in
                let weight = viewModel.weight(of: holding, in: holdings)
                Button {
                    onSelect(holding)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(DisplayText.company(holding.companyName))
                                .lineLimit(1)
                            Spacer()
                            Text(CurrencyFormatter.formatUSDMillion(viewModel.holdingValueUSD(for: holding)))
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                            Text(String(format: "%.1f%%", weight))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 56, alignment: .trailing)
                        }
                        .font(.subheadline)
                        ProgressView(value: min(max(weight, 0), 100), total: 100)
                            .tint(.blue)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func moversCard(title: String, items: [Mover]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if items.isEmpty {
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { mover in
                    Button {
                        onSelect(mover.holding)
                    } label: {
                        HStack {
                            Text(DisplayText.company(mover.holding.companyName))
                                .lineLimit(1)
                            Spacer()
                            Text(CurrencyFormatter.formatPercent(mover.quote.changePercent))
                                .fontWeight(.semibold)
                                .foregroundStyle(mover.quote.isPositive ? .green : .red)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
