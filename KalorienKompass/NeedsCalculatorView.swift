import SwiftUI

struct NeedsCalculatorView: View {
    @EnvironmentObject private var store: CalorieStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headline
                        resultCard
                        profileForm
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Bedarf")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dein Tagesziel")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.ink)
            Text("Berechnet mit der Mifflin-St Jeor-Formel plus Aktivität und Zieltempo.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.profile.targetCalories)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.leaf)
                Text("kcal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                Spacer()
                Image(systemName: "target")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColor.leaf)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                            .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                    }
            }

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

            VStack(spacing: 10) {
                Stepper("Alter: \(store.profile.age)", value: $store.profile.age, in: 14...90)
                Divider().opacity(0.45)
                Stepper("Größe: \(store.profile.heightCentimeters) cm", value: $store.profile.heightCentimeters, in: 130...220)
            }
            .glassField()

            VStack(alignment: .leading, spacing: 8) {
                Text("Aktuelles Gewicht: \(store.profile.weightKilograms, specifier: "%.1f") kg")
                    .font(.subheadline.weight(.semibold))
                Slider(value: $store.profile.weightKilograms, in: 40...180, step: 0.5)
                    .tint(AppColor.leaf)
            }
            .glassField()

            VStack(alignment: .leading, spacing: 8) {
                Text("Zielgewicht: \(store.profile.targetWeightKilograms, specifier: "%.1f") kg")
                    .font(.subheadline.weight(.semibold))
                Slider(value: $store.profile.targetWeightKilograms, in: 40...180, step: 0.5)
                    .tint(AppColor.leaf)
            }
            .glassField()

            VStack(alignment: .leading, spacing: 8) {
                Text("Aktivität")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)

                Menu {
                    Picker("Aktivität", selection: $store.profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text("\(level.rawValue) - \(level.sportDescription)")
                                .tag(level)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.profile.activityLevel.rawValue)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColor.leaf)
                            Text(store.profile.activityLevel.sportDescription)
                                .font(.caption)
                                .foregroundStyle(AppColor.muted)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.leaf)
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                            .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                    }
                }
            }

            Picker("Ziel", selection: $store.profile.goal) {
                ForEach(Goal.allCases) { goal in
                    Text(goal.rawValue).tag(goal)
                }
            }
            .pickerStyle(.menu)
            .glassField()
        }
        .font(.body)
        .surface()
    }
}

#Preview {
    NeedsCalculatorView()
        .environmentObject(CalorieStore.preview)
}
