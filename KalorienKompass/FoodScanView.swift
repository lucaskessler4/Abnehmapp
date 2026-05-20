import SwiftUI

struct FoodScanView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.paper.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Foto-Scan")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColor.ink)

                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "camera.macro")
                            .font(.system(size: 54))
                            .foregroundStyle(AppColor.leaf)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Nächster Ausbauschritt")
                            .font(.title2.bold())
                            .foregroundStyle(AppColor.ink)

                        Text("Hier kommt später die Kamera hinein: Foto machen, Essen erkennen lassen, Kalorienvorschlag prüfen und direkt in den Tag übernehmen.")
                            .font(.body)
                            .foregroundStyle(AppColor.muted)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Kamera-Berechtigung vorbereiten", systemImage: "checkmark.circle.fill")
                            Label("Bild an KI-Modell senden", systemImage: "sparkles")
                            Label("Kalorien als Vorschlag speichern", systemImage: "tray.and.arrow.down.fill")
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
}

#Preview {
    FoodScanView()
}
