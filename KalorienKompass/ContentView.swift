import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CalorieStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Heute", systemImage: "chart.pie.fill")
                }

            NeedsCalculatorView()
                .tabItem {
                    Label("Bedarf", systemImage: "target")
                }

            TrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "figure.run")
                }

            FoodScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
        }
        .tint(AppColor.leaf)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CalorieStore.preview)
        .environmentObject(HealthDataManager())
}
