import PhotosUI
import SwiftUI
import UIKit
import Vision
import ImageIO

struct FoodScanView: View {
    @EnvironmentObject private var store: CalorieStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showCamera = false
    @State private var showCameraUnavailableAlert = false
    @State private var isAnalyzing = false
    @State private var scanResult: FoodScanResult?
    @State private var showSaveHint = false
    @State private var showSaveConfirmation = false
    @State private var hasSavedCurrentResult = false
    @State private var customName = ""
    @State private var lastAppliedDescription = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Foto-Scan")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(AppColor.ink)

                        imageCard
                        actionCard
                        resultCard
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Scan")
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $pickedImage)
            }
            .alert("Kamera nicht verfügbar", isPresented: $showCameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Auf diesem Gerät ist keine Kamera verfügbar. Bitte nutze die Galerie.")
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                loadSelectedPhoto(newPhoto)
            }
            .onChange(of: pickedImage) { _, newImage in
                guard let newImage else { return }
                analyze(image: newImage)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
            }
            .alert("In Tagesliste speichern?", isPresented: $showSaveConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Speichern") {
                    if let result = scanResult {
                        saveScanResult(result)
                    }
                }
            } message: {
                Text("Die Mahlzeit wird einmal in Heute gespeichert.")
            }
        }
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let pickedImage {
                    Image(uiImage: pickedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [AppColor.sky.opacity(0.6), AppColor.mint.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "camera.macro")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(AppColor.leaf)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }

            if isAnalyzing {
                ProgressView("Essen wird erkannt ...")
                    .tint(AppColor.leaf)
                    .foregroundStyle(AppColor.muted)
            } else if let scanResult {
                Text("Erkannt: \(scanResult.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
            } else {
                Text("Foto machen oder aus der Galerie wählen.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
            }
        }
        .surface()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    showCameraUnavailableAlert = true
                }
            } label: {
                Label("Mit Kamera scannen", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.leaf)
            .controlSize(.large)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Bild aus Galerie", systemImage: "photo.fill.on.rectangle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppColor.leaf)
            .controlSize(.large)
        }
        .surface()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Kalorien-Vorschlag", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            if let scanResult {
                TextField("Beschreibung der Mahlzeit", text: $customName)
                    .textInputAutocapitalization(.never)
                    .glassField()

                Button {
                    applyDescriptionUpdate()
                } label: {
                    Label("Beschreibung speichern & Kalorien neu berechnen", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.leaf)
                .disabled(!canApplyDescriptionChanges)

                StatTile(
                    title: "Geschätzt",
                    value: "\(scanResult.estimatedCalories) kcal",
                    systemImage: "flame.fill",
                    color: AppColor.peach
                )

                Text("KI-Konfidenz: \(Int(scanResult.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)

                if hasPendingDescriptionChanges {
                    Text("Änderung noch nicht übernommen. Tippe auf den Button, um Kalorien zu aktualisieren.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }

                Button {
                    showSaveConfirmation = true
                } label: {
                    Label("In Tagesliste speichern", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.leaf)
                .controlSize(.large)
                .disabled(hasSavedCurrentResult || hasPendingDescriptionChanges)

                if showSaveHint {
                    Text("Gespeichert in Heute. Du kannst nicht doppelt speichern, bis du neu scannst oder die Beschreibung neu berechnest.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.leaf)
                }
            } else {
                Text("Nach dem Scan siehst du hier den automatisch geschätzten Kalorienwert.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
            }
        }
        .surface()
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                pickedImage = image
            }
        }
    }

    private func analyze(image: UIImage) {
        isAnalyzing = true
        showSaveHint = false
        scanResult = nil

        Task {
            let result = await FoodVisionAnalyzer.analyze(image: image)
            await MainActor.run {
                isAnalyzing = false
                scanResult = result
                customName = result.title
                lastAppliedDescription = result.title
                hasSavedCurrentResult = false
            }
        }
    }

    private var hasPendingDescriptionChanges: Bool {
        customName.trimmingCharacters(in: .whitespacesAndNewlines) != lastAppliedDescription
    }

    private var canApplyDescriptionChanges: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasPendingDescriptionChanges
    }

    private func applyDescriptionUpdate() {
        guard !isAnalyzing,
              var currentResult = scanResult else { return }
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let refined = FoodVisionAnalyzer.refinedEstimate(
            for: trimmed,
            baseConfidence: currentResult.confidence
        )

        currentResult.title = refined.title
        currentResult.estimatedCalories = refined.estimatedCalories
        currentResult.estimatedProtein = refined.estimatedProtein
        currentResult.confidence = refined.confidence
        scanResult = currentResult
        lastAppliedDescription = trimmed
        hasSavedCurrentResult = false
        showSaveHint = false
    }

    private func saveScanResult(_ result: FoodScanResult) {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? result.title
            : customName
        store.addEntry(
            name: name,
            calories: result.estimatedCalories,
            protein: result.estimatedProtein,
            imageData: compressedImageData(from: pickedImage)
        )
        showSaveHint = true
        hasSavedCurrentResult = true
    }

    private func compressedImageData(from image: UIImage?) -> Data? {
        guard let image else { return nil }
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

private struct FoodScanResult {
    var title: String
    var estimatedCalories: Int
    var estimatedProtein: Int
    var confidence: Double
}

private enum FoodVisionAnalyzer {
    private static let fallback = FoodScanResult(
        title: "Mahlzeit",
        estimatedCalories: 420,
        estimatedProtein: 18,
        confidence: 0.2
    )

    private enum Category: Int, CaseIterable {
        case main = 0
        case side = 1
        case sauce = 2
        case topping = 3
        case dessert = 4
        case drink = 5
    }

    private struct FoodItem {
        let category: Category
        let label: String
        let calories: Int
        let protein: Int
        let keywords: [String]
    }

    private static let catalog: [FoodItem] = [
        FoodItem(category: .main, label: "Burger", calories: 520, protein: 25, keywords: ["burger", "cheeseburger", "hamburger"]),
        FoodItem(category: .main, label: "Pizza", calories: 760, protein: 28, keywords: ["pizza", "margherita", "pepperoni"]),
        FoodItem(category: .main, label: "Nudeln", calories: 460, protein: 14, keywords: ["nudel", "nudeln", "pasta", "spaghetti", "penne"]),
        FoodItem(category: .main, label: "Reisgericht", calories: 490, protein: 12, keywords: ["reis", "rice", "risotto", "paella"]),
        FoodItem(category: .main, label: "Sushi", calories: 430, protein: 20, keywords: ["sushi", "maki", "nigiri"]),
        FoodItem(category: .main, label: "Döner", calories: 690, protein: 30, keywords: ["döner", "doner", "kebab", "shawarma"]),
        FoodItem(category: .main, label: "Wrap", calories: 520, protein: 22, keywords: ["wrap", "burrito", "tortilla"]),
        FoodItem(category: .main, label: "Sandwich", calories: 460, protein: 20, keywords: ["sandwich", "sub", "baguette"]),
        FoodItem(category: .main, label: "Steak", calories: 520, protein: 44, keywords: ["steak", "beef", "rumpsteak"]),
        FoodItem(category: .main, label: "Hähnchen", calories: 390, protein: 42, keywords: ["hähnchen", "chicken", "grillhuhn", "chicken breast"]),
        FoodItem(category: .main, label: "Fischgericht", calories: 420, protein: 34, keywords: ["fisch", "fish", "salmon", "lachs", "tuna"]),
        FoodItem(category: .main, label: "Suppe", calories: 290, protein: 10, keywords: ["suppe", "soup", "ramen", "pho"]),
        FoodItem(category: .main, label: "Salat", calories: 240, protein: 9, keywords: ["salat", "salad", "greens", "cesar"]),
        FoodItem(category: .main, label: "Curry", calories: 560, protein: 24, keywords: ["curry", "masala", "korma"]),
        FoodItem(category: .main, label: "Lasagne", calories: 620, protein: 28, keywords: ["lasagne", "lasagna"]),
        FoodItem(category: .main, label: "Omelett", calories: 340, protein: 24, keywords: ["omelett", "omelette", "egg", "ei"]),
        FoodItem(category: .main, label: "Pfannkuchen", calories: 380, protein: 11, keywords: ["pfannkuchen", "pancake", "crepe"]),
        FoodItem(category: .main, label: "Falafel", calories: 510, protein: 17, keywords: ["falafel"]),
        FoodItem(category: .main, label: "Kartoffelgericht", calories: 430, protein: 10, keywords: ["kartoffel", "potato", "gratin", "baked potato"]),
        FoodItem(category: .main, label: "Frühstücksschale", calories: 420, protein: 18, keywords: ["müsli", "oatmeal", "porridge", "joghurt", "skyr"]),

        FoodItem(category: .side, label: "Pommes", calories: 340, protein: 5, keywords: ["pommes", "fries", "chips"]),
        FoodItem(category: .side, label: "Bratkartoffeln", calories: 290, protein: 6, keywords: ["bratkartoffel", "home fries"]),
        FoodItem(category: .side, label: "Reis-Beilage", calories: 210, protein: 4, keywords: ["reisbeilage", "rice side"]),
        FoodItem(category: .side, label: "Gemüse-Beilage", calories: 120, protein: 4, keywords: ["gemüse", "vegetable side", "brokkoli", "broccoli"]),
        FoodItem(category: .side, label: "Brot-Beilage", calories: 180, protein: 6, keywords: ["brot", "roll", "brötchen", "toast"]),
        FoodItem(category: .side, label: "Coleslaw", calories: 170, protein: 2, keywords: ["coleslaw", "krautsalat"]),
        FoodItem(category: .side, label: "Onion Rings", calories: 280, protein: 5, keywords: ["onion rings", "zwiebelringe"]),
        FoodItem(category: .side, label: "Nachos", calories: 330, protein: 6, keywords: ["nachos", "tortilla chips"]),

        FoodItem(category: .sauce, label: "Tomatensoße", calories: 140, protein: 3, keywords: ["tomatensoße", "tomatensauce", "tomato sauce"]),
        FoodItem(category: .sauce, label: "Sahnesoße", calories: 280, protein: 6, keywords: ["sahnesoße", "cream sauce", "alfredo"]),
        FoodItem(category: .sauce, label: "Bolognese", calories: 320, protein: 20, keywords: ["bolognese", "meat sauce"]),
        FoodItem(category: .sauce, label: "Pesto", calories: 240, protein: 4, keywords: ["pesto"]),
        FoodItem(category: .sauce, label: "Currysoße", calories: 190, protein: 4, keywords: ["curry sauce", "currysauce", "currysoße"]),
        FoodItem(category: .sauce, label: "BBQ-Soße", calories: 110, protein: 1, keywords: ["bbq", "barbecue sauce"]),
        FoodItem(category: .sauce, label: "Mayonnaise", calories: 180, protein: 0, keywords: ["mayo", "mayonnaise", "aioli"]),
        FoodItem(category: .sauce, label: "Ketchup", calories: 60, protein: 1, keywords: ["ketchup"]),
        FoodItem(category: .sauce, label: "Guacamole", calories: 150, protein: 2, keywords: ["guacamole", "avocado dip"]),
        FoodItem(category: .sauce, label: "Erdnussoße", calories: 230, protein: 8, keywords: ["erdnussoße", "peanut sauce"]),

        FoodItem(category: .topping, label: "Käse", calories: 130, protein: 8, keywords: ["käse", "cheese", "mozzarella", "parmesan"]),
        FoodItem(category: .topping, label: "Bacon", calories: 120, protein: 8, keywords: ["bacon", "speck"]),
        FoodItem(category: .topping, label: "Ei", calories: 90, protein: 7, keywords: ["egg", "ei"]),
        FoodItem(category: .topping, label: "Avocado", calories: 120, protein: 2, keywords: ["avocado"]),
        FoodItem(category: .topping, label: "Nüsse", calories: 160, protein: 5, keywords: ["nüsse", "nuts", "almond", "walnut"]),

        FoodItem(category: .dessert, label: "Kuchen", calories: 420, protein: 6, keywords: ["kuchen", "cake", "tarte"]),
        FoodItem(category: .dessert, label: "Donut", calories: 290, protein: 4, keywords: ["donut"]),
        FoodItem(category: .dessert, label: "Cookie", calories: 240, protein: 3, keywords: ["cookie", "keks"]),
        FoodItem(category: .dessert, label: "Eis", calories: 260, protein: 4, keywords: ["eis", "ice cream", "gelato"]),
        FoodItem(category: .dessert, label: "Waffel", calories: 350, protein: 7, keywords: ["waffel", "waffle"]),
        FoodItem(category: .dessert, label: "Brownie", calories: 320, protein: 5, keywords: ["brownie"]),
        FoodItem(category: .dessert, label: "Pudding", calories: 190, protein: 5, keywords: ["pudding", "mousse"]),

        FoodItem(category: .drink, label: "Cola", calories: 140, protein: 0, keywords: ["cola", "coke"]),
        FoodItem(category: .drink, label: "Limonade", calories: 150, protein: 0, keywords: ["limonade", "soda", "soft drink"]),
        FoodItem(category: .drink, label: "Saft", calories: 130, protein: 1, keywords: ["saft", "juice", "orange juice"]),
        FoodItem(category: .drink, label: "Bier", calories: 170, protein: 2, keywords: ["bier", "beer"]),
        FoodItem(category: .drink, label: "Latte", calories: 180, protein: 8, keywords: ["latte", "cappuccino", "milk coffee"]),
        FoodItem(category: .drink, label: "Milchshake", calories: 320, protein: 9, keywords: ["milkshake", "shake"]),
        FoodItem(category: .drink, label: "Smoothie", calories: 220, protein: 4, keywords: ["smoothie"])
    ]

    static func analyze(image: UIImage) async -> FoodScanResult {
        guard let cgImage = image.cgImage else { return fallback }

        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: fallback)
                    return
                }

                let top = Array(observations.prefix(5))
                let resolved = resolveEstimate(for: top)
                continuation.resume(returning: resolved)
            }

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: fallback)
            }
        }
    }

    static func refinedEstimate(for userDescription: String, baseConfidence: Double) -> FoodScanResult {
        let typedDescription = userDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typedDescription.isEmpty else { return fallback }
        let scoring = score(sourceText: typedDescription)
        guard !scoring.items.isEmpty else {
            return FoodScanResult(
                title: typedDescription,
                estimatedCalories: 420,
                estimatedProtein: 18,
                confidence: max(0.15, baseConfidence * 0.85)
            )
        }

        return FoodScanResult(
            title: typedDescription,
            estimatedCalories: scoring.calories,
            estimatedProtein: scoring.protein,
            confidence: max(0.2, baseConfidence * min(1.0, 0.75 + Double(scoring.items.count) * 0.05))
        )
    }

    private static func resolveEstimate(for observations: [VNClassificationObservation]) -> FoodScanResult {
        let sourceText = observations
            .prefix(8)
            .map(\.identifier)
            .joined(separator: " ")
        let scoring = score(sourceText: sourceText)

        if !scoring.items.isEmpty {
            let title = buildTitle(from: scoring.items)
            let baseConfidence = Double(observations.first?.confidence ?? 0.2)
            return FoodScanResult(
                title: title,
                estimatedCalories: scoring.calories,
                estimatedProtein: scoring.protein,
                confidence: max(0.2, min(0.98, baseConfidence * (0.8 + Double(scoring.items.count) * 0.04)))
            )
        }

        if let first = observations.first {
            return FoodScanResult(
                title: cleanedLabel(from: first.identifier),
                estimatedCalories: 420,
                estimatedProtein: 18,
                confidence: Double(first.confidence)
            )
        }

        return fallback
    }

    private static func score(sourceText: String) -> (items: [FoodItem], calories: Int, protein: Int) {
        let normalized = sourceText.lowercased()
        let ranked: [(item: FoodItem, points: Int)] = catalog.compactMap { item in
            let points = item.keywords.reduce(0) { partial, keyword in
                partial + (normalized.contains(keyword) ? 1 : 0)
            }
            return points > 0 ? (item, points) : nil
        }
        .sorted {
            if $0.points == $1.points { return $0.item.calories > $1.item.calories }
            return $0.points > $1.points
        }

        var chosenByCategory: [Category: [FoodItem]] = [:]
        for candidate in ranked {
            let limit: Int
            switch candidate.item.category {
            case .side: limit = 2
            case .topping: limit = 2
            default: limit = 1
            }

            let existing = chosenByCategory[candidate.item.category] ?? []
            if existing.count < limit {
                chosenByCategory[candidate.item.category, default: []].append(candidate.item)
            }
        }

        let items = Category.allCases.flatMap { chosenByCategory[$0] ?? [] }
        guard !items.isEmpty else { return ([], 420, 18) }

        let calories = items.reduce(0) { $0 + $1.calories }
        let protein = items.reduce(0) { $0 + $1.protein }
        return (items, max(80, calories), max(0, protein))
    }

    private static func buildTitle(from items: [FoodItem]) -> String {
        let mains = items.filter { $0.category == .main }.map(\.label)
        let sides = items.filter { $0.category == .side }.map(\.label)
        let sauces = items.filter { $0.category == .sauce }.map(\.label)
        let toppings = items.filter { $0.category == .topping }.map(\.label)

        let base = mains.first ?? items.first?.label ?? "Mahlzeit"
        var parts: [String] = []
        if !sides.isEmpty { parts.append("mit \(sides.joined(separator: " und "))") }
        if !sauces.isEmpty { parts.append("mit \(sauces.joined(separator: " und "))") }
        if !toppings.isEmpty { parts.append("mit \(toppings.joined(separator: " und "))") }

        let joined = parts.joined(separator: ", ")
        return joined.isEmpty ? base : "\(base) \(joined)"
    }

    private static func cleanedLabel(from identifier: String) -> String {
        identifier
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized ?? "Mahlzeit"
    }

}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    FoodScanView()
        .environmentObject(CalorieStore.preview)
}
