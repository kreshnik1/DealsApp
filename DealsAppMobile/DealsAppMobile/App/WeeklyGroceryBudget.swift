import Foundation

enum WeeklyGroceryBudget: String, CaseIterable, Identifiable {
    case underFiveHundred
    case fiveHundredToThousand
    case thousandToFifteenHundred
    case fifteenHundredToTwentyFiveHundred
    case overTwentyFiveHundred

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .underFiveHundred:
            "Under 500 kr"
        case .fiveHundredToThousand:
            "500-1000 kr"
        case .thousandToFifteenHundred:
            "1000-1500 kr"
        case .fifteenHundredToTwentyFiveHundred:
            "1500-2500 kr"
        case .overTwentyFiveHundred:
            "2500+ kr"
        }
    }

    var detail: String {
        switch self {
        case .underFiveHundred:
            "A lighter grocery week."
        case .fiveHundredToThousand:
            "A modest weekly grocery budget."
        case .thousandToFifteenHundred:
            "A common weekly range for many households."
        case .fifteenHundredToTwentyFiveHundred:
            "A higher weekly grocery spend."
        case .overTwentyFiveHundred:
            "A large grocery budget or larger household."
        }
    }

    var estimatedWeeklySpend: Double {
        switch self {
        case .underFiveHundred:
            400
        case .fiveHundredToThousand:
            750
        case .thousandToFifteenHundred:
            1250
        case .fifteenHundredToTwentyFiveHundred:
            2000
        case .overTwentyFiveHundred:
            3000
        }
    }
}
