import SwiftUI

struct NeedsCalculatorView: View {
    @EnvironmentObject private var store: CalorieStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.paper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headline
                        resultCard
                        profileForm
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Bedarf")
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dein Tagesziel")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.ink)
            Text("Berechnet mit der Mifflin-St Jeor-Formel plus Aktivität und Zieltempo.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(store.profile.targetCalories) kcal")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.leaf)

            HStack(spacing: 10) {
                StatTile(title: "Grundumsatz", value: "\(store.profile.basalMetabolicRate) kcal", systemImage: "flame.fill", color: AppColor.peach)
                StatTile(title: "Erhaltung", value: "\(store.profile.maintenanceCalories) kcal", systemImage: "equal.circle.fill", color: AppColor.sky)
            }

            Text("Bis zum Zielgewicht fehlen etwa \(store.profile.remainingKilograms, specifier: "%.1f") kg.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
        .surface()
    }

    private var profileForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Geschlecht", selection: $store.profile.sex) {
                ForEach(Sex.allCases) { sex in
                    Text(sex.rawValue).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            Stepper("Alter: \(store.profile.age)", value: $store.profile.age, in: 14...90)
            Stepper("Größe: \(store.profile.heightCentimeters) cm", value: $store.profile.heightCentimeters, in: 130...220)

            VStack(alignment: .leading, spacing: 8) {
                Text("Aktuelles Gewicht: \(store.profile.weightKilograms, specifier: "%.1f") kg")
                Slider(value: $store.profile.weightKilograms, in: 40...180, step: 0.5)
                    .tint(AppColor.leaf)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Zielgewicht: \(store.profile.targetWeightKilograms, specifier: "%.1f") kg")
                Slider(value: $store.profile.targetWeightKilograms, in: 40...180, step: 0.5)
                    .tint(AppColor.leaf)
            }

            Picker("Aktivität", selection: $store.profile.activityLevel) {
                ForEach(ActivityLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }

            Picker("Ziel", selection: $store.profile.goal) {
                ForEach(Goal.allCases) { goal in
                    Text(goal.rawValue).tag(goal)
                }
            }
        }
        .font(.body)
        .surface()
    }
}

#Preview {
    NeedsCalculatorView()
        .environmentObject(CalorieStore.preview)
}
