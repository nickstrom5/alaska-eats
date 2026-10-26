import Foundation
import CoreLocation

/// The lists the app is built around. Each is a filter plus an order; none uses ratings (the app only publishes data it may).
enum Guide: String, CaseIterable, Identifiable, Hashable {
    case seafood, reindeer, sourdough, roadhouses, global, honors, oldest, inspections, nearMe, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seafood: "Halibut, Salmon & Crab"
        case .reindeer: "Reindeer Dogs"
        case .sourdough: "Sourdough"
        case .roadhouses: "Roadhouses & Lodges"
        case .global: "Anchorage's Global Kitchens"
        case .honors: "James Beard Honors"
        case .oldest: "Oldest Places"
        case .inspections: "Anchorage Inspection Scores"
        case .nearMe: "Near Me"
        case .all: "All Restaurants"
        }
    }

    var subtitle: String {
        switch self {
        case .seafood: "Hand-checked halibut and chips, salmon bakes and king crab"
        case .reindeer: "Hand-checked carts and kitchens serving reindeer sausage"
        case .sourdough: "Hand-checked sourdough pancakes, bread and breakfasts"
        case .roadhouses: "Hand-checked roadhouses and lodges, many open summers only"
        case .global: "Hand-checked Filipino, Korean, Hawaiian, Polynesian and Lao kitchens"
        case .honors: "James Beard finalists, semifinalists and America's Classics"
        case .oldest: "Founding years checked at the same address, oldest first"
        case .inspections: "The Anchorage Health Department's own scores"
        case .nearMe: "Everything around you, closest first"
        case .all: "Restaurants, cafés, bars and espresso stands statewide"
        }
    }

    var systemImage: String {
        switch self {
        case .seafood: "fish"
        case .reindeer: "flame"
        case .sourdough: "frying.pan"
        case .roadhouses: "road.lanes"
        case .global: "globe.americas"
        case .honors: "star.circle"
        case .oldest: "clock.arrow.circlepath"
        case .inspections: "checkmark.seal"
        case .nearMe: "location"
        case .all: "fork.knife"
        }
    }

    /// The Alaska guides get the accent card on Home.
    var isAlaska: Bool { tag != nil }

    /// Guides whose order is a ranking worth numbering.
    var isRanked: Bool { [.oldest].contains(self) }

    var sortOptions: [SortOrder] {
        switch self {
        case .seafood, .reindeer, .sourdough, .roadhouses, .global: [.featured, .nearest, .name]
        case .honors: [.iconic, .nearest]
        case .oldest: [.oldest]
        case .inspections: [.recent, .highestScore, .lowestScore, .nearest]
        case .nearMe: [.nearest]
        case .all: [.name, .nearest]
        }
    }

    var defaultSort: SortOrder { sortOptions[0] }

    /// The tag behind an Alaska guide.
    var tag: PlaceTags? {
        switch self {
        case .seafood: .seafood
        case .reindeer: .reindeer
        case .sourdough: .sourdough
        case .roadhouses: .roadhouse
        case .global: .global
        default: nil
        }
    }

    /// Every Alaska guide lists only places checked open with a 2025–26 source.
    var isHandChecked: Bool { tag != nil }

    func includes(_ p: Place) -> Bool {
        if let tag {
            return p.tags.contains(tag) && p.handChecked
        }
        switch self {
        case .honors: return p.jamesBeard != nil
        case .oldest: return p.founded != nil && p.tags.contains(.oldest)
        case .inspections: return p.inspection != nil
        default: return true
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case featured, nearest, oldest, name, iconic, recent, highestScore, lowestScore
    var id: String { rawValue }
    var label: String {
        switch self {
        case .featured: "Featured first"
        case .nearest: "Nearest"
        case .oldest: "Oldest first"
        case .name: "A to Z"
        case .iconic: "America's Classics, then finalists"
        case .recent: "Latest inspection first"
        case .highestScore: "Highest inspection score"
        case .lowestScore: "Lowest inspection score"
        }
    }
}

/// Filters shared by every list. Search text lives with each list.
struct Filters: Equatable, Codable {
    var town: String?
    var cuisine: String?
    var hideChains = false
    var confirmedOnly = false
    var includeNonRestaurants = false
    // no MICHELIN filter: the MICHELIN Guide covers no Alaska restaurant (BIB-GOURMAND-FILTER.md applies only where there's MICHELIN data)

    var activeCount: Int {
        [town != nil, cuisine != nil, hideChains, confirmedOnly, includeNonRestaurants].filter { $0 }.count
    }

    func allows(_ p: Place) -> Bool {
        if !includeNonRestaurants && p.isVenue { return false }
        if let town, p.city != town { return false }
        if let cuisine, p.cuisine != cuisine { return false }
        if hideChains && p.isChain { return false }
        if confirmedOnly && p.tier == .listing { return false }
        return true
    }
}

extension Filters {
    /// Filters saved by an older build may lack a key: read what's there instead of dropping them all.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(town: try c.decodeIfPresent(String.self, forKey: .town),
                  cuisine: try c.decodeIfPresent(String.self, forKey: .cuisine),
                  hideChains: try c.decodeIfPresent(Bool.self, forKey: .hideChains) ?? false,
                  confirmedOnly: try c.decodeIfPresent(Bool.self, forKey: .confirmedOnly) ?? false,
                  includeNonRestaurants: try c.decodeIfPresent(Bool.self, forKey: .includeNonRestaurants) ?? false)
    }
}

enum Ranking {
    static func sort(_ places: [Place], by order: SortOrder, from here: CLLocation?) -> [Place] {
        // Keys come from fields made once at load: a localized compare, or a new CLLocation per comparison, made a 16,000-place
        // sort take most of a second (AR-13). sortKey is the normalized name, so case, accents and punctuation don't change the order.
        func name(_ a: Place, _ b: Place) -> Bool { a.sortKey != b.sortKey ? a.sortKey < b.sortKey : a.id < b.id }
        switch order {
        case .nearest where here != nil:
            // each distance once, not four times per comparison
            let from = here!
            return places.map { p in (p, p.location.map { $0.distance(from: from) } ?? .greatestFiniteMagnitude) }
                .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : name($0.0, $1.0) }
                .map(\.0)
        case .featured, .nearest:
            // honored places first, then verified founding year, then name
            return places.sorted {
                let a = $0.iconicPoints ?? -1, b = $1.iconicPoints ?? -1
                if a != b { return a > b }
                let fa = $0.founded ?? 9999, fb = $1.founded ?? 9999
                return fa != fb ? fa < fb : name($0, $1)
            }
        case .oldest:
            return places.sorted { ($0.founded ?? 9999) != ($1.founded ?? 9999) ? ($0.founded ?? 9999) < ($1.founded ?? 9999) : name($0, $1) }
        case .name:
            return places.sorted(by: name)
        case .recent:
            return places.sorted {
                let a = $0.inspection?.d ?? "", b = $1.inspection?.d ?? ""
                return a != b ? a > b : name($0, $1)
            }
        case .highestScore, .lowestScore:
            let hi = order == .highestScore
            return places.sorted {
                let a = $0.inspection?.score ?? (hi ? -1 : 999), b = $1.inspection?.score ?? (hi ? -1 : 999)
                if a != b { return hi ? a > b : a < b }
                let da = $0.inspection?.d ?? "", db = $1.inspection?.d ?? ""
                return da != db ? da > db : name($0, $1)
            }
        case .iconic:
            // an order anyone can check: the James Beard honor (America's Classic, winner, finalist, semifinalist), then name
            func jb(_ p: Place) -> Int { p.honorFlags & 1 != 0 ? 4 : p.honorFlags & 2 != 0 ? 3 : p.honorFlags & 4 != 0 ? 2 : p.honorFlags & 8 != 0 ? 1 : 0 }
            return places.sorted {
                if jb($0) != jb($1) { return jb($0) > jb($1) }
                return name($0, $1)
            }
        }
    }
}
