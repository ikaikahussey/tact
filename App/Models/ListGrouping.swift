import Foundation

/// How the list groups its rows: a section per person with their notes
/// beneath, or the notes alone by how recent they are. Remembered in
/// `UserDefaults` under `storageKey`.
enum ListGrouping: String, CaseIterable, Identifiable {
    case person
    case recent

    static let storageKey = "listGrouping"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .person: "By Person"
        case .recent: "Recent"
        }
    }
}

/// How long ago a note's date is, for the Recent grouping. Buckets run
/// newest first, so the list reads top down from today.
enum RecentBucket: Int, CaseIterable, Comparable, Identifiable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case earlier

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        case .earlier: "Earlier"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The bucket `date` falls in as seen from `now`: the same day, the day
    /// before, within the last seven days, within the last month, or
    /// before that. A date after `now` counts as today.
    init(_ date: Date, now: Date = Date(), calendar: Calendar = .current) {
        if date >= now || calendar.isDate(date, inSameDayAs: now) {
            self = .today
        } else if calendar.isDateInYesterday(date) || isYesterday(date, now: now, calendar: calendar) {
            self = .yesterday
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
            self = .thisWeek
        } else if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now), date >= monthAgo {
            self = .thisMonth
        } else {
            self = .earlier
        }
    }
}

/// Whether `date` falls on the day before `now`'s day.
private func isYesterday(_ date: Date, now: Date, calendar: Calendar) -> Bool {
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
    return calendar.isDate(date, inSameDayAs: yesterday)
}

/// The notes of one recency bucket, newest first.
struct RecentSection: Identifiable, Equatable {
    let bucket: RecentBucket
    let notes: [Note]
    var id: RecentBucket { bucket }
}
