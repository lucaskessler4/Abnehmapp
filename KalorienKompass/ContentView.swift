import SwiftUI

struct ContentView: View {
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

            FoodScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
        }
        .tint(AppColor.leaf)
    }
}

#Preview {
    ContentView()
        .environmentObject(CalorieStore.preview)
}
