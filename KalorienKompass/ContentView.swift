import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CalorieStore
    @State private var selectedTab: AppTab = .today
    @Namespace private var tabAnimation
    @State private var dockBarHeight: CGFloat = 0
    @State private var safeBottomInset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            activeView
                .environment(\.bottomDockClearance, dockBarHeight + safeBottomInset + 16)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        SmartDock(
                            selectedTab: $selectedTab,
                            animation: tabAnimation
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .background {
                            GeometryReader { dockProxy in
                                Color.clear
                                    .onAppear {
                                        dockBarHeight = dockProxy.size.height
                                    }
                                    .onChange(of: dockProxy.size.height) { _, newHeight in
                                        dockBarHeight = newHeight
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                .onAppear {
                    safeBottomInset = proxy.safeAreaInsets.bottom
                }
                .onChange(of: proxy.safeAreaInsets.bottom) { _, newSafeBottom in
                    safeBottomInset = newSafeBottom
                }
                .preferredColorScheme(preferredColorScheme)
        }
    }

    @ViewBuilder
    private var activeView: some View {
        switch selectedTab {
        case .today:
            TodayView()
        case .needs:
            NeedsCalculatorView()
        case .tracking:
            TrackingView()
        case .calendar:
            CalendarView()
        case .scan:
            FoodScanView()
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct BottomDockClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var bottomDockClearance: CGFloat {
        get { self[BottomDockClearanceKey.self] }
        set { self[BottomDockClearanceKey.self] = newValue }
    }
}

#Preview {
    ContentView()
        .environmentObject(CalorieStore.preview)
        .environmentObject(HealthDataManager())
}

private enum AppTab: String, CaseIterable, Identifiable {
    case today
    case needs
    case tracking
    case calendar
    case scan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Heute"
        case .needs: return "Bedarf"
        case .tracking: return "Tracking"
        case .calendar: return "Kalender"
        case .scan: return "Scan"
        }
    }

    var icon: String {
        switch self {
        case .today: return "chart.pie.fill"
        case .needs: return "target"
        case .tracking: return "figure.run"
        case .calendar: return "calendar"
        case .scan: return "camera.viewfinder"
        }
    }
}

private struct SmartDock: View {
    @Binding var selectedTab: AppTab
    var animation: Namespace.ID

    private let sideTabs: [AppTab] = [.today, .needs, .tracking, .calendar]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(sideTabs.prefix(2)) { tab in
                SmartDockItem(
                    tab: tab,
                    selectedTab: $selectedTab,
                    animation: animation
                )
            }

            scanButton
                .padding(.horizontal, 4)

            ForEach(sideTabs.suffix(2)) { tab in
                SmartDockItem(
                    tab: tab,
                    selectedTab: $selectedTab,
                    animation: animation
                )
            }
        }
        .padding(10)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.14),
                                    .white.opacity(0.05),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blendMode(.screen)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }

    private var scanButton: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                selectedTab = .scan
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: AppTab.scan.icon)
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(AppColor.leaf, in: Circle())
                    .foregroundStyle(.white)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.8), lineWidth: 1.2)
                    }
                    .shadow(color: AppColor.leaf.opacity(0.45), radius: 10, y: 4)

                Text(AppTab.scan.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selectedTab == .scan ? AppColor.leaf : AppColor.muted)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan öffnen")
    }
}

private struct SmartDockItem: View {
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var animation: Namespace.ID

    private var isSelected: Bool {
        selectedTab == tab
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .frame(width: 30, height: 24)

                Text(tab.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? AppColor.leaf : AppColor.muted)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(AppColor.mint.opacity(0.92))
                        .matchedGeometryEffect(id: "active-tab", in: animation)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}
