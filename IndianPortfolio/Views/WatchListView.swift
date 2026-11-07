import SwiftUI
import SwiftData
import CoreData

struct WatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WatchListItem.dateAdded, order: .reverse) private var items: [WatchListItem]

    @State private var viewModel = WatchListViewModel()
    @State private var showingAddSheet = false
    @State private var selectedItem: WatchListItem?
    @State private var isSyncingFromCloud = false

    /// Plain split view; iOS decides one vs two columns (see PortfolioView).
    var body: some View {
        NavigationSplitView {
            mainContent
                .navigationTitle("Watch List")
                .toolbar { toolbarItems }
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 440)
        } detail: {
            NavigationStack {
                if let item = selectedItem {
                    WatchListDetailView(
                        item: item,
                        quote: viewModel.quotes[item.ticker],
                        exchangeRate: viewModel.exchangeRate,
                        onDelete: { remove(item) }
                    )
                    .id(item.id)
                } else {
                    ContentUnavailableView(
                        "Select a Stock",
                        systemImage: "eye",
                        description: Text("Choose a stock from your Watch List to view details.")
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddSheet) {
            AddWatchListItemView(existingTickers: Set(items.map(\.ticker)))
                .presentationDetents([.large])
        }
        .task {
            await viewModel.refreshAll(items: items)
            viewModel.startAutoRefresh(items: items)
        }
        .onChange(of: items) { _, _ in
            Task { await viewModel.refreshAll(items: items) }
            viewModel.startAutoRefresh(items: items)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refreshAll(items: items) }
                viewModel.startAutoRefresh(items: items)
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

    // MARK: - CloudKit sync

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return }

        if event.type == .import {
            if event.endDate == nil {
                isSyncingFromCloud = true
            } else {
                isSyncingFromCloud = false
                Task { await viewModel.refreshAll(items: items) }
            }
        } else if event.endDate != nil {
            isSyncingFromCloud = false
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
            } else if isSyncingFromCloud {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Syncing from iCloud…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Button {
                    Task { await viewModel.refreshAll(items: items) }
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
            .accessibilityLabel("Add to watch list")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Stocks", systemImage: "eye.slash")
        } description: {
            Text("Add stocks to your Watch List to track their prices.")
        } actions: {
            Button("Add Stock") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        List(selection: $selectedItem) {
            Section("Watching (\(items.count))") {
                ForEach(items) { item in
                    WatchListRowView(
                        item: item,
                        quote: viewModel.quotes[item.ticker]
                    )
                    .tag(item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            remove(item)
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshAll(items: items) }
    }

    private func remove(_ item: WatchListItem) {
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
        modelContext.delete(item)
    }
}
