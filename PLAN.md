# Plan: macOS Desktop Widget + iPad App

## Approach

### macOS Widget
Since you have an Apple Silicon iMac, the simplest and most reliable approach is:
1. Add `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES` — this makes the iOS app run natively on your Mac
2. Add a **WidgetKit extension** to the iOS app — this widget automatically appears in the macOS widget gallery too
3. Use **App Groups** + **UserDefaults** to share holdings data between the app and the widget
4. The widget fetches live prices independently (same Yahoo Finance API)

Widget sizes:
- **Small**: Portfolio total (INR Cr + USD M) + market status
- **Medium**: Portfolio total + top 3 holdings with price & % change
- **Large**: Portfolio total + SENSEX/NIFTY indices + top 5 holdings

### iPad App
The app already targets iPad (TARGETED_DEVICE_FAMILY = "1,2"). Key improvements:
- Use `NavigationSplitView` on iPad for master-detail layout (sidebar of holdings, detail shows stock chart)
- Wider stat grids (4 columns instead of 2) on iPad
- Toolbar add button instead of floating action button on iPad

## New Files (8 files)

1. `PortfolioWidget/PortfolioWidget.swift` — Widget entry point (@main WidgetBundle)
2. `PortfolioWidget/PortfolioTimelineProvider.swift` — Timeline provider + entry models
3. `PortfolioWidget/PortfolioWidgetViews.swift` — Small/Medium/Large widget views
4. `PortfolioWidget/WidgetDataService.swift` — Lightweight API fetcher for widget process
5. `PortfolioWidget/Assets.xcassets/` — Widget asset catalog (Contents.json + AccentColor)
6. `PortfolioWidget/PortfolioWidgetExtension.entitlements` — App Group entitlement
7. `IndianPortfolio/IndianPortfolio.entitlements` — App Group entitlement for main app
8. `IndianPortfolio/Shared/PortfolioDataStore.swift` — Shared UserDefaults data bridge

## Modified Files (4 files)

1. `project.pbxproj` — Add widget extension target, embed phase, dependency, build configs, Mac support flag
2. `PortfolioView.swift` — iPad NavigationSplitView, widget data sync after refresh
3. `PortfolioViewModel.swift` — Add WidgetKit import, notify widget on data refresh
4. `Constants.swift` — Add App Group ID constant

## Build & Install

- **iPad**: Build with `-destination 'platform=iOS Simulator,name=iPad Pro'` or install on physical iPad
- **Mac widget**: Build for iOS, install on Mac via "Designed for iPad" mode, then add widget from macOS widget gallery
- **iPhone**: Same as current — build and install via devicectl
