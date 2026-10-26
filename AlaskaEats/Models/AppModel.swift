import Foundation
import Observation
import CoreLocation

/// The whole app's state: the bundled places, filters, saved places and what's selected.
@MainActor
@Observable
final class AppModel {
    private(set) var places: [Place] = []
    private(set) var isLoaded = false
    private(set) var loadError: String?
    private(set) var generated = ""
    private(set) var restaurantCount = 0
    /// restaurants on Anchorage's food permit or liquor license lists
    var licensedCount: Int { places.filter { !$0.isVenue && $0.tier == .licensed }.count }
    /// restaurants with the Anchorage Health Department's inspection score
    var inspectedCount: Int { places.filter { !$0.isVenue && $0.inspection != nil }.count }
    private(set) var calibration = Calibration(areas: [:])
    /// the day the Anchorage Clerk's liquor license list was published
    private(set) var liquorUpdated = ""
    private(set) var licensesUpdated: String?
    /// active on-premises liquor licenses on the Clerk's list, and active fixed food permits (Anchorage)
    private(set) var licenseCount: Int?
    private(set) var permitCount: Int?
    /// the newest inspection in the department's file, the oldest one used, and the day the file last changed
    private(set) var inspectionsThrough: String?
    private(set) var inspectionsFrom: String?
    private(set) var inspectionsFileModified: String?
    /// the department's next steps and inspection types, verbatim (sentence case)
    private(set) var results: [String] = []
    private(set) var itypes: [String] = []
    /// the Overture Maps release the listings come from, read from the data file
    private(set) var overtureRelease: String?
    /// towns sorted by how many restaurants they have
    private(set) var towns: [(name: String, count: Int)] = []
    private(set) var cuisines: [(name: String, count: Int)] = []
    /// Bib Gourmand places (non-restaurants left out, like the other counts): the Filters switch shows only when there are some.
    private(set) var bibCount = 0
    /// normalized town name -> display name ("canon city" -> "Cañon City")
    private(set) var townKeys: [String: String] = [:]

    var filters = Filters() { didSet { saveFilters() } }
    private(set) var saved: Set<String> = []

    // navigation (iPad sidebar / iPhone tabs)
    var selectedGuide: Guide?
    var selectedPlace: Place?
    var tab: Tab = .guides
    enum Tab: Hashable { case guides, map, saved, about }
    /// the iPhone guides stack: a guide, then a place
    var guidesPath: [Route] = []
    enum Route: Hashable { case guide(Guide), place(Place) }
    /// bumped by openGuide so the iPad sidebar follows even when the same guide is picked again
    private(set) var guideRequest = 0
    /// iPad to iPhone-size (Split View, Stage Manager): the place that was open next to the Map or Saved list, for that tab's own
    /// stack to show, so a size-class change doesn't lose it
    var handoffPlace: Place?

    /// The iPhone guides stack for what's selected: the open guide, then the open place.
    var compactPath: [Route] {
        (selectedGuide.map { [Route.guide($0)] } ?? []) + (selectedPlace.map { [Route.place($0)] } ?? [])
    }

    /// iPhone: the stack changed (a push, a pop, a swipe back), so the selection follows it; an iPad layout then opens on the same
    /// guide and place.
    func followPath() {
        var guide: Guide?
        for r in guidesPath { if case .guide(let g) = r { guide = g } }
        if selectedGuide != guide { selectedGuide = guide }
        if case .place(let p) = guidesPath.last { if selectedPlace != p { selectedPlace = p } } else if selectedPlace != nil { selectedPlace = nil }
    }

    /// Open a guide from Home: pushes it on iPhone, selects it in the iPad sidebar.
    func openGuide(_ g: Guide) {
        tab = .guides
        selectedGuide = g
        guidesPath = [.guide(g)]
        guideRequest += 1
    }

    /// a fixed "you are here" for screenshots, so lists sort by distance without a permission prompt
    var screenshotLocation: CLLocation?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        saved = Set(defaults.stringArray(forKey: "saved") ?? [])
        if let data = defaults.data(forKey: "filters"), let f = try? JSONDecoder().decode(Filters.self, from: data) { filters = f }
    }

    /// A cold launch from Spotlight asks for the data twice (the app's .task and the search continuation); both wait on one decode.
    private var loading: Task<Void, Never>?
    /// where a region's detail file is: the app bundle, or (tests) a folder next to a test core file
    private var detailURL: (String) -> URL? = { Bundle.main.url(forResource: "detail-" + $0, withExtension: "json") }
    /// region detail files already read, and the reads in flight (two places of one region opened quickly share one read)
    @ObservationIgnored private var details: [String: [String: PlaceDetail]] = [:]
    @ObservationIgnored private var detailLoads: [String: Task<[String: PlaceDetail], Never>] = [:]

    /// "Kodiak, Southwest & Aleutians" -> "kodiak-southwest-aleutians": the file name the pipeline writes (detail-kodiak-southwest-aleutians.json)
    nonisolated static func regionSlug(_ region: String) -> String {
        region.lowercased().replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "[^a-z]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// The detail record for a place (permit, licenses, inspection history, phone, website), reading its region's file once.
    /// Nil when the place has no detail (no record, no phone, no website) or the file can't be read.
    func detail(for p: Place) async -> PlaceDetail? {
        let region = p.region ?? "Other"
        if let d = details[region] { return d[p.id] }
        if let t = detailLoads[region] { return await t.value[p.id] }
        let url = detailURL(Self.regionSlug(region))
        let t = Task.detached(priority: .userInitiated) { () -> [String: PlaceDetail] in
            guard let url, let data = try? Data(contentsOf: url) else { return [:] }
            return (try? JSONDecoder().decode([String: PlaceDetail].self, from: data)) ?? [:]
        }
        detailLoads[region] = t
        let d = await t.value
        details[region] = d
        detailLoads[region] = nil
        return d[p.id]
    }

    func load(from url: URL? = Bundle.main.url(forResource: "places", withExtension: "json"), detailFolder: URL? = nil) async {
        if let detailFolder { detailURL = { detailFolder.appendingPathComponent("detail-\($0).json") } }
        guard !isLoaded else { return }
        if let loading { await loading.value; return }
        let task = Task { await decode(from: url) }
        loading = task
        await task.value
    }

    private func decode(from url: URL?) async {
        guard let url else { loadError = "The restaurant data is missing from the app."; return }
        do {
            let (file, places) = try await Task.detached(priority: .userInitiated) { () throws -> (DataFile, [Place]) in
                let data = try Data(contentsOf: url)
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DataFile.Malformed(field: "everything") }
                let file = try DataFile(json: root)
                // kept in A-to-Z order: a filter keeps it, so the A-to-Z sort of any list is a pass over an already sorted array
                let places = Place.build(root["places"] as? [[String: Any]] ?? [], file: file)
                    .sorted { $0.sortKey != $1.sortKey ? $0.sortKey < $1.sortKey : $0.id < $1.id }
                return (file, places)
            }.value
            apply(file: file, places: places)
        } catch {
            loadError = "The restaurant data couldn't be read (\(error.localizedDescription))."
        }
    }

    func apply(file: DataFile, places: [Place]) {
        self.places = places
        generated = file.generated
        restaurantCount = file.count_restaurants
        calibration = file.calibration
        liquorUpdated = file.liquor_updated
        licensesUpdated = file.licenses_updated
        licenseCount = file.moa_active_onprem
        permitCount = file.anc_active_permits
        inspectionsThrough = file.inspections_through["anc"]
        inspectionsFrom = file.inspections_from
        inspectionsFileModified = file.inspections_file_modified
        results = file.results
        itypes = file.itypes
        overtureRelease = file.overture_release
        var tc: [String: Int] = [:], cc: [String: Int] = [:]
        for p in places where !p.isVenue {
            if let c = p.city { tc[c, default: 0] += 1 }
            cc[p.cuisine, default: 0] += 1
        }
        towns = tc.map { ($0.key, $0.value) }.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        cuisines = cc.map { ($0.key, $0.value) }.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        bibCount = places.lazy.filter { !$0.isVenue && $0.michelin == .bib }.count
        var keys: [String: String] = [:]
        for (name, _) in towns {   // biggest town wins a shared spelling
            let k = Search.normalizeAddress(name)
            if keys[k] == nil { keys[k] = name }
        }
        townKeys = keys
        if let t = filters.town, tc[t] == nil { filters.town = nil }
        if let c = filters.cuisine, cc[c] == nil { filters.cuisine = nil }
        isLoaded = true
    }

    func place(id: String) -> Place? { places.first { $0.id == id } }

    /// the department's next step for an inspection, as published
    func step(_ i: Int) -> InspectionStep? { i >= 0 && i < results.count ? InspectionStep(index: i, label: results[i]) : nil }
    func itype(_ i: Int) -> String? { i >= 0 && i < itypes.count ? itypes[i] : nil }

    /// The guides Home shows: a hand-checked guide appears once its research lands, so no card opens an empty list.
    var homeGuides: [Guide] {
        [Guide.seafood, .reindeer, .sourdough, .roadhouses, .global, .honors, .oldest, .inspections, .nearMe].filter { g in
            g == .nearMe || places.contains { g.includes($0) && !$0.isVenue }
        }
    }

    /// The last list asked for. A list view's body runs on every change (an iPad row tap re-renders it), so the same guide, sort,
    /// search, filters and (for a distance sort) location to ~100 m reuse the result instead of filtering 17,000 places again.
    private struct ListKey: Equatable {
        let guide: Guide, sort: SortOrder, search: String, filters: Filters, count: Int, lat: Int?, lon: Int?
    }
    @ObservationIgnored private var lastList: (key: ListKey, places: [Place])?

    /// Places in a guide, filtered and searched, in the chosen order.
    func list(_ guide: Guide, sort: SortOrder, search: String, here: CLLocation?) -> [Place] {
        // reading filters and places here keeps SwiftUI observing them even when the cached list is returned
        let usesHere = sort == .nearest || guide == .nearMe
        let key = ListKey(guide: guide, sort: sort, search: search, filters: filters, count: places.count,
                          lat: usesHere ? here.map { Int(($0.coordinate.latitude * 1000).rounded()) } : nil,
                          lon: usesHere ? here.map { Int(($0.coordinate.longitude * 1000).rounded()) } : nil)
        if let lastList, lastList.key == key { return lastList.places }
        let out = makeList(guide, sort: sort, search: search, here: usesHere ? here : nil)
        lastList = (key, out)
        return out
    }

    private func makeList(_ guide: Guide, sort: SortOrder, search: String, here: CLLocation?) -> [Place] {
        let q = Search.parse(search, towns: townKeys)
        // typed something, but nothing searchable ("🍕", "!!!"): show nothing rather than everything
        if q.isEmpty && !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        var out = places.filter { guide.includes($0) && filters.allows($0) && (q.isEmpty || Search.matches($0, q)) }
        if guide == .nearMe && here == nil { return [] }
        out = Ranking.sort(out, by: sort, from: here)
        if !q.tokens.isEmpty && !(guide.isRanked) {   // name matches first when searching
            let named = out.filter { Search.nameMatches($0, q) }
            if !named.isEmpty && named.count < out.count {
                let ids = Set(named.map(\.id))
                out = named + out.filter { !ids.contains($0.id) }
            }
        }
        return out
    }

    func count(_ guide: Guide) -> Int { places.lazy.filter { guide.includes($0) && self.filters.allows($0) }.count }

    // MARK: saved places

    func isSaved(_ p: Place) -> Bool { saved.contains(p.id) }

    func toggleSaved(_ p: Place) {
        if saved.contains(p.id) { saved.remove(p.id) } else { saved.insert(p.id) }
        defaults.set(Array(saved).sorted(), forKey: "saved")
    }

    var savedPlaces: [Place] { places.filter { saved.contains($0.id) }.sorted { $0.sortKey != $1.sortKey ? $0.sortKey < $1.sortKey : $0.id < $1.id } }

    /// A random place from a guide ("Surprise me"), never the one just shown.
    func randomPick(from guide: Guide, excluding last: String?) -> Place? {
        let pool = places.filter { guide.includes($0) && filters.allows($0) && $0.id != last }
        return pool.randomElement()
    }

    /// "Surprise me": a random hand-checked Alaska pick (any guide), never the one just shown.
    func randomClassic(excluding last: String?) -> Place? {
        places.filter { $0.isClassic && filters.allows($0) && $0.id != last }.randomElement()
    }

    private func saveFilters() {
        if let data = try? JSONEncoder().encode(filters) { defaults.set(data, forKey: "filters") }
    }

    // MARK: honest labels

    /// "73%": how often a listing of this kind matched an active Anchorage food permit or liquor license (every food business there
    /// needs a permit, so it's close to a real rate; places opened since the department's file stopped count as misses).
    func matchRate(for p: Place) -> String? {
        guard p.tier != .licensed else { return nil }   // an official record confirms it; no listing rate needed
        let group: String
        switch (p.source, p.tier) {
        case ("meta", .confirmed): group = "meta_high"
        case ("meta", _): group = "meta_mid"
        case ("AllThePlaces", _), ("DAC", _): group = "brand_feed"
        default: return nil
        }
        let v = calibration.areas.values.compactMap { $0.groups[group]?.official }.map { Int(($0 * 100).rounded()) }.sorted()
        guard let lo = v.first, let hi = v.last else { return nil }
        return lo == hi ? "\(lo)%" : "\(lo)–\(hi)%"
    }
}
