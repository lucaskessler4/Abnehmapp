import SwiftUI

struct TrackingView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: CalorieStore
    @EnvironmentObject private var healthDataManager: HealthDataManager
    @State private var selectedSource: ActivitySource = .garmin
    @State private var calories = ""
    @State private var note = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case calories
        case note
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headline
                        summaryCard
                        appConnectionsCard
                        manualCard
                        activityList
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Tracking")
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

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps verbinden")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.ink)
            Text("Apple Health und Garmin Connect erhöhen dein Tagesbudget automatisch.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("+\(store.todaysActivityCalories)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.leaf)
                Text("kcal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                Spacer()
                Image(systemName: "figure.run.circle.fill")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(AppColor.leaf)
            }

            HStack(spacing: 10) {
                StatTile(title: "Basis", value: "\(store.profile.targetCalories) kcal", systemImage: "target", color: AppColor.sky)
                StatTile(title: "Heute", value: "\(store.adjustedTargetCalories) kcal", systemImage: "plus.forwardslash.minus", color: AppColor.peach)
            }
        }
        .surface()
    }

    private var appConnectionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Automatische App-Synchronisierung", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            VStack(spacing: 10) {
                connectedAppRow(
                    source: .appleHealth,
                    description: "Liest aktive Energie und neue Trainings aus Apple Health."
                )
                connectedAppRow(
                    source: .garmin,
                    description: "Wird automatisch erkannt, sobald Garmin Connect seine Trainings in Apple Health schreibt."
                )
            }

            Text(healthDataManager.state.message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassField()

            Button {
                syncConnectedApps()
            } label: {
                Label("Verbundene Apps jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.leaf)
            .controlSize(.large)
            .disabled(healthDataManager.state == .requesting || !store.hasConnectedActivitySources)
        }
        .surface()
    }

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Tracking manuell eintragen", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            Picker("Quelle", selection: $selectedSource) {
                ForEach(ActivitySource.allCases.filter { $0 != .appleHealth }) { source in
                    Label(source.displayName, systemImage: source.systemImage)
                        .tag(source)
                }
            }
            .pickerStyle(.segmented)

            TextField("Aktivitätskalorien", text: $calories)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .calories)
                .glassField()

            TextField("Notiz, z. B. Lauftraining", text: $note)
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .note)
                .glassField()

            Button {
                addManualActivity()
            } label: {
                Label("Zum Tagesbudget addieren", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.leaf)
            .disabled(Int(calories) == nil)
            .controlSize(.large)
        }
        .surface()
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heutige Trackings")
                .font(.title3.bold())
                .foregroundStyle(AppColor.ink)

            if store.todaysActivityEntries.isEmpty {
                ContentUnavailableView(
                    "Noch keine Aktivität",
                    systemImage: "figure.walk.circle",
                    description: Text("Verbinde Apple Health und Garmin Connect oder trage Aktivitätskalorien manuell ein.")
                )
                .surface()
            } else {
                VStack(spacing: 10) {
                    ForEach(store.todaysActivityEntries) { entry in
                        activityRow(entry)
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch healthDataManager.state {
        case .failed, .unavailable:
            return .red
        case .imported:
            return AppColor.leaf
        default:
            return AppColor.muted
        }
    }

    private func activityRow(_ entry: ActivityCalorieEntry) -> some View {
        return HStack(spacing: 12) {
            Image(systemName: entry.source.systemImage)
                .font(.headline)
                .foregroundStyle(AppColor.leaf)
                .frame(width: 42, height: 42)
                .background(AppColor.mint.opacity(0.85), in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.source.displayName)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Text(entry.note.isEmpty ? entry.date.formatted(date: .omitted, time: .shortened) : entry.note)
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text("+\(entry.calories) kcal")
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            Button {
                store.deleteActivityEntry(entry)
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(entry.source.displayName) löschen")
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
        }
    }

    private func connectedAppRow(source: ActivitySource, description: String) -> some View {
        let isConnected = store.isActivitySourceConnected(source)

        return HStack(spacing: 12) {
            Image(systemName: source.systemImage)
                .font(.headline)
                .foregroundStyle(AppColor.leaf)
                .frame(width: 42, height: 42)
                .background(AppColor.mint.opacity(0.85), in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(source.displayName)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isConnected {
                Button {
                    store.disconnectActivitySource(source)
                } label: {
                    Text("Trennen")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    connect(source)
                } label: {
                    Text("Verbinden")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.leaf)
                .disabled(healthDataManager.state == .requesting)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
        }
    }

    private func connect(_ source: ActivitySource) {
        focusedField = nil

        if source == .garmin {
            openGarminConnect()
        }

        Task {
            await healthDataManager.configureAutomaticSync { caloriesBySource in
                store.replaceTodaysTrackedActivities(caloriesBySource)
            }

            guard canUseHealthSync else { return }

            store.connectActivitySource(source)

            if let caloriesBySource = await healthDataManager.importTodaysTrackedCalories() {
                store.replaceTodaysTrackedActivities(caloriesBySource)
            }
        }
    }

    private func openGarminConnect() {
        guard let appURL = URL(string: "gcm-ciq://"),
              let appStoreURL = URL(string: "https://apps.apple.com/app/garmin-connect/id583446403") else { return }

        openURL(appURL) { accepted in
            guard !accepted else { return }
            openURL(appStoreURL)
        }
    }

    private func syncConnectedApps() {
        focusedField = nil

        Task {
            await healthDataManager.configureAutomaticSync { caloriesBySource in
                store.replaceTodaysTrackedActivities(caloriesBySource)
            }

            guard let caloriesBySource = await healthDataManager.importTodaysTrackedCalories() else { return }
            store.replaceTodaysTrackedActivities(caloriesBySource)
        }
    }

    private func addManualActivity() {
        guard let calorieValue = Int(calories) else { return }
        focusedField = nil

        store.addActivity(
            source: selectedSource,
            calories: calorieValue,
            note: note
        )

        calories = ""
        note = ""
    }

    private var canUseHealthSync: Bool {
        switch healthDataManager.state {
        case .failed, .unavailable:
            return false
        default:
            return true
        }
    }
}

#Preview {
    TrackingView()
        .environmentObject(CalorieStore.preview)
        .environmentObject(HealthDataManager())
}
