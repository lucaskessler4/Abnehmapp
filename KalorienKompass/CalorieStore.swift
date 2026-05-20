import Foundation

struct DayCalorieSummary: Identifiable, Equatable {
    let date: Date
    let consumedCalories: Int
    let activityCalories: Int
    let targetCalories: Int
    let maxCaloriesWithoutDeficit: Int
    let plannedDeficit: Int

    var id: Date { date }

    var balance: Int {
        targetCalories - consumedCalories
    }

    var actualDeficit: Int {
        maxCaloriesWithoutDeficit - consumedCalories
    }

    var hasDeficit: Bool {
        actualDeficit > 0
    }

    var reachedPlannedDeficit: Bool {
        balance >= 0
    }
}

@MainActor
final class CalorieStore: ObservableObject {
    @Published var entries: [FoodEntry] = [] {
        didSet {
            guard !isApplyingPersistenceSanitization else { return }
            saveEntries()
        }
    }

    @Published var savedMeals: [SavedMeal] = [] {
        didSet {
            guard !isApplyingPersistenceSanitization else { return }
            saveSavedMeals()
        }
    }

    @Published var notes: [DailyNote] = [] {
        didSet { saveNotes() }
    }

    @Published var activityEntries: [ActivityCalorieEntry] = [] {
        didSet { saveActivityEntries() }
    }

    @Published var connectedActivitySources: [ActivitySource] = [] {
        didSet { saveConnectedActivitySources() }
    }

    @Published var profile = UserProfile() {
        didSet { saveProfile() }
    }

    @Published var appearanceMode: AppearanceMode = .system {
        didSet { saveAppearanceMode() }
    }

    private let entriesKey = "calorieEntries"
    private let savedMealsKey = "savedMeals"
    private let notesKey = "dailyNotes"
    private let activityEntriesKey = "activityCalorieEntries"
    private let connectedActivitySourcesKey = "connectedActivitySources"
    private let profileKey = "userProfile"
    private let appearanceModeKey = "appearanceMode"
    private let calendar = Calendar.current
    private let maxUserDefaultsPayloadBytes = 3_500_000
    private var isApplyingPersistenceSanitization = false

    init() {
        load()
    }

    var todaysEntries: [FoodEntry] {
        entries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var todaysNotes: [DailyNote] {
        notes
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var todaysCalories: Int {
        todaysEntries.reduce(0) { $0 + $1.calories }
    }

    var todaysActivityEntries: [ActivityCalorieEntry] {
        activityEntries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var todaysActivityCalories: Int {
        todaysActivityEntries.reduce(0) { $0 + $1.calories }
    }

    var todaysProtein: Int {
        todaysEntries.reduce(0) { $0 + $1.protein }
    }

    var adjustedTargetCalories: Int {
        profile.targetCalories + todaysActivityCalories
    }

    var hasConnectedActivitySources: Bool {
        !connectedActivitySources.isEmpty
    }

    var remainingCalories: Int {
        adjustedTargetCalories - todaysCalories
    }

    var calorieProgress: Double {
        guard adjustedTargetCalories > 0 else { return 0 }
        return min(Double(todaysCalories) / Double(adjustedTargetCalories), 1.0)
    }

    var foodTrackingStreak: Int {
        let trackedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !trackedDays.isEmpty else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: .now)

        if !trackedDays.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }

        while trackedDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        return streak
    }

    func daySummary(for date: Date) -> DayCalorieSummary {
        let dayStart = calendar.startOfDay(for: date)
        let consumedCalories = entries
            .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
            .reduce(0) { $0 + $1.calories }
        let activityCalories = activityEntries
            .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
            .reduce(0) { $0 + $1.calories }
        let maxCaloriesWithoutDeficit = profile.maintenanceCalories + activityCalories
        let targetCalories = max(1200, maxCaloriesWithoutDeficit - profile.desiredCalorieDeficit)

        return DayCalorieSummary(
            date: dayStart,
            consumedCalories: consumedCalories,
            activityCalories: activityCalories,
            targetCalories: targetCalories,
            maxCaloriesWithoutDeficit: maxCaloriesWithoutDeficit,
            plannedDeficit: profile.desiredCalorieDeficit
        )
    }

    func daySummariesForMonth(containing monthDate: Date) -> [DayCalorieSummary] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        var day = monthInterval.start
        var summaries: [DayCalorieSummary] = []

        while day < monthInterval.end {
            summaries.append(daySummary(for: day))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return summaries
    }

    func historicalTrackedDaySummaries(until endDate: Date = .now) -> [DayCalorieSummary] {
        let trackedDates = entries.map(\.date) + activityEntries.map(\.date)
        guard let earliestTrackedDate = trackedDates.min() else { return [] }

        let startDay = calendar.startOfDay(for: earliestTrackedDate)
        let endDay = calendar.startOfDay(for: endDate)
        guard startDay <= endDay else { return [] }

        var day = startDay
        var summaries: [DayCalorieSummary] = []

        while day <= endDay {
            let summary = daySummary(for: day)
            let isTracked = summary.consumedCalories > 0 || summary.activityCalories > 0
            if isTracked {
                summaries.append(summary)
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return summaries
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

    func addNote(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        notes.insert(
            DailyNote(text: trimmedText, date: .now),
            at: 0
        )
    }

    func addActivity(source: ActivitySource, calories: Int, note: String = "") {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ActivityCalorieEntry(
            source: source,
            calories: max(0, calories),
            date: .now,
            note: trimmedNote
        )
        activityEntries.append(entry)
    }

    func replaceTodaysActivity(source: ActivitySource, calories: Int, note: String = "") {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        activityEntries.removeAll {
            calendar.isDateInToday($0.date) && $0.source == source && $0.replacesSourceForDay
        }

        guard calories > 0 else { return }

        let entry = ActivityCalorieEntry(
            source: source,
            calories: max(0, calories),
            date: .now,
            note: trimmedNote,
            replacesSourceForDay: true
        )
        activityEntries.append(entry)
    }

    func connectActivitySource(_ source: ActivitySource) {
        guard source != .manual,
              !connectedActivitySources.contains(source) else { return }

        connectedActivitySources.append(source)
    }

    func disconnectActivitySource(_ source: ActivitySource) {
        connectedActivitySources.removeAll { $0 == source }
        activityEntries.removeAll {
            calendar.isDateInToday($0.date) && $0.source == source && $0.replacesSourceForDay
        }
    }

    func isActivitySourceConnected(_ source: ActivitySource) -> Bool {
        connectedActivitySources.contains(source)
    }

    func replaceTodaysTrackedActivities(_ caloriesBySource: [ActivitySource: Int]) {
        let automaticSources = Set(connectedActivitySources)
        activityEntries.removeAll {
            calendar.isDateInToday($0.date)
                && automaticSources.contains($0.source)
                && $0.replacesSourceForDay
        }

        for source in automaticSources {
            guard source != .manual else { continue }
            let calories = max(0, caloriesBySource[source] ?? 0)
            guard calories > 0 else { continue }

            activityEntries.append(
                ActivityCalorieEntry(
                    source: source,
                    calories: calories,
                    date: .now,
                    note: source == .garmin ? "Automatisch aus Garmin Connect" : "Automatisch aus Apple Health",
                    replacesSourceForDay: true
                )
            )
        }
    }

    func updateNote(_ note: DailyNote, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
              let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        notes[index].text = trimmedText
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

    func deleteNote(_ note: DailyNote) {
        notes.removeAll { $0.id == note.id }
    }

    func deleteActivityEntry(_ entry: ActivityCalorieEntry) {
        activityEntries.removeAll { $0.id == entry.id }
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

        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decodedNotes = try? decoder.decode([DailyNote].self, from: data) {
            notes = decodedNotes
        }

        if let data = UserDefaults.standard.data(forKey: activityEntriesKey),
           let decodedActivityEntries = try? decoder.decode([ActivityCalorieEntry].self, from: data) {
            activityEntries = decodedActivityEntries
        }

        if let data = UserDefaults.standard.data(forKey: connectedActivitySourcesKey),
           let decodedConnectedActivitySources = try? decoder.decode([ActivitySource].self, from: data) {
            connectedActivitySources = decodedConnectedActivitySources
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
        let payload = sanitizedEntryPayload()
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: entriesKey)
            if payload != entries {
                isApplyingPersistenceSanitization = true
                entries = payload
                isApplyingPersistenceSanitization = false
            }
        }
    }

    private func saveSavedMeals() {
        let payload = sanitizedSavedMealPayload()
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: savedMealsKey)
            if payload != savedMeals {
                isApplyingPersistenceSanitization = true
                savedMeals = payload
                isApplyingPersistenceSanitization = false
            }
        }
    }

    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    private func saveActivityEntries() {
        if let data = try? JSONEncoder().encode(activityEntries) {
            UserDefaults.standard.set(data, forKey: activityEntriesKey)
        }
    }

    private func saveConnectedActivitySources() {
        if let data = try? JSONEncoder().encode(connectedActivitySources) {
            UserDefaults.standard.set(data, forKey: connectedActivitySourcesKey)
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

    private func sanitizedEntryPayload() -> [FoodEntry] {
        guard let encoded = try? JSONEncoder().encode(entries),
              encoded.count > maxUserDefaultsPayloadBytes else {
            return entries
        }

        return entries.map { entry in
            var sanitized = entry
            sanitized.imageData = nil
            return sanitized
        }
    }

    private func sanitizedSavedMealPayload() -> [SavedMeal] {
        guard let encoded = try? JSONEncoder().encode(savedMeals),
              encoded.count > maxUserDefaultsPayloadBytes else {
            return savedMeals
        }

        return savedMeals.map { meal in
            var sanitized = meal
            sanitized.imageData = nil
            return sanitized
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
            desiredCalorieDeficit: 500,
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
        store.notes = [
            DailyNote(text: "Heute mehr trinken und abends kurz spazieren gehen.", date: .now),
            DailyNote(text: "Mittagessen war sättigend, Snack am Nachmittag planen.", date: .now)
        ]
        store.activityEntries = [
            ActivityCalorieEntry(source: .appleHealth, calories: 280, date: .now, note: "Active Energy", replacesSourceForDay: true),
            ActivityCalorieEntry(source: .garmin, calories: 180, date: .now, note: "Lauftraining")
        ]
        store.connectedActivitySources = [.appleHealth, .garmin]
        return store
    }
}
