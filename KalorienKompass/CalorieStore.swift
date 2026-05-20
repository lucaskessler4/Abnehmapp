import Foundation

@MainActor
final class CalorieStore: ObservableObject {
    @Published var entries: [FoodEntry] = [] {
        didSet { saveEntries() }
    }

    @Published var profile = UserProfile() {
        didSet { saveProfile() }
    }

    private let entriesKey = "calorieEntries"
    private let profileKey = "userProfile"
    private let calendar = Calendar.current

    init() {
        load()
    }

    var todaysEntries: [FoodEntry] {
        entries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var todaysCalories: Int {
        todaysEntries.reduce(0) { $0 + $1.calories }
    }

    var todaysProtein: Int {
        todaysEntries.reduce(0) { $0 + $1.protein }
    }

    var remainingCalories: Int {
        profile.targetCalories - todaysCalories
    }

    var calorieProgress: Double {
        guard profile.targetCalories > 0 else { return 0 }
        return min(Double(todaysCalories) / Double(profile.targetCalories), 1.0)
    }

    func addEntry(name: String, calories: Int, protein: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FoodEntry(
            name: trimmedName.isEmpty ? "Mahlzeit" : trimmedName,
            calories: max(0, calories),
            protein: max(0, protein),
            date: .now
        )
        entries.append(entry)
    }

    func deleteEntries(at offsets: IndexSet) {
        let ids = offsets.map { todaysEntries[$0].id }
        entries.removeAll { ids.contains($0.id) }
    }

    func deleteEntry(_ entry: FoodEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    private func load() {
        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decodedEntries = try? decoder.decode([FoodEntry].self, from: data) {
            entries = decodedEntries
        }

        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decodedProfile = try? decoder.decode(UserProfile.self, from: data) {
            profile = decodedProfile
        }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
}

extension CalorieStore {
    static var preview: CalorieStore {
        let store = CalorieStore()
        store.profile = UserProfile(
            sex: .male,
            age: 31,
            heightCentimeters: 182,
            weightKilograms: 88,
            targetWeightKilograms: 80,
            activityLevel: .light,
            goal: .loseSteady
        )
        store.entries = [
            FoodEntry(name: "Skyr mit Beeren", calories: 310, protein: 32, date: .now),
            FoodEntry(name: "Hähnchen-Bowl", calories: 640, protein: 48, date: .now)
        ]
        return store
    }
}
