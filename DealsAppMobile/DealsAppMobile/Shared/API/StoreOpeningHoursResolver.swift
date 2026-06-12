import Foundation

struct StoreOpeningHoursResolver {
    private let regularHours: [OpeningHoursEntryDTO]
    private let specialHours: [OpeningHoursEntryDTO]
    private let calendar: Calendar

    init(
        regularHours: [OpeningHoursEntryDTO],
        specialHours: [OpeningHoursEntryDTO] = [],
        calendar: Calendar = .current
    ) {
        self.regularHours = regularHours
        self.specialHours = specialHours
        self.calendar = calendar
    }

    func hoursText(for date: Date) -> String? {
        guard let weekday = StoreWeekday(date: date, calendar: calendar) else {
            return nil
        }

        let matchingEntry = specialHours.first(where: { $0.matches(weekday: weekday) })
            ?? regularHours.first(where: { $0.matches(weekday: weekday) })

        return matchingEntry?.displayHoursText
    }
}

private enum StoreWeekday {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    init?(date: Date, calendar: Calendar) {
        switch calendar.component(.weekday, from: date) {
        case 1:
            self = .sunday
        case 2:
            self = .monday
        case 3:
            self = .tuesday
        case 4:
            self = .wednesday
        case 5:
            self = .thursday
        case 6:
            self = .friday
        case 7:
            self = .saturday
        default:
            return nil
        }
    }

    func matches(_ day: String) -> Bool {
        aliases.contains(Self.normalize(day))
    }

    private var aliases: Set<String> {
        switch self {
        case .monday:
            ["monday", "mandag"]
        case .tuesday:
            ["tuesday", "tisdag"]
        case .wednesday:
            ["wednesday", "onsdag"]
        case .thursday:
            ["thursday", "torsdag"]
        case .friday:
            ["friday", "fredag"]
        case .saturday:
            ["saturday", "lordag"]
        case .sunday:
            ["sunday", "sondag"]
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "sv_SE"))
            .lowercased()
    }
}

private extension OpeningHoursEntryDTO {
    func matches(weekday: StoreWeekday) -> Bool {
        days.contains(where: weekday.matches)
    }

    var displayHoursText: String {
        let openText = open?.trimmedNonEmpty
        let closeText = close?.trimmedNonEmpty

        switch (openText, closeText) {
        case let (open?, close?):
            return "\(open) - \(close)"
        case (nil, nil):
            return "Closed"
        case let (open?, nil):
            return "Opens at \(open)"
        case let (nil, close?):
            return "Closes at \(close)"
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
