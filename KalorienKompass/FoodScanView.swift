import SwiftUI

struct FoodScanView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Foto-Scan")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColor.ink)

                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "camera.macro")
                            .font(.system(size: 54))
                            .foregroundStyle(AppColor.leaf)
                            .frame(width: 82, height: 82)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                            }

                        Text("Nächster Ausbauschritt")
                            .font(.title2.bold())
                            .foregroundStyle(AppColor.ink)

                        Text("Hier kommt später die Kamera hinein: Foto machen, Essen erkennen lassen, Kalorienvorschlag prüfen und direkt in den Tag übernehmen.")
                            .font(.body)
                            .foregroundStyle(AppColor.muted)

                        VStack(alignment: .leading, spacing: 10) {
                            scanStep("Kamera-Berechtigung vorbereiten", systemImage: "checkmark.circle.fill")
                            scanStep("Bild an KI-Modell senden", systemImage: "sparkles")
                            scanStep("Kalorien als Vorschlag speichern", systemImage: "tray.and.arrow.down.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppColor.ink)
                    }
                    .surface()

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Scan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
            }
        }
    }

    private func scanStep(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }
    }
}

#Preview {
    FoodScanView()
}
