import Foundation
import CoreLocation
import UIKit

/// `-screenshot <name>` opens one screen with fixed state for App Store screenshots (scripts/capture-screenshots.sh).
/// Names: home, seafood, reindeer, roadhouses, global, detail, map, honors, oldest, saved, about.
enum ScreenshotMode {
    /// Debug builds only: an App Store build ignores the launch argument, so no one can reach seeded screens or fake locations.
    static var name: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }
    static var isActive: Bool { name != nil }

    @MainActor
    static func apply(to model: AppModel) {
        guard let name, model.isLoaded else { return }
        model.filters = Filters()
        // downtown Anchorage (4th Avenue at E Street), so "nearest" lists have distances without a permission prompt
        model.screenshotLocation = CLLocation(latitude: 61.2176, longitude: -149.8930)
        // by name and town, ignoring case, so a rebuild with a slightly different casing still finds the place; the hand-checked one first.
        // No inspection list is opened: an App Store image never shows a reinspection or a low score.
        let pick = { (n: String, town: String?) -> Place? in
            let hits = model.places.filter { $0.name.caseInsensitiveCompare(n) == .orderedSame && (town == nil || $0.city == town) }
            return hits.first(where: \.handChecked) ?? hits.first
        }
        for p in [pick("Lucky Wishbone", "Anchorage"), pick("Altura Bistro", "Anchorage"), pick("In Bocca al Lupo", "Juneau")]
            .compactMap({ $0 }) where !model.isSaved(p) {
            model.toggleSaved(p)
        }
        let open = { (g: Guide) in model.tab = .guides; model.selectedGuide = g; model.guidesPath = [.guide(g)] }
        switch name {
        case "seafood":
            // from the Homer Spit, so the nearest halibut and crab houses are a short walk
            model.screenshotLocation = CLLocation(latitude: 59.6046, longitude: -151.4250)
            open(.seafood)
        case "reindeer": open(.reindeer)
        case "roadhouses": open(.roadhouses)
        case "global": open(.global)
        case "honors": open(.honors)
        case "oldest": open(.oldest)
        case "detail":
            // honored and scored: the detail shot shows a James Beard honor and Anchorage's own score (100, next regular inspection)
            open(.honors)
            if let p = pick("Whisky & Ramen", "Anchorage") ?? pick("Lucky Wishbone", "Anchorage") ?? model.places.first {
                model.selectedPlace = p; model.guidesPath.append(.place(p))
            }
        case "map": model.tab = .map
        case "saved": model.tab = .saved
        case "about": model.tab = .about
        default: model.tab = .guides; model.selectedGuide = nil
        }
        // iPad shows the place column next to every list, so give each shot a place instead of "Pick a place": an honored or
        // hand-checked one with a current Anchorage permit and score, so no store image shows "(none matched)" (Lucky Wishbone's and
        // Altura Bistro's records in the department's file are too old to count).
        guard UIDevice.current.userInterfaceIdiom == .pad, model.selectedPlace == nil else { return }
        let place: Place? = switch name {
        case "home", "honors", "saved", "oldest": pick("Whisky & Ramen", "Anchorage") ?? pick("Lucky Wishbone", "Anchorage")
        case "map": pick("Simon & Seafort's Saloon & Grill", "Anchorage") ?? pick("Whisky & Ramen", "Anchorage")
        case "seafood", "reindeer", "roadhouses", "global": model.list(Guide(rawValue: name) ?? .seafood, sort: .featured, search: "", here: nil).first
        case "about": nil
        default: pick("Whisky & Ramen", "Anchorage")
        }
        model.selectedPlace = place
    }
}
