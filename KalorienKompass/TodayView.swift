import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: CalorieStore
    @State private var foodName = ""
    @State private var calories = ""
    @State private var protein = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.paper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        progressCard
                        quickAddCard
                        entriesSection
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Heute")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalorien Kompass")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.ink)
            Text("Ein klarer Blick auf deinen Tag, ohne Kalorienbuchhaltung als Strafarbeit.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
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
            }

            ProgressView(value: store.calorieProgress)
                .tint(store.remainingCalories >= 0 ? AppColor.leaf : .red)
                .scaleEffect(x: 1, y: 2.4, anchor: .center)

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
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                TextField("kcal", text: $calories)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Protein g", text: $protein)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

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
        }
        .surface()
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
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private func addFood() {
        guard let calorieValue = Int(calories) else { return }
        store.addEntry(
            name: foodName,
            calories: calorieValue,
            protein: Int(protein) ?? 0
        )
        foodName = ""
        calories = ""
        protein = ""
    }
}

#Preview {
    TodayView()
        .environmentObject(CalorieStore.preview)
}
