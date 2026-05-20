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
        case .advisor:
            NutritionAdvisorView()
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
    case advisor
    case scan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Heute"
        case .needs: return "Bedarf"
        case .tracking: return "Tracking"
        case .calendar: return "Kalender"
        case .advisor: return "Berater"
        case .scan: return "Scan"
        }
    }

    var icon: String {
        switch self {
        case .today: return "chart.pie.fill"
        case .needs: return "target"
        case .tracking: return "figure.run"
        case .calendar: return "calendar"
        case .advisor: return "sparkles"
        case .scan: return "camera.viewfinder"
        }
    }
}

private struct SmartDock: View {
    @Binding var selectedTab: AppTab
    var animation: Namespace.ID

    private let sideTabs: [AppTab] = [.today, .needs, .tracking, .calendar, .advisor]

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

            ForEach(sideTabs.suffix(3)) { tab in
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

private struct NutritionAdvisorView: View {
    @Environment(\.bottomDockClearance) private var bottomDockClearance
    @State private var mealTime: MealTime = .dinner
    @State private var appetite: Appetite = .high
    @State private var cookingTime: CookingTime = .medium
    @State private var kcalTarget: Int = 650
    @State private var proteinTarget: Int = 35
    @State private var budget: Budget = .medium
    @State private var diet: DietStyle = .omnivore
    @State private var goals: Set<MealGoal> = [.highProtein, .filling]
    @State private var selectedCuisine: Cuisine = .mixed

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        introCard
                        questionCard
                        recommendationHeader

                        ForEach(recommendations.prefix(24)) { dish in
                            dishCard(dish)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, bottomDockClearance)
                }
            }
            .navigationTitle("Ernährungsberater")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("KI-Fragen für deinen Tag", systemImage: "sparkles")
                .font(.headline)
            Text("Beantworte kurz die Fragen. Danach bekommst du passende Gerichte mit Fokus auf Eiweiß, Sättigung, Kalorienziel und Alltagstauglichkeit.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
        .surface()
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Wann willst du essen?", selection: $mealTime) {
                ForEach(MealTime.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                menuPicker("Sättigung", selection: $appetite)
                menuPicker("Zeit", selection: $cookingTime)
            }

            HStack(spacing: 10) {
                menuPicker("Budget", selection: $budget)
                menuPicker("Ernährungsart", selection: $diet)
            }

            menuPicker("Küche", selection: $selectedCuisine)

            VStack(alignment: .leading, spacing: 6) {
                Text("Kalorien pro Mahlzeit: \(kcalTarget) kcal")
                    .font(.subheadline.weight(.semibold))
                Slider(value: Binding(get: { Double(kcalTarget) }, set: { kcalTarget = Int($0) }), in: 250...1000, step: 25)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mindestens Protein: \(proteinTarget) g")
                    .font(.subheadline.weight(.semibold))
                Slider(value: Binding(get: { Double(proteinTarget) }, set: { proteinTarget = Int($0) }), in: 10...70, step: 2)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Was ist dir heute wichtig?")
                    .font(.subheadline.weight(.semibold))

                ForEach(MealGoal.allCases) { goal in
                    Button {
                        if goals.contains(goal) {
                            goals.remove(goal)
                        } else {
                            goals.insert(goal)
                        }
                    } label: {
                        HStack {
                            Image(systemName: goals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(goals.contains(goal) ? AppColor.leaf : AppColor.muted)
                            Text(goal.title)
                                .foregroundStyle(AppColor.ink)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .surface()
    }

    private var recommendationHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Empfohlene Gerichte")
                .font(.headline)
            Text("\(recommendations.count) passende Treffer aus \(allDishes.count) Gerichten")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
        }
        .padding(.horizontal, 2)
    }

    private func dishCard(_ dish: AdvisorDish) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dish.name)
                    .font(.headline)
                Spacer()
                Text(dish.cuisine.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                    .glassPill()
            }

            HStack(spacing: 10) {
                StatTile(title: "kcal", value: "\(dish.calories)", systemImage: "flame.fill", color: AppColor.peach)
                StatTile(title: "Protein", value: "\(dish.protein) g", systemImage: "bolt.heart.fill", color: AppColor.sky)
            }

            HStack(spacing: 8) {
                tag("Sättigung \(dish.satiety)/5")
                tag("\(dish.time) Min")
                tag(dish.budget.rawValue)
            }
        }
        .surface()
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.field, in: Capsule())
    }

    private func menuPicker<T: CaseIterable & Identifiable & Hashable & AdvisorOptionTitle>(
        _ title: String,
        selection: Binding<T>
    ) -> some View where T.AllCases: RandomAccessCollection {
        Menu {
            Picker(title, selection: selection) {
                ForEach(T.allCases) { option in
                    Text(option.optionTitle).tag(option)
                }
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(selection.wrappedValue.optionTitle)
                    .foregroundStyle(AppColor.muted)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppColor.muted)
            }
            .glassField()
        }
    }

    private var recommendations: [AdvisorDish] {
        allDishes
            .filter { dish in
                dish.calories <= kcalTarget + 200
                    && dish.protein >= max(8, proteinTarget - 8)
                    && dish.time <= cookingTime.maxMinutes
                    && diet.matches(dish.diet)
                    && selectedCuisine.matches(dish.cuisine)
            }
            .sorted { lhs, rhs in
                score(for: lhs) > score(for: rhs)
            }
    }

    private func score(for dish: AdvisorDish) -> Int {
        var points = 0
        points -= abs(dish.calories - kcalTarget)
        points -= abs(dish.protein - proteinTarget) * 2

        if goals.contains(.highProtein) { points += dish.protein * 5 }
        if goals.contains(.filling) { points += dish.satiety * 24 }
        if goals.contains(.lowCalorie) { points -= dish.calories / 5 }
        if goals.contains(.quick) { points -= dish.time * 3 }
        if goals.contains(.budgetFriendly), dish.budget == .low { points += 90 }

        if appetite == .high { points += dish.satiety * 18 }
        if appetite == .medium { points += dish.satiety * 10 }
        if appetite == .light { points += (6 - dish.satiety) * 12 }

        if mealTime == .breakfast, dish.tags.contains(.breakfast) { points += 75 }
        if mealTime == .lunch, dish.tags.contains(.lunch) { points += 75 }
        if mealTime == .dinner, dish.tags.contains(.dinner) { points += 75 }
        if mealTime == .snack, dish.tags.contains(.snack) { points += 75 }

        if budget == .low, dish.budget == .low { points += 80 }
        if budget == .medium, dish.budget != .high { points += 30 }
        if budget == .high { points += 10 }

        return points
    }
}

private protocol AdvisorOptionTitle {
    var optionTitle: String { get }
}

private enum MealTime: String, CaseIterable, Identifiable {
    case breakfast = "Fruehstueck"
    case lunch = "Mittag"
    case dinner = "Abend"
    case snack = "Snack"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breakfast: return "Frühstück"
        case .lunch: return "Mittag"
        case .dinner: return "Abend"
        case .snack: return "Snack"
        }
    }
}

private enum Appetite: String, CaseIterable, Identifiable, AdvisorOptionTitle {
    case light = "Leicht"
    case medium = "Mittel"
    case high = "Hoch"
    var id: String { rawValue }
    var optionTitle: String { rawValue }
}

private enum CookingTime: String, CaseIterable, Identifiable, AdvisorOptionTitle {
    case short = "Kurz"
    case medium = "Normal"
    case long = "Egal"
    var id: String { rawValue }
    var optionTitle: String { rawValue }
    var maxMinutes: Int {
        switch self {
        case .short: return 15
        case .medium: return 30
        case .long: return 120
        }
    }
}

private enum Budget: String, CaseIterable, Identifiable, AdvisorOptionTitle {
    case low = "Guenstig"
    case medium = "Normal"
    case high = "Premium"
    var id: String { rawValue }
    var optionTitle: String {
        switch self {
        case .low: return "Günstig"
        case .medium: return "Normal"
        case .high: return "Premium"
        }
    }
}

private enum DietStyle: String, CaseIterable, Identifiable, AdvisorOptionTitle {
    case omnivore = "Alles"
    case vegetarian = "Vegetarisch"
    case vegan = "Vegan"
    var id: String { rawValue }
    var optionTitle: String { rawValue }
    func matches(_ dishDiet: DishDiet) -> Bool {
        switch self {
        case .omnivore: return true
        case .vegetarian: return dishDiet == .vegetarian || dishDiet == .vegan
        case .vegan: return dishDiet == .vegan
        }
    }
}

private enum Cuisine: String, CaseIterable, Identifiable, AdvisorOptionTitle {
    case mixed = "Alles"
    case mediterranean = "Mediterran"
    case asian = "Asiatisch"
    case german = "Deutsch"
    case oriental = "Orientalisch"
    case latin = "Latein"
    var id: String { rawValue }
    var optionTitle: String { rawValue }
    var title: String { rawValue }
    func matches(_ other: Cuisine) -> Bool {
        self == .mixed || self == other
    }
}

private enum MealGoal: String, CaseIterable, Identifiable {
    case highProtein
    case filling
    case lowCalorie
    case quick
    case budgetFriendly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .highProtein: return "Eiweißreich"
        case .filling: return "Sehr sättigend"
        case .lowCalorie: return "Wenig Kalorien"
        case .quick: return "Schnell kochen"
        case .budgetFriendly: return "Preiswert"
        }
    }
}

private enum DishDiet {
    case omnivore
    case vegetarian
    case vegan
}

private enum DishTag {
    case breakfast
    case lunch
    case dinner
    case snack
}

private struct AdvisorDish: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Int
    let satiety: Int
    let time: Int
    let budget: Budget
    let diet: DishDiet
    let cuisine: Cuisine
    let tags: Set<DishTag>
}

private let allDishes: [AdvisorDish] = [
    AdvisorDish(name: "Skyr-Bowl mit Beeren", calories: 360, protein: 32, satiety: 4, time: 5, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast, .snack]),
    AdvisorDish(name: "Haferflocken mit Proteinpulver und Banane", calories: 430, protein: 35, satiety: 5, time: 8, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast]),
    AdvisorDish(name: "Rührei mit Spinat und Vollkorntoast", calories: 420, protein: 28, satiety: 4, time: 10, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.breakfast]),
    AdvisorDish(name: "Overnight Oats mit Chiasamen", calories: 390, protein: 22, satiety: 4, time: 6, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast]),
    AdvisorDish(name: "Protein-Pancakes mit Quark", calories: 470, protein: 38, satiety: 5, time: 15, budget: .medium, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast]),
    AdvisorDish(name: "Vollkornbrot mit Hüttenkäse und Tomate", calories: 340, protein: 24, satiety: 4, time: 6, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.breakfast, .snack]),
    AdvisorDish(name: "Shakshuka mit Feta", calories: 410, protein: 26, satiety: 4, time: 20, budget: .medium, diet: .vegetarian, cuisine: .oriental, tags: [.breakfast, .lunch]),
    AdvisorDish(name: "Tofu-Scramble mit Paprika", calories: 360, protein: 27, satiety: 4, time: 12, budget: .low, diet: .vegan, cuisine: .mixed, tags: [.breakfast, .lunch]),
    AdvisorDish(name: "Quark mit Apfel und Zimt", calories: 300, protein: 30, satiety: 3, time: 4, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast, .snack]),
    AdvisorDish(name: "Magerjoghurt mit Nüssen", calories: 330, protein: 21, satiety: 3, time: 4, budget: .medium, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast, .snack]),
    AdvisorDish(name: "Hähnchen-Reis-Bowl", calories: 620, protein: 48, satiety: 5, time: 25, budget: .medium, diet: .omnivore, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Lachs mit Ofengemüse", calories: 590, protein: 44, satiety: 4, time: 30, budget: .high, diet: .omnivore, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Putenstreifen mit Couscous", calories: 540, protein: 46, satiety: 4, time: 22, budget: .medium, diet: .omnivore, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Rinderhack-Chili mit Bohnen", calories: 650, protein: 50, satiety: 5, time: 30, budget: .medium, diet: .omnivore, cuisine: .latin, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Quinoa-Salat mit Kichererbsen", calories: 510, protein: 24, satiety: 4, time: 20, budget: .medium, diet: .vegan, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Linsencurry mit Spinat", calories: 560, protein: 25, satiety: 5, time: 25, budget: .low, diet: .vegan, cuisine: .oriental, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Tofu-Teriyaki mit Brokkoli", calories: 520, protein: 34, satiety: 4, time: 20, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Vollkornpasta mit Thunfisch", calories: 600, protein: 42, satiety: 5, time: 18, budget: .medium, diet: .omnivore, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Crispy Tofu Wrap", calories: 530, protein: 29, satiety: 4, time: 15, budget: .medium, diet: .vegan, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Hüttenkäse-Kartoffel-Bowl", calories: 480, protein: 32, satiety: 5, time: 18, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Süßkartoffel mit Bohnen und Joghurt", calories: 560, protein: 27, satiety: 5, time: 30, budget: .low, diet: .vegetarian, cuisine: .latin, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Reispfanne mit Ei und Gemüse", calories: 500, protein: 24, satiety: 4, time: 15, budget: .low, diet: .vegetarian, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Bulgur-Salat mit Feta", calories: 470, protein: 22, satiety: 4, time: 15, budget: .low, diet: .vegetarian, cuisine: .mediterranean, tags: [.lunch]),
    AdvisorDish(name: "Cäsar-Salat mit Hähnchen", calories: 520, protein: 45, satiety: 4, time: 17, budget: .medium, diet: .omnivore, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Taco-Bowl mit Pute", calories: 610, protein: 47, satiety: 5, time: 20, budget: .medium, diet: .omnivore, cuisine: .latin, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Soba-Nudeln mit Edamame", calories: 540, protein: 26, satiety: 4, time: 18, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Falafel-Bowl mit Tahini", calories: 640, protein: 23, satiety: 5, time: 25, budget: .medium, diet: .vegan, cuisine: .oriental, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Kartoffelsuppe mit Linsen", calories: 450, protein: 21, satiety: 5, time: 28, budget: .low, diet: .vegan, cuisine: .german, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Spinat-Lasagne light", calories: 580, protein: 31, satiety: 5, time: 35, budget: .medium, diet: .vegetarian, cuisine: .mediterranean, tags: [.dinner]),
    AdvisorDish(name: "Ofenlachs mit Kartoffeln", calories: 630, protein: 46, satiety: 5, time: 30, budget: .high, diet: .omnivore, cuisine: .german, tags: [.dinner]),
    AdvisorDish(name: "Hähnchen-Geschnetzeltes light", calories: 520, protein: 49, satiety: 4, time: 22, budget: .medium, diet: .omnivore, cuisine: .german, tags: [.dinner]),
    AdvisorDish(name: "Putenfrikadellen mit Gemüse", calories: 540, protein: 50, satiety: 5, time: 28, budget: .medium, diet: .omnivore, cuisine: .german, tags: [.dinner]),
    AdvisorDish(name: "Tofu-Erdnuss-Pfanne", calories: 610, protein: 31, satiety: 4, time: 20, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.dinner]),
    AdvisorDish(name: "Gemüseomelett mit Käse", calories: 440, protein: 34, satiety: 4, time: 12, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.dinner]),
    AdvisorDish(name: "Steak mit grünen Bohnen", calories: 590, protein: 52, satiety: 4, time: 25, budget: .high, diet: .omnivore, cuisine: .mixed, tags: [.dinner]),
    AdvisorDish(name: "Shrimp-Pfanne mit Zucchini", calories: 470, protein: 43, satiety: 4, time: 18, budget: .high, diet: .omnivore, cuisine: .mediterranean, tags: [.dinner]),
    AdvisorDish(name: "Veganes Chili sin Carne", calories: 530, protein: 28, satiety: 5, time: 30, budget: .low, diet: .vegan, cuisine: .latin, tags: [.dinner]),
    AdvisorDish(name: "Auberginenauflauf mit Mozzarella", calories: 510, protein: 27, satiety: 4, time: 28, budget: .medium, diet: .vegetarian, cuisine: .mediterranean, tags: [.dinner]),
    AdvisorDish(name: "Wokgemüse mit Seitan", calories: 500, protein: 36, satiety: 4, time: 16, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.dinner]),
    AdvisorDish(name: "Chicken Caesar Wrap", calories: 560, protein: 44, satiety: 4, time: 12, budget: .medium, diet: .omnivore, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Eiersalat-Sandwich Vollkorn", calories: 420, protein: 23, satiety: 3, time: 10, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.lunch]),
    AdvisorDish(name: "Proteinshake mit Haferdrink", calories: 260, protein: 34, satiety: 2, time: 3, budget: .medium, diet: .vegan, cuisine: .mixed, tags: [.snack]),
    AdvisorDish(name: "Edamame mit Meersalz", calories: 240, protein: 20, satiety: 3, time: 5, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.snack]),
    AdvisorDish(name: "Apfel mit Erdnussmus", calories: 280, protein: 8, satiety: 3, time: 2, budget: .low, diet: .vegan, cuisine: .mixed, tags: [.snack]),
    AdvisorDish(name: "Reiswaffeln mit Hüttenkäse", calories: 230, protein: 17, satiety: 2, time: 3, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.snack]),
    AdvisorDish(name: "Proteinriegel und Kaffee", calories: 250, protein: 20, satiety: 2, time: 1, budget: .medium, diet: .vegetarian, cuisine: .mixed, tags: [.snack]),
    AdvisorDish(name: "Gekochte Eier mit Gurke", calories: 210, protein: 18, satiety: 3, time: 6, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.snack]),
    AdvisorDish(name: "Hummus mit Gemüsesticks", calories: 300, protein: 11, satiety: 3, time: 6, budget: .low, diet: .vegan, cuisine: .oriental, tags: [.snack]),
    AdvisorDish(name: "Miso-Suppe mit Tofu", calories: 220, protein: 16, satiety: 3, time: 10, budget: .low, diet: .vegan, cuisine: .asian, tags: [.snack, .dinner]),
    AdvisorDish(name: "Caprese mit Vollkornbrot", calories: 390, protein: 20, satiety: 3, time: 8, budget: .medium, diet: .vegetarian, cuisine: .mediterranean, tags: [.lunch, .snack]),
    AdvisorDish(name: "Harzer Käse mit Radieschen", calories: 200, protein: 33, satiety: 3, time: 4, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.snack]),
    AdvisorDish(name: "Thunfischsalat mit Bohnen", calories: 460, protein: 43, satiety: 4, time: 11, budget: .medium, diet: .omnivore, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Poke Bowl mit Lachs", calories: 610, protein: 39, satiety: 4, time: 20, budget: .high, diet: .omnivore, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Poke Bowl mit Tofu", calories: 560, protein: 29, satiety: 4, time: 20, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Kartoffel-Quark", calories: 490, protein: 31, satiety: 5, time: 22, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Veganes Protein-Chili", calories: 550, protein: 35, satiety: 5, time: 30, budget: .low, diet: .vegan, cuisine: .latin, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Hähnchen-Curry Kokos light", calories: 570, protein: 45, satiety: 4, time: 24, budget: .medium, diet: .omnivore, cuisine: .asian, tags: [.dinner]),
    AdvisorDish(name: "Seelachsfilet mit Erbsenpüree", calories: 510, protein: 41, satiety: 4, time: 25, budget: .medium, diet: .omnivore, cuisine: .german, tags: [.dinner]),
    AdvisorDish(name: "Linsenbolognese mit Zucchininudeln", calories: 430, protein: 23, satiety: 4, time: 20, budget: .low, diet: .vegan, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Mozzarella-Omelett", calories: 410, protein: 31, satiety: 4, time: 10, budget: .medium, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast, .dinner]),
    AdvisorDish(name: "Putenbrust auf Salat", calories: 390, protein: 46, satiety: 4, time: 12, budget: .medium, diet: .omnivore, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Bohnen-Mais-Salat", calories: 420, protein: 18, satiety: 4, time: 9, budget: .low, diet: .vegan, cuisine: .latin, tags: [.lunch]),
    AdvisorDish(name: "Couscous mit Garnelen", calories: 530, protein: 39, satiety: 4, time: 16, budget: .high, diet: .omnivore, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Vegane Burrito-Bowl", calories: 620, protein: 27, satiety: 5, time: 22, budget: .medium, diet: .vegan, cuisine: .latin, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Baked Oats mit Protein", calories: 460, protein: 33, satiety: 4, time: 18, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast]),
    AdvisorDish(name: "Quarkbrötchen mit Lachs", calories: 440, protein: 35, satiety: 4, time: 7, budget: .high, diet: .omnivore, cuisine: .german, tags: [.breakfast, .lunch]),
    AdvisorDish(name: "Schneller Couscous-Salat", calories: 450, protein: 16, satiety: 3, time: 10, budget: .low, diet: .vegan, cuisine: .mediterranean, tags: [.lunch]),
    AdvisorDish(name: "Gemüsepfanne mit Feta", calories: 470, protein: 24, satiety: 4, time: 15, budget: .low, diet: .vegetarian, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Hähnchenwrap mit Joghurtsoße", calories: 520, protein: 41, satiety: 4, time: 14, budget: .medium, diet: .omnivore, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Kichererbsenpfanne mit Spiegelei", calories: 560, protein: 30, satiety: 5, time: 17, budget: .low, diet: .vegetarian, cuisine: .oriental, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Reis mit Linsen und Joghurt", calories: 590, protein: 28, satiety: 5, time: 20, budget: .low, diet: .vegetarian, cuisine: .oriental, tags: [.dinner]),
    AdvisorDish(name: "Fisch-Tacos", calories: 540, protein: 38, satiety: 4, time: 20, budget: .high, diet: .omnivore, cuisine: .latin, tags: [.dinner]),
    AdvisorDish(name: "Sushi-Bowl mit Thunfisch", calories: 600, protein: 42, satiety: 4, time: 18, budget: .high, diet: .omnivore, cuisine: .asian, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Brokkoli-Cheddar-Suppe light", calories: 390, protein: 19, satiety: 4, time: 20, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Schneller Nudelsalat mit Ei", calories: 510, protein: 25, satiety: 4, time: 14, budget: .low, diet: .vegetarian, cuisine: .german, tags: [.lunch]),
    AdvisorDish(name: "Tuna-Melt Vollkorntoast", calories: 470, protein: 36, satiety: 4, time: 9, budget: .medium, diet: .omnivore, cuisine: .mixed, tags: [.lunch, .snack]),
    AdvisorDish(name: "Veganer Protein-Smoothie", calories: 320, protein: 31, satiety: 3, time: 4, budget: .medium, diet: .vegan, cuisine: .mixed, tags: [.breakfast, .snack]),
    AdvisorDish(name: "Tomaten-Mozzarella-Pasta light", calories: 560, protein: 24, satiety: 4, time: 19, budget: .medium, diet: .vegetarian, cuisine: .mediterranean, tags: [.dinner]),
    AdvisorDish(name: "Rinderstreifen mit Paprika", calories: 580, protein: 47, satiety: 4, time: 21, budget: .high, diet: .omnivore, cuisine: .asian, tags: [.dinner]),
    AdvisorDish(name: "Lauwarmer Linsensalat", calories: 490, protein: 23, satiety: 4, time: 16, budget: .low, diet: .vegan, cuisine: .mediterranean, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Putensteak mit Ofenkürbis", calories: 540, protein: 45, satiety: 5, time: 27, budget: .medium, diet: .omnivore, cuisine: .german, tags: [.dinner]),
    AdvisorDish(name: "Spiegelei-Bagel mit Avocado", calories: 500, protein: 24, satiety: 4, time: 10, budget: .medium, diet: .vegetarian, cuisine: .mixed, tags: [.breakfast, .lunch]),
    AdvisorDish(name: "Quinoa-Power-Bowl", calories: 580, protein: 26, satiety: 5, time: 23, budget: .medium, diet: .vegan, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Hähnchensuppe mit Gemüse", calories: 420, protein: 38, satiety: 4, time: 25, budget: .low, diet: .omnivore, cuisine: .german, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Wrap mit Räucherlachs und Frischkäse", calories: 480, protein: 32, satiety: 3, time: 8, budget: .high, diet: .omnivore, cuisine: .mixed, tags: [.lunch, .snack]),
    AdvisorDish(name: "Tofu-Satay mit Reis", calories: 620, protein: 33, satiety: 4, time: 26, budget: .medium, diet: .vegan, cuisine: .asian, tags: [.dinner]),
    AdvisorDish(name: "Käse-Lauch-Suppe light", calories: 430, protein: 24, satiety: 4, time: 20, budget: .low, diet: .omnivore, cuisine: .german, tags: [.dinner]),
    AdvisorDish(name: "Schnelle Pizza-Tortilla", calories: 390, protein: 22, satiety: 3, time: 12, budget: .low, diet: .vegetarian, cuisine: .mixed, tags: [.lunch, .dinner]),
    AdvisorDish(name: "Bohneneintopf mit Tofu", calories: 540, protein: 32, satiety: 5, time: 28, budget: .low, diet: .vegan, cuisine: .german, tags: [.dinner])
]

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
