import PhotosUI
import SwiftUI
import UIKit
import Vision

struct FoodScanView: View {
    @EnvironmentObject private var store: CalorieStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showCamera = false
    @State private var showCameraUnavailableAlert = false
    @State private var isAnalyzing = false
    @State private var scanResult: FoodScanResult?
    @State private var showSaveHint = false
    @State private var customName = ""

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
                TextField("Mahlzeitname", text: $customName)
                    .textInputAutocapitalization(.words)
                    .glassField()

                StatTile(
                    title: "Geschätzt",
                    value: "\(scanResult.estimatedCalories) kcal",
                    systemImage: "flame.fill",
                    color: AppColor.peach
                )

                Text("KI-Konfidenz: \(Int(scanResult.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)

                Button {
                    saveScanResult(scanResult)
                } label: {
                    Label("In Tagesliste speichern", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.leaf)
                .controlSize(.large)

                if showSaveHint {
                    Text("Gespeichert in Heute.")
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
            }
        }
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
    let title: String
    let estimatedCalories: Int
    let estimatedProtein: Int
    let confidence: Double
}

private enum FoodVisionAnalyzer {
    private static let fallback = FoodScanResult(
        title: "Mahlzeit",
        estimatedCalories: 420,
        estimatedProtein: 18,
        confidence: 0.2
    )

    private static let estimates: [(keywords: [String], calories: Int, protein: Int, label: String)] = [
        (["salad", "vegetable", "greens"], 220, 8, "Salat"),
        (["apple", "banana", "fruit", "berries"], 140, 2, "Obst"),
        (["pizza"], 780, 30, "Pizza"),
        (["burger", "sandwich"], 650, 28, "Burger/Sandwich"),
        (["pasta", "spaghetti", "noodle"], 620, 22, "Pasta"),
        (["rice", "risotto"], 520, 12, "Reisgericht"),
        (["soup"], 300, 10, "Suppe"),
        (["steak", "beef", "meat"], 500, 38, "Fleischgericht"),
        (["fish", "salmon"], 420, 34, "Fischgericht"),
        (["cake", "dessert", "cookie", "donut"], 460, 6, "Dessert"),
        (["bread", "toast"], 280, 9, "Brotmahlzeit")
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

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: fallback)
            }
        }
    }

    private static func resolveEstimate(for observations: [VNClassificationObservation]) -> FoodScanResult {
        for observation in observations {
            let identifier = observation.identifier.lowercased()
            if let matched = estimates.first(where: { estimate in
                estimate.keywords.contains { identifier.contains($0) }
            }) {
                return FoodScanResult(
                    title: matched.label,
                    estimatedCalories: matched.calories,
                    estimatedProtein: matched.protein,
                    confidence: Double(observation.confidence)
                )
            }
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

    private static func cleanedLabel(from identifier: String) -> String {
        identifier
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized ?? "Mahlzeit"
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
