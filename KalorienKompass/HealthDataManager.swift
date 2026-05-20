import Foundation
import HealthKit

@MainActor
final class HealthDataManager: ObservableObject {
    enum ImportState: Equatable {
        case idle
        case unavailable
        case requesting
        case automatic
        case imported(Int)
        case failed(String)

        var message: String {
            switch self {
            case .idle:
                return "Noch nicht synchronisiert"
            case .unavailable:
                return "Apple Health ist auf diesem Gerät nicht verfügbar."
            case .requesting:
                return "Apple Health und Garmin Connect werden gelesen ..."
            case .automatic:
                return "Automatische Synchronisierung ist aktiv."
            case .imported(let calories):
                return "\(calories) kcal automatisch übernommen."
            case .failed(let message):
                return message
            }
        }
    }

    @Published var state: ImportState = .idle

    private let healthStore = HKHealthStore()
    private var hasConfiguredAutomaticSync = false
    private var automaticImportHandler: (([ActivitySource: Int]) -> Void)?

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func configureAutomaticSync(onImport: @escaping ([ActivitySource: Int]) -> Void) async {
        automaticImportHandler = onImport
        guard !hasConfiguredAutomaticSync else { return }
        guard isHealthDataAvailable else {
            state = .unavailable
            return
        }

        do {
            try await authorizeActivityReads()
            try await enableBackgroundDelivery()
            hasConfiguredAutomaticSync = true
            state = .automatic

            if let caloriesBySource = await importTodaysTrackedCalories() {
                onImport(caloriesBySource)
            }
        } catch {
            state = .failed("Automatische Synchronisierung konnte nicht aktiviert werden.")
        }
    }

    func importTodaysTrackedCalories() async -> [ActivitySource: Int]? {
        guard isHealthDataAvailable else {
            state = .unavailable
            return nil
        }

        state = .requesting

        do {
            try await authorizeActivityReads()
            let caloriesBySource = try await readTodaysActiveEnergyBySource()
            let totalCalories = caloriesBySource.values.reduce(0, +)
            state = hasConfiguredAutomaticSync ? .automatic : .imported(totalCalories)
            return caloriesBySource
        } catch {
            state = .failed("Apple Health und Garmin Connect konnten nicht gelesen werden.")
            return nil
        }
    }

    private func authorizeActivityReads() async throws {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthImportError.quantityTypeUnavailable
        }

        let workoutType = HKObjectType.workoutType()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: [activeEnergyType, workoutType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthImportError.authorizationDenied)
                }
            }
        }
    }

    private func enableBackgroundDelivery() async throws {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthImportError.quantityTypeUnavailable
        }

        try await enableBackgroundDelivery(for: activeEnergyType)
        try await enableBackgroundDelivery(for: HKObjectType.workoutType())

        startObserver(for: activeEnergyType)
        startObserver(for: HKObjectType.workoutType())
    }

    private func enableBackgroundDelivery(for type: HKObjectType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthImportError.backgroundDeliveryUnavailable)
                }
            }
        }
    }

    private func startObserver(for sampleType: HKSampleType) {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                defer { completionHandler() }

                guard let self,
                      let caloriesBySource = await self.importTodaysTrackedCalories() else { return }

                self.automaticImportHandler?(caloriesBySource)
            }
        }

        healthStore.execute(query)
    }

    private func readTodaysActiveEnergyBySource() async throws -> [ActivitySource: Int] {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthImportError.quantityTypeUnavailable
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: activeEnergyType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let quantitySamples = samples as? [HKQuantitySample] ?? []
                let caloriesBySource = quantitySamples.reduce(into: [ActivitySource: Int]()) { result, sample in
                    let source = Self.activitySource(from: sample.sourceRevision.source.name)
                    let calories = sample.quantity.doubleValue(for: .kilocalorie())
                    result[source, default: 0] += Int(calories.rounded())
                }

                continuation.resume(returning: caloriesBySource)
            }

            healthStore.execute(query)
        }
    }

    nonisolated private static func activitySource(from healthSourceName: String) -> ActivitySource {
        let normalizedName = healthSourceName.lowercased()

        if normalizedName.contains("garmin") {
            return .garmin
        }

        return .appleHealth
    }
}

private enum HealthImportError: Error {
    case authorizationDenied
    case backgroundDeliveryUnavailable
    case quantityTypeUnavailable
}
