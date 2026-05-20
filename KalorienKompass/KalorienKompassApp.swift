import SwiftUI

@main
struct KalorienKompassApp: App {
    @StateObject private var store = CalorieStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
