import Foundation

@MainActor
final class CalorieStore: ObservableObject {
    @Published var entries: [FoodEntry] = [] {
        didSet { saveEntries() }
    }

    @Published var savedMeals: [SavedMeal] = [] {
        didSet { saveSavedMeals() }
    }

    @Published var profile = UserProfile() {
        didSet { saveProfile() }
    }

    @Published var appearanceMode: AppearanceMode = .system {
        didSet { saveAppearanceMode() }
    }

    private let entriesKey = "calorieEntries"
    private let savedMealsKey = "savedMeals"
    private let profileKey = "userProfile"
    private let appearanceModeKey = "appearanceMode"
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

    func addEntry(name: String, calories: Int, protein: Int, imageData: Data? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FoodEntry(
            name: trimmedName.isEmpty ? "Mahlzeit" : trimmedName,
            calories: max(0, calories),
            protein: max(0, protein),
            date: .now,
            imageData: imageData
        )
        entries.append(entry)
    }

    func addEntry(from meal: SavedMeal) {
        addEntry(
            name: meal.name,
            calories: meal.calories,
            protein: meal.protein,
            imageData: meal.imageData
        )
    }

    func saveMeal(name: String, calories: Int, protein: Int, imageData: Data?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let meal = SavedMeal(
            name: trimmedName.isEmpty ? "Mahlzeit" : trimmedName,
            calories: max(0, calories),
            protein: max(0, protein),
            imageData: imageData
        )
        savedMeals.insert(meal, at: 0)
    }

    func deleteEntries(at offsets: IndexSet) {
        let ids = offsets.map { todaysEntries[$0].id }
        entries.removeAll { ids.contains($0.id) }
    }

    func deleteEntry(_ entry: FoodEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func deleteSavedMeal(_ meal: SavedMeal) {
        savedMeals.removeAll { $0.id == meal.id }
    }

    private func load() {
        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decodedEntries = try? decoder.decode([FoodEntry].self, from: data) {
            entries = decodedEntries
        }

        if let data = UserDefaults.standard.data(forKey: savedMealsKey),
           let decodedMeals = try? decoder.decode([SavedMeal].self, from: data) {
            savedMeals = decodedMeals
        }

        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decodedProfile = try? decoder.decode(UserProfile.self, from: data) {
            profile = decodedProfile
        }

        if let rawValue = UserDefaults.standard.string(forKey: appearanceModeKey),
           let decodedMode = AppearanceMode(rawValue: rawValue) {
            appearanceMode = decodedMode
        }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    private func saveSavedMeals() {
        if let data = try? JSONEncoder().encode(savedMeals) {
            UserDefaults.standard.set(data, forKey: savedMealsKey)
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private func saveAppearanceMode() {
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: appearanceModeKey)
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
        store.savedMeals = [
            SavedMeal(name: "Skyr mit Beeren", calories: 310, protein: 32),
            SavedMeal(name: "Hähnchen-Bowl", calories: 640, protein: 48)
        ]
        return store
    }
}
