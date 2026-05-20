import PhotosUI
import SwiftUI
import UIKit

struct TodayView: View {
    private enum FocusedField: Hashable {
        case foodName
        case calories
        case protein
    }

    @EnvironmentObject private var store: CalorieStore
    @State private var foodName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var shouldSaveMeal = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        progressCard
                        quickAddCard
                        savedMealsSection
                        entriesSection
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
            }
            .navigationTitle("Heute")
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
                    Text("von \(store.profile.targetCalories) kcal")
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
                StatTile(title: "Ziel", value: store.profile.goal.rawValue, systemImage: "flag.checkered", color: AppColor.peach)
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
            .disabled(Int(calories) == nil)
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
        guard let calorieValue = Int(calories) else { return }
        let proteinValue = Int(protein) ?? 0
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
        shouldSaveMeal = false
        selectedPhoto = nil
        selectedImageData = nil
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

#Preview {
    TodayView()
        .environmentObject(CalorieStore.preview)
}
