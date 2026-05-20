import Foundation

struct FoodEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var calories: Int
    var protein: Int
    var date: Date
    var imageData: Data? = nil
}

struct SavedMeal: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var calories: Int
    var protein: Int
    var imageData: Data? = nil
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Hell"
    case dark = "Dunkel"

    var id: String { rawValue }
}

enum Sex: String, Codable, CaseIterable, Identifiable {
    case female = "Weiblich"
    case male = "Männlich"

    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Wenig aktiv"
    case light = "Leicht aktiv"
    case moderate = "Aktiv"
    case high = "Sehr aktiv"

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .low: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .high: return 1.725
        }
    }

    var sportDescription: String {
        switch self {
        case .low:
            return "Kaum Sport, viel Sitzen, wenige Schritte im Alltag."
        case .light:
            return "Leichter Alltag oder 1-3 lockere Sporteinheiten pro Woche."
        case .moderate:
            return "Regelmäßig aktiv, etwa 3-5 Sporteinheiten pro Woche."
        case .high:
            return "Viel Training, körperlicher Job oder fast täglich Sport."
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case loseSlow = "Langsam abnehmen"
    case loseSteady = "Konstant abnehmen"
    case maintain = "Gewicht halten"

    var id: String { rawValue }

    var dailyAdjustment: Int {
        switch self {
        case .loseSlow: return -300
        case .loseSteady: return -500
        case .maintain: return 0
        }
    }
}

struct UserProfile: Codable, Equatable {
    var sex: Sex = .male
    var age: Int = 30
    var heightCentimeters: Int = 180
    var weightKilograms: Double = 85
    var targetWeightKilograms: Double = 78
    var activityLevel: ActivityLevel = .light
    var goal: Goal = .loseSteady

    var basalMetabolicRate: Int {
        let base = 10 * weightKilograms + 6.25 * Double(heightCentimeters) - 5 * Double(age)
        let sexOffset = sex == .male ? 5.0 : -161.0
        return Int((base + sexOffset).rounded())
    }

    var maintenanceCalories: Int {
        Int((Double(basalMetabolicRate) * activityLevel.factor).rounded())
    }

    var targetCalories: Int {
        max(1200, maintenanceCalories + goal.dailyAdjustment)
    }

    var remainingKilograms: Double {
        max(0, weightKilograms - targetWeightKilograms)
    }
}
