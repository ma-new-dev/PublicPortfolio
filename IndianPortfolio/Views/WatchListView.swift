import SwiftUI
import SwiftData

struct WatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \WatchListItem.dateAdded, order: .reverse) private var items: [WatchListItem]

    @State private var viewModel = WatchListViewModel()
    @State private var showingAddSheet = false
    @State private var selectedItem: WatchListItem?

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            mainContent
                .navigationTitle("Watch List")
                .toolbar { toolbarItems }
        } detail: {
            if let item = selectedItem {
                WatchListDetailView(
                    item: item,
                    quote: viewModel.quotes[item.ticker],
                    exchangeRate: viewModel.exchangeRate
                )
            } else {
                ContentUnavailableView(
                    "Select a Stock",
                    systemImage: "eye",
                    description: Text("Choose a stock from your Watch List to view details.")
                )
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddWatchListItemView(existingTickers: Set(items.map(\.ticker)))
                .presentationDetents([.large])
        }
        .task { await viewModel.refreshAll(items: items) }
        .onChange(of: items.count) { _, _ in
            Task { await viewModel.refreshAll(items: items) }
            viewModel.startAutoRefresh(items: items)
        }
        .onAppear { viewModel.startAutoRefresh(items: items) }
        .onDisappear { viewModel.stopAutoRefresh() }
        .refreshable { await viewModel.refreshAll(items: items) }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Watch List")
                .toolbar { toolbarItems }
                .sheet(isPresented: $showingAddSheet) {
                    AddWatchListItemView(existingTickers: Set(items.map(\.ticker)))
                        .presentationDetents([.large])
                }
                .task { await viewModel.refreshAll(items: items) }
                .onChange(of: items.count) { _, _ in
                    Task { await viewModel.refreshAll(items: items) }
                    viewModel.startAutoRefresh(items: items)
                }
                .onAppear { viewModel.startAutoRefresh(items: items) }
                .onDisappear { viewModel.stopAutoRefresh() }
                .refreshable { await viewModel.refreshAll(items: items) }
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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.refreshAll(items: items) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
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
        List {
            Section("Watching (\(items.count))") {
                ForEach(items) { item in
                    Group {
                        if horizontalSizeClass == .regular {
                            Button {
                                selectedItem = item
                            } label: {
                                WatchListRowView(
                                    item: item,
                                    quote: viewModel.quotes[item.ticker]
                                )
                            }
                            .listRowBackground(
                                selectedItem?.id == item.id
                                    ? Color.blue.opacity(0.1)
                                    : Color(.systemBackground)
                            )
                        } else {
                            NavigationLink {
                                WatchListDetailView(
                                    item: item,
                                    quote: viewModel.quotes[item.ticker],
                                    exchangeRate: viewModel.exchangeRate
                                )
                            } label: {
                                WatchListRowView(
                                    item: item,
                                    quote: viewModel.quotes[item.ticker]
                                )
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            modelContext.delete(item)
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
