import SwiftUI
import UniformTypeIdentifiers

struct NeedsCalculatorView: View {
    private enum FocusedField: Hashable {
        case weight
        case targetWeight
        case calorieDeficit
    }

    @EnvironmentObject private var store: CalorieStore
    @Environment(\.bottomDockClearance) private var bottomDockClearance
    @State private var weightInput = ""
    @State private var targetWeightInput = ""
    @State private var calorieDeficitInput = ""
    @State private var sectionOrder: [NeedsSection] = NeedsSection.allCases
    @State private var draggedSection: NeedsSection?
    @State private var hasLoadedSectionOrder = false
    @AppStorage("needsSectionOrder") private var sectionOrderStorage = ""
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headline
                        ForEach(sectionOrder) { section in
                            needsSection(section)
                                .onDrag {
                                    draggedSection = section
                                    return NSItemProvider(object: NSString(string: section.rawValue))
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: NeedsSectionDropDelegate(
                                        target: section,
                                        sections: $sectionOrder,
                                        draggedSection: $draggedSection
                                    )
                                )
                        }
                    }
                    .padding(18)
                    .padding(.bottom, bottomDockClearance)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Bedarf")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") {
                        focusedField = nil
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button("Fertig") {
                        focusedField = nil
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                    }
                    .opacity(focusedField == nil ? 0 : 1)
                    .disabled(focusedField == nil)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
            .onAppear {
                syncInputsFromProfile()
                guard !hasLoadedSectionOrder else { return }
                sectionOrder = NeedsSection.order(from: sectionOrderStorage)
                hasLoadedSectionOrder = true
            }
            .onChange(of: sectionOrder) { _, newValue in
                sectionOrderStorage = NeedsSection.storageString(for: newValue)
            }
            .onChange(of: store.profile.weightKilograms) { _, value in
                guard focusedField != .weight else { return }
                let formatted = formattedWeight(value)
                if weightInput != formatted {
                    weightInput = formatted
                }
            }
            .onChange(of: store.profile.targetWeightKilograms) { _, value in
                guard focusedField != .targetWeight else { return }
                let formatted = formattedWeight(value)
                if targetWeightInput != formatted {
                    targetWeightInput = formatted
                }
            }
            .onChange(of: store.profile.desiredCalorieDeficit) { _, value in
                guard focusedField != .calorieDeficit else { return }
                calorieDeficitInput = "\(value)"
            }
            .onChange(of: focusedField) { oldValue, newValue in
                if oldValue == .weight, newValue != .weight {
                    commitWeightInput(isTarget: false)
                }
                if oldValue == .targetWeight, newValue != .targetWeight {
                    commitWeightInput(isTarget: true)
                }
                if oldValue == .calorieDeficit, newValue != .calorieDeficit {
                    commitCalorieDeficitInput()
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dein Tagesziel")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.ink)
            Text("Lege dein Tagesziel über dein gewünschtes Kaloriendefizit fest.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
    }

    private func needsSection(_ section: NeedsSection) -> some View {
        Group {
            switch section {
            case .result:
                resultCard
            case .basics:
                basicsCard
            case .weights:
                weightsCard
            case .calorieDeficit:
                calorieDeficitCard
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dein Tagesziel")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.muted)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.profile.targetCalories) kcal")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.ink)
                    Text("Kalorien pro Tag")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColor.leaf.opacity(0.18), AppColor.sky.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Grundumsatz: \(store.profile.basalMetabolicRate) kcal", systemImage: "flame.fill")
                Label("Kaloriendefizit: \(store.profile.desiredCalorieDeficit) kcal", systemImage: "minus.circle.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.leaf)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Bis zum Zielgewicht fehlen etwa \(store.profile.remainingKilograms, specifier: "%.1f") kg.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)

            if let estimateText = targetDurationEstimateText {
                Text(estimateText)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
            }

            Text("Tagesziel = Grundumsatz minus Kaloriendefizit.")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
        }
        .surface()
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Geschlecht", selection: $store.profile.sex) {
                ForEach(Sex.allCases) { sex in
                    Text(sex.rawValue).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 10) {
                Stepper("Alter: \(store.profile.age)", value: $store.profile.age, in: 14...90)
                Divider().opacity(0.45)
                Stepper("Größe: \(store.profile.heightCentimeters) cm", value: $store.profile.heightCentimeters, in: 130...220)
            }
            .glassField()
        }
        .font(.body)
        .surface()
    }

    private var weightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aktuelles Gewicht: \(store.profile.weightKilograms, specifier: "%.1f") kg")
                    .font(.subheadline.weight(.semibold))
                TextField("z. B. 82,5", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .glassField()
            }
            .glassField()

            VStack(alignment: .leading, spacing: 8) {
                Text("Zielgewicht: \(store.profile.targetWeightKilograms, specifier: "%.1f") kg")
                    .font(.subheadline.weight(.semibold))
                TextField("z. B. 75,0", text: $targetWeightInput)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .targetWeight)
                    .glassField()
            }
            .glassField()
        }
        .font(.body)
        .surface()
    }

    private var calorieDeficitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kaloriendefizit")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            TextField("z. B. 500", text: $calorieDeficitInput)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .calorieDeficit)
                .glassField()

            Button {
                commitCalorieDeficitInput()
                focusedField = nil
            } label: {
                Label("Speichern", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.leaf)
            .controlSize(.large)

            Text("Gib ein, um wie viele kcal du täglich unter deinem Grundumsatz liegen möchtest.")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
        }
        .font(.body)
        .surface()
    }

    private func syncInputsFromProfile() {
        weightInput = formattedWeight(store.profile.weightKilograms)
        targetWeightInput = formattedWeight(store.profile.targetWeightKilograms)
        calorieDeficitInput = "\(store.profile.desiredCalorieDeficit)"
    }

    private func formattedWeight(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private func commitWeightInput(isTarget: Bool) {
        let text = isTarget ? targetWeightInput : weightInput
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            if isTarget {
                targetWeightInput = formattedWeight(store.profile.targetWeightKilograms)
            } else {
                weightInput = formattedWeight(store.profile.weightKilograms)
            }
            return
        }

        let clampedValue = min(max(value, 40), 180)
        let preciseValue = (clampedValue * 10).rounded() / 10

        if isTarget {
            store.profile.targetWeightKilograms = preciseValue
            targetWeightInput = formattedWeight(preciseValue)
        } else {
            store.profile.weightKilograms = preciseValue
            weightInput = formattedWeight(preciseValue)
        }
    }

    private func commitCalorieDeficitInput() {
        let normalized = calorieDeficitInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(normalized) else {
            calorieDeficitInput = "\(store.profile.desiredCalorieDeficit)"
            return
        }

        let clampedValue = min(max(value, 0), 2000)
        store.profile.desiredCalorieDeficit = clampedValue
        calorieDeficitInput = "\(clampedValue)"
    }

    private var targetDurationEstimateText: String? {
        let remaining = store.profile.remainingKilograms
        guard remaining > 0 else {
            return "Zielgewicht erreicht."
        }

        let dailyDeficit = store.profile.desiredCalorieDeficit
        guard dailyDeficit > 0 else {
            return "Mit einem Defizit von 0 kcal gibt es keine Abnahme-Zeitschätzung."
        }

        let weeklyDeficit = Double(dailyDeficit * 7)
        let weeks = (remaining * 7_700) / weeklyDeficit
        let roundedWeeks = max(1, Int(weeks.rounded()))
        let months = Double(roundedWeeks) / 4.345
        let formattedMonths = String(format: "%.1f", months)

        if months >= 2 {
            return "Bis zum Ziel dauert es voraussichtlich etwa \(roundedWeeks) Wochen (\(formattedMonths) Monate)."
        }

        return "Bis zum Ziel dauert es voraussichtlich etwa \(roundedWeeks) Wochen."
    }
}

private enum NeedsSection: String, CaseIterable, Identifiable {
    case result
    case basics
    case weights
    case calorieDeficit

    var id: String { rawValue }

    static func order(from storage: String) -> [NeedsSection] {
        let storedValues = storage
            .split(separator: ",")
            .compactMap { NeedsSection(rawValue: String($0)) }

        guard !storedValues.isEmpty else {
            return allCases
        }

        let missing = allCases.filter { !storedValues.contains($0) }
        return storedValues + missing
    }

    static func storageString(for sections: [NeedsSection]) -> String {
        sections.map(\.rawValue).joined(separator: ",")
    }
}

private struct NeedsSectionDropDelegate: DropDelegate {
    let target: NeedsSection
    @Binding var sections: [NeedsSection]
    @Binding var draggedSection: NeedsSection?

    func dropEntered(info: DropInfo) {
        guard
            let draggedSection,
            draggedSection != target,
            let fromIndex = sections.firstIndex(of: draggedSection),
            let toIndex = sections.firstIndex(of: target)
        else {
            return
        }

        withAnimation(.snappy) {
            sections.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        return true
    }
}

#Preview {
    NeedsCalculatorView()
        .environmentObject(CalorieStore.preview)
}
