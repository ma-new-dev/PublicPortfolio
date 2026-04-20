import SwiftUI
import SwiftData
import CoreData

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \StockHolding.dateAdded, order: .reverse) private var holdings: [StockHolding]
    @State private var viewModel = PortfolioViewModel()
    @State private var showingAddSheet = false
    @State private var showingAccountSettings = false
    @State private var selectedHolding: StockHolding?
    @State private var isEditing = false
    @State private var isSyncingFromCloud = false

    /// Deduplicated holdings — keeps only the first (newest) entry per ticker
    private var uniqueHoldings: [StockHolding] {
        var seen = Set<String>()
        return holdings.filter { holding in
            if seen.contains(holding.ticker) {
                return false
            }
            seen.insert(holding.ticker)
            return true
        }
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var iPadLayout: some View {
        NavigationSplitView {
            mainContent
                .navigationTitle("Portfolio")
                .toolbar { toolbarItems }
                .sheet(isPresented: $showingAccountSettings) {
                    AccountSettingsView()
                }
        } detail: {
            if let holding = selectedHolding {
                StockDetailView(
                    holding: holding,
                    quote: viewModel.quotes[holding.ticker],
                    exchangeRate: viewModel.exchangeRate
                )
            } else {
                ContentUnavailableView(
                    "Select a Stock",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Choose a holding from the list to view details.")
                )
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddStockView()
                .presentationDetents([.large])
        }
        .task {
            removeDuplicates()
            await viewModel.refreshAll(holdings: uniqueHoldings)
        }
        .onChange(of: holdings) { _, _ in
            removeDuplicates()
            Task { await viewModel.refreshAll(holdings: uniqueHoldings) }
            viewModel.startAutoRefresh(holdings: uniqueHoldings)
        }
        .onAppear {
            viewModel.startAutoRefresh(holdings: uniqueHoldings)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .refreshable {
            await viewModel.refreshAll(holdings: uniqueHoldings)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSPersistentCloudKitContainer.eventChangedNotification
        )) { notification in
            handleCloudKitEvent(notification)
        }
    }

    // MARK: - iPhone Layout (NavigationStack)

    private var iPhoneLayout: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Portfolio")
                .toolbar { toolbarItems }
                .sheet(isPresented: $showingAccountSettings) {
                    AccountSettingsView()
                }
                .sheet(isPresented: $showingAddSheet) {
                    AddStockView()
                        .presentationDetents([.large])
                }
                .task {
                    removeDuplicates()
                    await viewModel.refreshAll(holdings: uniqueHoldings)
                }
                .onChange(of: holdings) { _, _ in
                    removeDuplicates()
                    Task { await viewModel.refreshAll(holdings: uniqueHoldings) }
                    viewModel.startAutoRefresh(holdings: uniqueHoldings)
                }
                .onAppear {
                    viewModel.startAutoRefresh(holdings: uniqueHoldings)
                }
                .onDisappear {
                    viewModel.stopAutoRefresh()
                }
                .refreshable {
                    await viewModel.refreshAll(holdings: uniqueHoldings)
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: NSPersistentCloudKitContainer.eventChangedNotification
                )) { notification in
                    handleCloudKitEvent(notification)
                }
        }
    }

    // MARK: - Shared main content

    private var mainContent: some View {
        ZStack {
            if uniqueHoldings.isEmpty {
                emptyState
            } else {
                holdingsList
            }
        }
    }

    // MARK: - Toolbar items

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 12) {
                sortMenu
                Button {
                    withAnimation {
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.subheadline)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.refreshAll(holdings: uniqueHoldings) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    showingAccountSettings = true
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
    }

    // MARK: - Sort menu

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Sort")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            // Market status bar
            marketStatusBar

            // Market indices
            indicesSection

            Spacer()

            ContentUnavailableView {
                Label("No Holdings", systemImage: "chart.bar.doc.horizontal")
            } description: {
                Text("Add Indian stocks to your portfolio to track their fair market value.")
            } actions: {
                Button("Add Stock") {
                    showingAddSheet = true
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
    }

    // MARK: - Market status bar

    private var marketStatusBar: some View {
        HStack {
            if isSyncingFromCloud {
                ProgressView()
                    .controlSize(.mini)
                Text("Syncing from iCloud…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(viewModel.isMarketOpen ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(MarketStatusService.marketStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.exchangeRate > 0 {
                Text("1 USD = \(String(format: "%.2f", 1.0 / viewModel.exchangeRate)) INR")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    // MARK: - Market Indices

    private var indicesSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(viewModel.indices) { index in
                    NavigationLink {
                        IndexDetailView(index: index)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(index.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            if index.value > 0 {
                                Text(String(format: "%.0f", index.value))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                HStack(spacing: 4) {
                                    Image(systemName: index.isPositive ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption2)
                                    Text(CurrencyFormatter.formatPercent(index.changePercent))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(index.isPositive ? .green : .red)
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Holdings list

    private var holdingsList: some View {
        VStack(spacing: 0) {
            // Market status bar
            marketStatusBar

            // Market indices
            indicesSection

            // Stocks list
            List {
                Section("Holdings (\(uniqueHoldings.count))") {
                    ForEach(viewModel.sortedHoldings(uniqueHoldings), id: \.id) { holding in
                        Group {
                            if horizontalSizeClass == .regular {
                                // iPad: tap to select, show detail in split view
                                Button {
                                    selectedHolding = holding
                                } label: {
                                    StockRowView(
                                        holding: holding,
                                        quote: viewModel.quotes[holding.ticker],
                                        exchangeRate: viewModel.exchangeRate
                                    )
                                }
                                .listRowBackground(
                                    selectedHolding?.id == holding.id
                                        ? Color.blue.opacity(0.1)
                                        : Color(.systemBackground)
                                )
                            } else {
                                // iPhone: NavigationLink pushes detail
                                NavigationLink {
                                    StockDetailView(
                                        holding: holding,
                                        quote: viewModel.quotes[holding.ticker],
                                        exchangeRate: viewModel.exchangeRate
                                    )
                                } label: {
                                    StockRowView(
                                        holding: holding,
                                        quote: viewModel.quotes[holding.ticker],
                                        exchangeRate: viewModel.exchangeRate
                                    )
                                }
                            }
                        }
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
                        for index in offsets {
                            deleteHolding(sorted[index])
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))

            // Bottom portfolio total
            portfolioFooter
        }
    }

    // MARK: - Portfolio footer

    private var portfolioFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Portfolio Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINRCrore(viewModel.totalValueINR(for: uniqueHoldings)))
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("USD Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatUSDMillion(viewModel.totalValueUSD(for: uniqueHoldings)))
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
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
                // Import in progress
                isSyncingFromCloud = true
            } else {
                // Import finished
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
        for h in holdings where h.ticker == ticker {
            modelContext.delete(h)
        }
        if selectedHolding?.ticker == ticker {
            selectedHolding = nil
        }
    }

    /// Remove duplicate entries from the database, keeping the newest per ticker
    private func removeDuplicates() {
        var seen = Set<String>()
        for holding in holdings {
            if seen.contains(holding.ticker) {
                modelContext.delete(holding)
            } else {
                seen.insert(holding.ticker)
            }
        }
    }
}
