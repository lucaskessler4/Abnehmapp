import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TodayView: View {
    private enum FocusedField: Hashable {
        case foodName
        case calories
        case protein
        case portion
        case note
    }

    @EnvironmentObject private var store: CalorieStore
    @State private var foodName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var portionSize = "1.0"
    @State private var shouldSaveMeal = false
    @State private var noteText = ""
    @State private var editingNote: DailyNote?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var sectionOrder: [DashboardSection] = DashboardSection.allCases
    @State private var draggedSection: DashboardSection?
    @State private var hasLoadedSectionOrder = false
    @AppStorage("todaySectionOrder") private var sectionOrderStorage = ""
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        ForEach(sectionOrder) { section in
                            dashboardSection(section)
                                .onDrag {
                                    draggedSection = section
                                    return NSItemProvider(object: NSString(string: section.rawValue))
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: DashboardSectionDropDelegate(
                                        target: section,
                                        sections: $sectionOrder,
                                        draggedSection: $draggedSection
                                    )
                                )
                        }
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
                .onAppear {
                    guard !hasLoadedSectionOrder else { return }
                    sectionOrder = DashboardSection.order(from: sectionOrderStorage)
                    hasLoadedSectionOrder = true
                }
                .onChange(of: sectionOrder) { _, newValue in
                    sectionOrderStorage = DashboardSection.storageString(for: newValue)
                }
            }
            .navigationTitle("Heute")
            .sheet(item: $editingNote) { note in
                NoteEditorView(note: note)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
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
        }
    }

    private func dashboardSection(_ section: DashboardSection) -> some View {
        Group {
            switch section {
            case .progress:
                progressCard
            case .quickAdd:
                quickAddCard
            case .notes:
                notesSection
            case .savedMeals:
                savedMealsSection
            case .entries:
                entriesSection
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Kalorien Kompass")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColor.ink)
                    Text("Ein klarer Blick auf deinen Tag.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()

                Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                    .glassPill()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.todaysCalories)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.ink)
                    Text("von \(store.adjustedTargetCalories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(store.remainingCalories >= 0 ? "Noch übrig" : "Drüber")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                    Text("\(abs(store.remainingCalories)) kcal")
                        .font(.headline)
                        .foregroundStyle(store.remainingCalories >= 0 ? AppColor.leaf : .red)
                }
                .glassPill()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.thinMaterial)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    store.remainingCalories >= 0 ? AppColor.leaf : .red,
                                    AppColor.sky.opacity(0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * store.calorieProgress))
                }
            }
            .frame(height: 14)
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }

            HStack(spacing: 10) {
                StatTile(title: "Protein", value: "\(store.todaysProtein) g", systemImage: "bolt.heart.fill", color: AppColor.sky)
                StatTile(title: "Aktivität", value: "+\(store.todaysActivityCalories) kcal", systemImage: "figure.run", color: AppColor.peach)
            }

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(AppColor.peach)
                Text("Streak: \(store.foodTrackingStreak) Tage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }

            if store.todaysActivityCalories > 0 {
                Text("Basisziel \(store.profile.targetCalories) kcal + Tracking \(store.todaysActivityCalories) kcal")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
        }
        .surface()
    }

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Mahlzeit hinzufügen", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            TextField("Name, z. B. Frühstück", text: $foodName)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .foodName)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .calories
                }
                .glassField()

            HStack(spacing: 10) {
                TextField("kcal", text: $calories)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .calories)
                    .glassField()

                TextField("Protein g", text: $protein)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .protein)
                    .glassField()
            }

            TextField("Portion (z. B. 1.0, 0.5, 1.5)", text: $portionSize)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .portion)
                .glassField()

            if let adjustedCalories, isValidPortion {
                Text("Portionsbereinigt: \(adjustedCalories) kcal • \(adjustedProtein) g Protein")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
            } else {
                Text("Bitte eine Portionsgröße größer als 0 eingeben.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                MealImageThumbnail(imageData: selectedImageData)

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(selectedImageData == nil ? "Bild hinzufügen" : "Bild ändern", systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(AppColor.leaf)

                    if selectedImageData != nil {
                        Button {
                            selectedPhoto = nil
                            selectedImageData = nil
                        } label: {
                            Label("Bild entfernen", systemImage: "xmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColor.muted)
                    }
                }
            }

            Toggle("Mahlzeit für später speichern", isOn: $shouldSaveMeal)
                .tint(AppColor.leaf)

            Button {
                addFood()
            } label: {
                Label("Eintragen", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.leaf)
            .disabled(adjustedCalories == nil || !isValidPortion)
            .controlSize(.large)
        }
        .surface()
        .onChange(of: selectedPhoto) { _, newPhoto in
            loadSelectedPhoto(newPhoto)
        }
    }

    private var savedMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gespeicherte Mahlzeiten")
                .font(.title3.bold())
                .foregroundStyle(AppColor.ink)

            if store.savedMeals.isEmpty {
                Text("Speichere häufige Mahlzeiten, dann kannst du sie später mit einem Tipp wieder eintragen.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surface()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.savedMeals) { meal in
                            savedMealCard(meal)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Notizen", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            TextEditor(text: $noteText)
                .frame(minHeight: 88)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .note)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(.thinMaterial)
                }
                .overlay(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("Gedanken, Hunger, Planung ...")
                            .font(.body)
                            .foregroundStyle(AppColor.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                }

            Button {
                addNote()
            } label: {
                Label("Notiz speichern", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.leaf)
            .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .controlSize(.large)

            if !store.todaysNotes.isEmpty {
                VStack(spacing: 10) {
                    ForEach(store.todaysNotes) { note in
                        noteRow(note)
                    }
                }
            }
        }
        .surface()
    }

    private func noteRow(_ note: DailyNote) -> some View {
        Button {
            editingNote = note
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.headline)
                    .foregroundStyle(AppColor.leaf)
                    .frame(width: 36, height: 36)
                    .background(AppColor.mint.opacity(0.85), in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(note.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer(minLength: 0)

                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notiz öffnen und bearbeiten")
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
        }
    }

    private func savedMealCard(_ meal: SavedMeal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MealImageThumbnail(imageData: meal.imageData, size: 70)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(2)
                    .frame(height: 42, alignment: .topLeading)

                Text("\(meal.calories) kcal • \(meal.protein) g Protein")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 12) {
                Button {
                    store.addEntry(from: meal)
                } label: {
                    Label("Nutzen", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.leaf)

                Button {
                    store.deleteSavedMeal(meal)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(meal.name) löschen")
            }
        }
        .padding(14)
        .frame(width: 190, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tagesliste")
                .font(.title3.bold())
                .foregroundStyle(AppColor.ink)

            if store.todaysEntries.isEmpty {
                ContentUnavailableView(
                    "Noch nichts eingetragen",
                    systemImage: "fork.knife.circle",
                    description: Text("Füge deine erste Mahlzeit hinzu. Kleine ehrliche Einträge schlagen perfekte Pläne.")
                )
                .surface()
            } else {
                VStack(spacing: 10) {
                    ForEach(store.todaysEntries) { entry in
                        HStack {
                            MealImageThumbnail(imageData: entry.imageData)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name)
                                    .font(.headline)
                                    .foregroundStyle(AppColor.ink)
                                Text("\(entry.protein) g Protein")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.muted)
                            }

                            Spacer()

                            Text("\(entry.calories) kcal")
                                .font(.headline)
                                .foregroundStyle(AppColor.ink)

                            Button {
                                store.deleteEntry(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColor.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(entry.name) löschen")
                        }
                        .padding(14)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                        }
                    }
                }
            }
        }
    }

    private func addFood() {
        guard
            let calorieValue = adjustedCalories,
            calorieValue >= 0
        else {
            return
        }
        let proteinValue = adjustedProtein
        focusedField = nil

        store.addEntry(
            name: foodName,
            calories: calorieValue,
            protein: proteinValue,
            imageData: selectedImageData
        )

        if shouldSaveMeal {
            store.saveMeal(
                name: foodName,
                calories: calorieValue,
                protein: proteinValue,
                imageData: selectedImageData
            )
        }

        foodName = ""
        calories = ""
        protein = ""
        portionSize = "1.0"
        shouldSaveMeal = false
        selectedPhoto = nil
        selectedImageData = nil
    }

    private var adjustedCalories: Int? {
        guard let baseCalories = Int(calories) else { return nil }
        let portion = portionValue
        return max(0, Int((Double(baseCalories) * portion).rounded()))
    }

    private var adjustedProtein: Int {
        let baseProtein = Int(protein) ?? 0
        let portion = portionValue
        return max(0, Int((Double(baseProtein) * portion).rounded()))
    }

    private var isValidPortion: Bool {
        portionValue > 0
    }

    private var portionValue: Double {
        let normalized = portionSize
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalized) ?? -1
    }

    private func addNote() {
        store.addNote(text: noteText)
        noteText = ""
        focusedField = nil
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedImageData = compressedImageData(from: data)
                }
            }
        }
    }

    private func compressedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 900
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longestSide)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.72)
    }
}

private enum DashboardSection: String, CaseIterable, Identifiable {
    case progress
    case quickAdd
    case notes
    case savedMeals
    case entries

    var id: String { rawValue }

    static func order(from storage: String) -> [DashboardSection] {
        let storedValues = storage
            .split(separator: ",")
            .compactMap { DashboardSection(rawValue: String($0)) }

        guard !storedValues.isEmpty else {
            return allCases
        }

        let missing = allCases.filter { !storedValues.contains($0) }
        return storedValues + missing
    }

    static func storageString(for sections: [DashboardSection]) -> String {
        sections.map(\.rawValue).joined(separator: ",")
    }
}

private struct DashboardSectionDropDelegate: DropDelegate {
    let target: DashboardSection
    @Binding var sections: [DashboardSection]
    @Binding var draggedSection: DashboardSection?

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
    TodayView()
        .environmentObject(CalorieStore.preview)
}

private struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CalorieStore
    @State private var editedText: String

    let note: DailyNote

    init(note: DailyNote) {
        self.note = note
        _editedText = State(initialValue: note.text)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: 16) {
                    Text(note.date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.muted)

                    TextEditor(text: $editedText)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .fill(.thinMaterial)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                        }

                    Spacer(minLength: 0)

                    Button(role: .destructive) {
                        store.deleteNote(note)
                        dismiss()
                    } label: {
                        Label("Notiz löschen", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(18)
            }
            .navigationTitle("Notiz bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        store.updateNote(note, text: editedText)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
