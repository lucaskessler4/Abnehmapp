import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: CalorieStore
    @Environment(\.bottomDockClearance) private var bottomDockClearance
    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var monthSummaries: [DayCalorieSummary] {
        store.daySummariesForMonth(containing: displayedMonth)
    }

    private var summariesByDay: [Date: DayCalorieSummary] {
        Dictionary(uniqueKeysWithValues: monthSummaries.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    private var selectedSummary: DayCalorieSummary {
        summariesByDay[calendar.startOfDay(for: selectedDate)] ?? store.daySummary(for: selectedDate)
    }

    private var monthDeficitCount: Int {
        monthSummaries.filter { isTracked($0) && $0.hasDeficit }.count
    }

    private var monthTrackedCount: Int {
        monthSummaries.filter(isTracked).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headline
                        monthCard
                        selectedDayCard
                    }
                    .padding(18)
                    .padding(.bottom, bottomDockClearance)
                }
            }
            .navigationTitle("Kalender")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Defizit-Tage im Blick")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.ink)
            Text("Grün bedeutet Defizit erreicht, Rot bedeutet kein Defizit.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
    }

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.ink)

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                StatTile(title: "Defizit-Tage", value: "\(monthDeficitCount)", systemImage: "checkmark.seal.fill", color: AppColor.mint)
                StatTile(title: "Getrackt", value: "\(monthTrackedCount)", systemImage: "calendar", color: AppColor.sky)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthGridDays().enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .surface()
    }

    private var selectedDayCard: some View {
        let tracked = isTracked(selectedSummary)

        return VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            HStack(spacing: 10) {
                StatTile(title: "Gegessen", value: "\(selectedSummary.consumedCalories) kcal", systemImage: "fork.knife", color: AppColor.peach)
                StatTile(title: "Maximum fürs Defizit", value: "\(selectedSummary.targetCalories) kcal", systemImage: "target", color: AppColor.sky)
            }

            if !tracked {
                Label("Kein Tracking an diesem Tag", systemImage: "minus.circle")
                    .font(.headline)
                    .foregroundStyle(AppColor.muted)
            } else if selectedSummary.hasDeficit {
                Label("Defizit: \(selectedSummary.balance) kcal", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppColor.leaf)
            } else {
                Label("Kein Defizit: \(abs(selectedSummary.balance)) kcal drüber", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            Text("Aktivität an diesem Tag: +\(selectedSummary.activityCalories) kcal")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
        }
        .surface()
    }

    private func dayCell(for date: Date) -> some View {
        let summary = summariesByDay[calendar.startOfDay(for: date)] ?? store.daySummary(for: date)
        let tracked = isTracked(summary)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.bold))
                if tracked {
                    Text(summary.hasDeficit ? "-\(summary.balance)" : "+\(abs(summary.balance))")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("—")
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(dayForegroundColor(summary: summary, tracked: tracked))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(dayBackgroundColor(summary: summary, tracked: tracked))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.leaf : AppColor.glassStroke, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(tracked ? 1 : 0.55)
    }

    private func isTracked(_ summary: DayCalorieSummary) -> Bool {
        summary.consumedCalories > 0 || summary.activityCalories > 0
    }

    private func dayBackgroundColor(summary: DayCalorieSummary, tracked: Bool) -> Color {
        guard tracked else { return AppColor.field }
        return summary.hasDeficit ? AppColor.mint : Color.red.opacity(0.75)
    }

    private func dayForegroundColor(summary: DayCalorieSummary, tracked: Bool) -> Color {
        guard tracked else { return AppColor.muted }
        return summary.hasDeficit ? AppColor.ink : .white
    }

    private func monthGridDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = calendar.firstWeekdayIndexFromMonday(for: firstDay)

        var days = Array(repeating: Date?.none, count: firstWeekday)
        var cursor = firstDay

        while cursor < monthInterval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func shiftMonth(by offset: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: shifted)

        if !calendar.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) {
            selectedDate = displayedMonth
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        guard let monthInterval = dateInterval(of: .month, for: date) else {
            return startOfDay(for: date)
        }
        return monthInterval.start
    }

    func firstWeekdayIndexFromMonday(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}

#Preview {
    CalendarView()
        .environmentObject(CalorieStore.preview)
        .environmentObject(HealthDataManager())
}
