import SwiftUI

@main
struct KalorienKompassApp: App {
    @StateObject private var store = CalorieStore()
    @StateObject private var healthDataManager = HealthDataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(healthDataManager)
                .task {
                    guard store.hasConnectedActivitySources else { return }

                    await healthDataManager.configureAutomaticSync { caloriesBySource in
                        store.replaceTodaysTrackedActivities(caloriesBySource)
                    }
                }
        }
    }
}
