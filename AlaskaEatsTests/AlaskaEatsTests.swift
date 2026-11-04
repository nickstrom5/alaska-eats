import XCTest
import CoreLocation
@testable import AlaskaEats

@MainActor
final class AlaskaEatsTests: XCTestCase {

    /// A tiny core file and two region detail files with the same shape as Resources/places.json and Resources/detail-*.json.
    private func sampleModel() async throws -> AppModel {
        let json = """
        {"v":1,"generated":"2026-10-26","overture_release":"2026-10-21.0","liquor_updated":"2026-10-25","licenses_updated":"2026-10-25",
         "anc_active_permits":725,"moa_active_onprem":252,"inspections_through":{"anc":"2026-05-18"},"inspections_from":"2023-05-18",
         "inspections_file_modified":"2026-05-19",
         "cities":["Anchorage","Homer","Talkeetna","Juneau","Eagle River","Utqiaġvik","Joint Base Elmendorf-Richardson","Wasilla"],
         "cuisines":["Bar & Pub","Seafood","Chicken & Wings","Breakfast & Diner","American & Other","Filipino","Hot Dogs & Sausages"],
         "brands":["Subway"],"counties":["Anchorage Municipality","Kenai Peninsula Borough","Matanuska-Susitna Borough","Juneau City and Borough","North Slope Borough"],
         "regions":["Anchorage","Mat-Su","Kenai Peninsula","Interior","Southeast","Prince William Sound & Copper River","Kodiak, Southwest & Aleutians","Western & Arctic"],
         "srcs":["official","meta","AllThePlaces","DAC","research"],
         "results":["Next regular inspection within 12 months","Reinspection required within 6 months"],"itypes":["Regular","Reinspection"],
         "count":9,"count_restaurants":8,
         "calibration":{"Anchorage Municipality":{"listings":1393,"groups":{"meta_high":{"n":591,"official":0.728}}}},
         "places":[
          {"id":"a","n":"Lucky Wishbone","c":0,"co":0,"rg":0,"cu":2,"t":2,"s":1,"hc":1,"g":32,"f":1955,"h":17,"jbf":"America's Classic 2025","ip":70,"a":"1033 E 5th Ave","z":"99501","la":61.2178,"lo":-149.8628,"in":[0,0,97,"2026-04-01"]},
          {"id":"b","n":"Captain Pattie's Fish House","c":1,"co":1,"rg":2,"cu":1,"t":1,"s":1,"hc":1,"g":1,"a":"4241 Homer Spit Rd","la":59.6046,"lo":-151.4250,"dish":"halibut; king crab"},
          {"id":"c","n":"Talkeetna Roadhouse","c":2,"co":2,"rg":1,"cu":3,"t":1,"s":1,"hc":1,"g":12,"a":"13550 E Main St","la":62.3236,"lo":-150.1094},
          {"id":"d","n":"Tracy's King Crab Shack","c":3,"co":3,"rg":4,"cu":1,"t":1,"s":1,"g":1,"a":"432 S Franklin St","la":58.2988,"lo":-134.4057},
          {"id":"e","n":"Exchange Food Court","c":6,"co":0,"rg":0,"cu":4,"t":1,"s":1,"v":1,"la":61.2356,"lo":-149.7620},
          {"id":"f","n":"Altura Bistro","c":0,"co":0,"rg":0,"cu":4,"t":2,"s":1,"hc":1,"h":4,"jbf":"Best Chef: Northwest and Pacific finalist 2026 (Nathan Bentley)","ip":40,"a":"4240 Old Seward Hwy","la":61.1792,"lo":-149.8657,"liq":1,"in":[0,1,84,"2026-02-10"]},
          {"id":"g","n":"Kusina Pinoy","c":4,"co":0,"rg":0,"cu":5,"t":0,"s":1,"hc":1,"g":16,"a":"12812 Old Glenn Hwy","la":61.3214,"lo":-149.5679,"in":[0,0,100,"2025-11-20"]},
          {"id":"h","n":"Pepe's North of the Border","c":5,"co":4,"rg":7,"cu":4,"t":1,"s":1,"a":"1204 Agvik St","la":71.2906,"lo":-156.7886},
          {"id":"i","n":"M.A.'s Gourmet Dogs","c":0,"co":0,"rg":0,"cu":6,"t":1,"s":1,"g":2,"la":61.2170,"lo":-149.8900}
         ]}
        """
        let anchorage = """
        {"a":{"lic":[["Anchorage food permit","FA0001234","Food establishment permit",null]],"ph":"(907) 272-3454","w":"luckywishbone.com",
              "in":{"n":3,"h":[["2026-04-01",0,97,0],["2025-04-03",0,95,0],["2024-03-30",1,86,1]],"v":["PROPER COLD HOLDING TEMPERATURES"],
                    "r":"https://anchorageonline.envisionconnect.com/#/pa1/detail/FA0001234/PR0001200"}},
         "f":{"lic":[["Anchorage food permit","FA0009999","Food establishment permit",null],["Anchorage liquor license","4321","Restaurant or Eating Place (beer and wine)","2026"]],
              "in":{"n":1,"h":[["2026-02-10",1,84,0]],"r":"https://evil.example.com/#/pa1/detail/FA0009999/PR1"}},
         "i":{"w":"javascript:alert(1)"}}
        """
        let kenai = """
        {"b":{"w":"captainpatties.com"}}
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ak-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("places.json")
        try json.data(using: .utf8)!.write(to: url)
        try anchorage.data(using: .utf8)!.write(to: dir.appendingPathComponent("detail-anchorage.json"))
        try kenai.data(using: .utf8)!.write(to: dir.appendingPathComponent("detail-kenai-peninsula.json"))
        let model = AppModel(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        await model.load(from: url, detailFolder: dir)
        XCTAssertTrue(model.isLoaded, model.loadError ?? "")
        return model
    }

    func testDecodesAndHidesNonRestaurantsByDefault() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.places.count, 9)
        XCTAssertEqual(m.restaurantCount, 8)
        XCTAssertFalse(m.list(.all, sort: .name, search: "", here: nil).contains { $0.name == "Exchange Food Court" }, "an on-base food court is hidden by default")
        m.filters.includeNonRestaurants = true
        XCTAssertTrue(m.list(.all, sort: .name, search: "", here: nil).contains { $0.name == "Exchange Food Court" })
    }

    func testGuidesListOnlyWhatTheyPromise() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.seafood, sort: .name, search: "", here: nil).map(\.name), ["Captain Pattie's Fish House"], "a seafood tag without a hand check isn't listed")
        XCTAssertEqual(m.list(.sourdough, sort: .name, search: "", here: nil).map(\.name), ["Talkeetna Roadhouse"])
        XCTAssertEqual(m.list(.roadhouses, sort: .name, search: "", here: nil).map(\.name), ["Talkeetna Roadhouse"])
        XCTAssertEqual(m.list(.global, sort: .name, search: "", here: nil).map(\.name), ["Kusina Pinoy"])
        XCTAssertEqual(m.list(.reindeer, sort: .name, search: "", here: nil).map(\.name), [], "a reindeer tag without a hand check isn't listed")
        XCTAssertEqual(m.list(.oldest, sort: .oldest, search: "", here: nil).map(\.name), ["Lucky Wishbone"])
        XCTAssertEqual(m.list(.honors, sort: .iconic, search: "", here: nil).map(\.name), ["Lucky Wishbone", "Altura Bistro"], "America's Classic, then a finalist")
        XCTAssertEqual(Set(m.list(.inspections, sort: .recent, search: "", here: nil).map(\.name)), ["Lucky Wishbone", "Altura Bistro", "Kusina Pinoy"])
        XCTAssertTrue(Guide.allCases.filter(\.isAlaska).allSatisfy(\.isHandChecked))
        XCTAssertFalse(m.homeGuides.contains(.reindeer), "Home hides a guide with no hand-checked place")
        XCTAssertTrue(m.homeGuides.contains(.seafood))
    }

    func testInspectionsShowTheDepartmentsOwnScoreAndStep() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.inspections, sort: .lowestScore, search: "", here: nil).map(\.name), ["Altura Bistro", "Lucky Wishbone", "Kusina Pinoy"])
        XCTAssertEqual(m.list(.inspections, sort: .highestScore, search: "", here: nil).map(\.name), ["Kusina Pinoy", "Lucky Wishbone", "Altura Bistro"])
        XCTAssertEqual(m.list(.inspections, sort: .recent, search: "", here: nil).first?.name, "Lucky Wishbone")
        let a = try XCTUnwrap(m.place(id: "f")?.inspection)
        XCTAssertEqual(a.score, 84)
        XCTAssertEqual(m.step(a.step)?.label, "Reinspection required within 6 months")
        XCTAssertTrue(m.step(a.step)?.isFollowUp ?? false)
        XCTAssertFalse(m.step(0)?.isFollowUp ?? true)
        XCTAssertNil(m.step(9), "an index past the list isn't a step")
        XCTAssertNil(m.place(id: "b")?.inspection, "no score outside Anchorage")
        XCTAssertEqual(m.inspectionsThrough, "2026-05-18"); XCTAssertEqual(m.inspectionsFileModified, "2026-05-19")
        let d = await m.detail(for: m.place(id: "a")!)
        XCTAssertEqual(d?.inspection?.h.map(\.score), [97, 95, 86])
        XCTAssertEqual(m.itype(d?.inspection?.h.last?.t ?? -1), "Reinspection")
        XCTAssertEqual(d?.inspection?.reportURL?.host, "anchorageonline.envisionconnect.com")
        let f = await m.detail(for: m.place(id: "f")!)
        XCTAssertNil(f?.inspection?.reportURL, "a report link to any other host is dropped")
    }

    func testDatesAreCalendarDays() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let d = DayFormat.date("2026-06-16")!
        XCTAssertEqual(utc.dateComponents([.year, .month, .day], from: d), DateComponents(year: 2026, month: 6, day: 16))
        XCTAssertTrue(DayFormat.monthYear("2025-09-01")!.contains("2025"))
        XCTAssertNil(DayFormat.date("2026-13-01"))
        XCTAssertEqual(DayFormat.text("soon"), "soon", "a value that isn't a date is shown as it is")
    }

    func testRegionDetailsLoadOnDemand() async throws {
        let m = try await sampleModel()
        let v = await m.detail(for: m.place(id: "a")!)
        XCTAssertEqual(v?.licenses.first?.source, "Anchorage food permit")
        XCTAssertEqual(v?.licenses.first?.id, "FA0001234")
        XCTAssertNil(v?.licenses.first?.expires, "a permit row without an expiration still decodes")
        XCTAssertEqual(v?.website?.absoluteString, "https://luckywishbone.com", "a bare host gets https://")
        let f = await m.detail(for: m.place(id: "f")!)
        XCTAssertEqual(f?.licenses.last?.expires, "2026", "the Clerk's expiration year comes through")
        let dogs = await m.detail(for: m.place(id: "i")!)
        XCTAssertNil(dogs?.website, "a javascript: link never becomes a website button")
        let homer = await m.detail(for: m.place(id: "b")!)
        XCTAssertEqual(homer?.website?.host, "captainpatties.com", "the Kenai Peninsula file is read on its own")
        XCTAssertEqual(AppModel.regionSlug("Kodiak, Southwest & Aleutians"), "kodiak-southwest-aleutians")
        XCTAssertEqual(AppModel.regionSlug("Prince William Sound & Copper River"), "prince-william-sound-copper-river")
        let missing = await m.detail(for: m.place(id: "c")!)
        XCTAssertNil(missing, "a region with no detail file reads as no detail, not a crash")
    }

    func testSearchWordStartsTownsAndGuides() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.all, sort: .name, search: "old sew", here: nil).map(\.name), ["Altura Bistro"], "a street word start")
        XCTAssertEqual(m.list(.all, sort: .name, search: "homer", here: nil).map(\.name), ["Captain Pattie's Fish House"], "a town narrows to it")
        XCTAssertEqual(m.list(.all, sort: .name, search: "king crab", here: nil).map(\.name), ["Tracy's King Crab Shack", "Captain Pattie's Fish House"], "a dish finds who is named for it (first) and who serves it")
        XCTAssertEqual(m.list(.all, sort: .name, search: "🍕", here: nil), [], "an emoji finds nothing, not everything")
        XCTAssertEqual(m.list(.all, sort: .name, search: "sourdough", here: nil).map(\.name), ["Talkeetna Roadhouse"], "a guide word means the guide")
        XCTAssertEqual(m.list(.all, sort: .name, search: "eagle river", here: nil).map(\.name), ["Kusina Pinoy"], "a two-word town")
        XCTAssertEqual(m.list(.all, sort: .name, search: "utqiagvik", here: nil).map(\.name), ["Pepe's North of the Border"], "Utqiaġvik without its ġ")
        XCTAssertEqual(Search.normalize("Ørchard Æble Łódź"), "orchard aeble lodz")
    }

    func testOutsideAlaskaUsesTheOutline() {
        func inside(_ la: Double, _ lo: Double) -> Bool { AlaskaOutline.contains(CLLocationCoordinate2D(latitude: la, longitude: lo)) }
        XCTAssertTrue(inside(61.2176, -149.8930), "Anchorage"); XCTAssertTrue(inside(58.3019, -134.4197), "Juneau")
        XCTAssertTrue(inside(55.3414, -131.6458), "Ketchikan's dock"); XCTAssertTrue(inside(71.2906, -156.7886), "Utqiaġvik")
        XCTAssertTrue(inside(55.9167, -130.0167), "Hyder"); XCTAssertTrue(inside(51.88, -176.64), "Adak")
        XCTAssertTrue(inside(52.93, 173.18), "Attu, where an iPhone reports a longitude east of 180°")
        XCTAssertTrue(inside(65.75, -168.95), "Little Diomede"); XCTAssertTrue(inside(57.12, -170.28), "St. Paul")
        XCTAssertFalse(inside(60.72, -135.05), "Whitehorse"); XCTAssertFalse(inside(54.31, -130.32), "Prince Rupert")
        XCTAssertFalse(inside(64.06, -139.43), "Dawson City"); XCTAssertFalse(inside(64.73, 177.51), "Anadyr")
        XCTAssertFalse(inside(47.61, -122.33), "Seattle"); XCTAssertFalse(inside(37.33, -122.03), "Cupertino")
    }

    func testMatchRatesComeFromAnchoragesPermits() async throws {
        let m = try await sampleModel()
        XCTAssertNil(m.matchRate(for: m.place(id: "a")!), "an official record needs no listing rate")
        XCTAssertEqual(m.matchRate(for: m.place(id: "c")!), "73%")
    }

    func testBundledData() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "bundle-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        XCTAssertGreaterThan(m.restaurantCount, 1_500)
        XCTAssertGreaterThan(m.licensedCount, 400, "hundreds of Anchorage restaurants are on its permit or license lists")
        XCTAssertGreaterThan(m.inspectedCount, 300, "Anchorage's inspection scores")
        XCTAssertEqual(Set(m.places.map(\.id)).count, m.places.count, "ids are unique")
        for g in Guide.allCases where g.isHandChecked {
            XCTAssertTrue(m.places.filter(g.includes).allSatisfy(\.handChecked), "\(g.title) lists only hand-checked places")
        }
        XCTAssertTrue(m.places.allSatisfy { $0.michelin == .none }, "no MICHELIN Guide covers Alaska")
        XCTAssertTrue(m.places.filter { $0.inspection != nil }.allSatisfy { $0.county == "Anchorage Municipality" }, "scores only where Anchorage inspects")
        XCTAssertTrue(m.places.compactMap(\.coordinate).allSatisfy { (-180...180).contains($0.longitude) && (51...72).contains($0.latitude) },
                      "ordinary longitudes (the pipeline's unwrapped ones never ship) and Alaska's latitudes")
        XCTAssertTrue(m.places.allSatisfy { p in p.coordinate.map { AlaskaOutline.contains($0) } ?? true }, "every place is inside the outline")
        let bases: Set<String> = ["Joint Base Elmendorf-Richardson", "Fort Wainwright", "Eielson AFB"]
        XCTAssertTrue(m.places.filter { bases.contains($0.city ?? "") }.allSatisfy(\.isVenue), "places on a military base are hidden by default")
        // records through comes from the data, at least 7 days before the build
        let through = try XCTUnwrap(DayFormat.date(m.inspectionsThrough)), built = try XCTUnwrap(DayFormat.date(m.generated))
        XCTAssertLessThanOrEqual(through, built.addingTimeInterval(-7 * 86_400))
        XCTAssertTrue(m.places.compactMap(\.inspection).allSatisfy { (DayFormat.date($0.d) ?? .distantFuture) <= through })
        // no Google-derived data: the data file has no rating, review or price fields at all
        let raw = try String(contentsOf: Bundle.main.url(forResource: "places", withExtension: "json")!, encoding: .utf8)
        for key in ["\"rating\"", "\"reviews\"", "\"price\"", "\"gmap_id\""] { XCTAssertFalse(raw.contains(key), "\(key) must not ship") }
        // honors the research settled (playbook: name a known place so a merge can't silently lose it)
        let lw = try XCTUnwrap(m.places.first { $0.name == "Lucky Wishbone" && $0.city == "Anchorage" })
        XCTAssertEqual(lw.jamesBeardLabel, "America's Classic"); XCTAssertTrue(lw.handChecked)
        XCTAssertFalse(m.places.contains { $0.name == "The Broken Blender" }, "at Sweet Cheeks Cabaret's address")
    }

    /// Stable ids: md5(name + ~100 m cell)[:12], never a row number; every bundled region detail file decodes and its ids are core ids.
    func testIdsAndBundledDetailFiles() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "ids-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.places.allSatisfy { $0.id.count >= 12 && $0.id.prefix(12).allSatisfy(\.isHexDigit) && $0.id.dropFirst(12).allSatisfy { $0 == "x" } })
        let ids = Set(m.places.map(\.id))
        var permitted = 0, reports = 0
        for region in Set(m.places.compactMap(\.region)) {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json"), region)
            let d = try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url))
            XCTAssertTrue(Set(d.keys).isSubset(of: ids), "\(region) detail ids are core ids")
            permitted += d.values.filter { $0.licenses.contains { $0.source == "Anchorage food permit" } }.count
            reports += d.values.filter { $0.inspection?.reportURL != nil }.count
            XCTAssertTrue(d.values.allSatisfy { $0.licenses.allSatisfy { l in l.expires.map { Int($0) != nil } ?? true } }, "expirations are years")
        }
        XCTAssertGreaterThan(permitted, 300, "permitted places carry their Anchorage permit")
        XCTAssertGreaterThan(reports, 300, "inspected places link the department's own reports")
    }

    func testBundledDataGuards() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "guards-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        XCTAssertEqual(DataGuards.adultVenues(m.places), [], "no strip club under its name")
        XCTAssertEqual(DataGuards.adultAddresses(m.places), [], "no place at a checked adult-club address")
        XCTAssertEqual(DataGuards.gamingParlors(m.places), [], "no gaming parlor among the restaurants")
        XCTAssertEqual(DataGuards.badWebsites(try DataGuards.bundledLinks(m.places)), [], "no directory, Google or news page as a restaurant's website")
        XCTAssertEqual(DataGuards.badNames(m.places), [], "no visible name ending in \u{201C} the\u{201D} or \u{201C} of\u{201D}, or just \u{201C}The\u{201D}")
        XCTAssertEqual(DataGuards.legalNames(m.places), [], "no license holder entity name (\u{201C}… LLC\u{201D}) shown as a place's name")
        XCTAssertEqual(DataGuards.nonRestaurants(m.places), [], "no nail salon, care home, school, gun store or gas station among the restaurants")
    }

    /// Each guard above fires on a copy of the bundled data broken the way QA found it elsewhere: a guard that can't fail guards nothing.
    func testGuardsCatchABrokenCopy() async throws {
        let raw = try Data(contentsOf: Bundle.main.url(forResource: "places", withExtension: "json")!)
        var file = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        var places = try XCTUnwrap(file["places"] as? [[String: Any]])
        let idx = places.indices.filter { places[$0]["v"] == nil }.prefix(9).map { $0 }
        places[idx[2]]["n"] = "Great Alaskan Bush Company"
        places[idx[3]]["n"] = "Kitchen the"
        places[idx[4]]["n"] = "NORTHERN HOSPITALITY GROUP LLC"
        places[idx[5]]["n"] = "Polaris Assisted Living"
        places[idx[6]]["n"] = "Jackpot Gaming Hall"
        places[idx[7]]["a"] = "1565 Gambell St"; places[idx[7]]["c"] = (file["cities"] as? [String])?.firstIndex(of: "Anchorage")
        places[idx[8]]["n"] = "The Meltdown"
        file["places"] = places
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("places-broken.json")
        try JSONSerialization.data(withJSONObject: file).write(to: url)
        let m = AppModel(defaults: UserDefaults(suiteName: "broken-\(UUID().uuidString)")!)
        await m.load(from: url)
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        let id = idx.map { places[$0]["id"] as? String }
        func caught(_ found: [String], _ i: Int, _ what: String) {
            XCTAssertTrue(found.contains { $0.contains("[\(id[i] ?? "?")]") }, "the guard missed \(what)")
        }
        let links = [(name: "A", id: "x1", url: "https://www.yelp.com/biz/some-place"), (name: "B", id: "x2", url: "https://www.adn.com/alaska-life/food-drink/2026/"),
                     (name: "C", id: "x3", url: "https://smart.com/menu")]
        XCTAssertEqual(DataGuards.badWebsites(links).count, 2, "the guard catches a Yelp page and a news story, and not smart.com")
        caught(DataGuards.adultVenues(m.places), 2, "a strip club")
        caught(DataGuards.badNames(m.places), 3, "\u{201C}Kitchen the\u{201D}")
        caught(DataGuards.legalNames(m.places), 4, "a license holder's entity name")
        caught(DataGuards.nonRestaurants(m.places), 5, "a care home shown as a restaurant")
        caught(DataGuards.gamingParlors(m.places), 6, "a gaming hall shown as a restaurant")
        caught(DataGuards.adultAddresses(m.places), 7, "a place at the Crazy Horse Saloon's address")
        caught(DataGuards.nonRestaurants(m.places), 8, "a Denny's delivery-only brand shown as a restaurant (QA 2026-10-29)")
    }
}

/// Checks on the bundled data, written as functions so testGuardsCatchABrokenCopy can prove each one fires.
enum DataGuards {
    /// directories, Google and news sites: matched on the link's host, so "smart.com" isn't "rt.com"
    static let badHosts = #"^https?://([^/?#]*\.)?(yelp\.com|business\.site|google\.com|groupon\.com|yellowpages\.com|tripadvisor\.com|adn\.com|alaskasnewssource\.com|ktuu\.com|alaskapublic\.org|newsminer\.com|juneauempire\.com|ktoo\.org|homernews\.com|peninsulaclarion\.com|travelalaska\.com|anchorage\.net|alaska\.org|eater\.com|rt\.com)([:/?#]|$)"#

    static func badWebsites(_ links: [(name: String, id: String, url: String)]) -> [String] {
        links.compactMap { l in
            guard l.url.range(of: badHosts, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
            return "\(l.name) [\(l.id)]: \(l.url)"
        }
    }

    /// every website link in the bundled region detail files, with its place's name
    static func bundledLinks(_ places: [Place]) throws -> [(name: String, id: String, url: String)] {
        let names = Dictionary(places.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var out: [(name: String, id: String, url: String)] = []
        for region in Set(places.compactMap(\.region)) {
            guard let url = Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json") else { continue }
            for (id, d) in try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url)) {
                if let w = d.website?.absoluteString { out.append((names[id] ?? "?", id, w)) }
            }
        }
        return out
    }

    static let adultNames = #"gentlem[ae]n['’]?s club|strip club|exotic dancer|\bmen['’]?s club|rick['’]?s cabaret|xtc cabaret|baby dolls|spearmint rhino|bikini bar|pt['’]?s showclub|showgirls|centerfolds|treasures? gentlem|deja ?vu showgirls|hustler club|penthouse club|stars cabaret|lucky devil lounge|devils point|casa diablo|golden dragon exotic|union jacks? club|kit kat club|bikini barista|bush company|sweet cheeks cabaret|fantasies on 5th|club sinrock|good time charlie"#

    /// data/research/adult_venues.json's checked club addresses (number and street start), by town
    static let adultAddresses: [(String, String)] = [("631 E International Airport", "Anchorage"), ("1565 Gambell", "Anchorage"),
                                                     ("535 W 3rd Ave", "Anchorage"), ("1911 E 5th Ave", "Anchorage"), ("301 W 64th Ave", "Anchorage"),
                                                     ("1347 Bedrock", "Fairbanks"), ("42140 Sterling", "Soldotna"), ("42140 Sterling", "Sterling")]

    static func adultAddresses(_ places: [Place]) -> [String] {
        places.filter { p in adultAddresses.contains { (a, t) in p.city == t && (p.address ?? "").lowercased().hasPrefix(a.lowercased()) } }
            .map { "\($0.name) [\($0.id)]" }
    }

    /// names that advertise gambling: listed only with the non-restaurants (Alaska has no video lottery; bars' pull-tabs don't count)
    static let gamingNames = #"\b(lottery|lotto|jackpot|slots?|poker|gaming)\b"#

    static func gamingParlors(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: gamingNames, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }

    /// every license key in the bundled region detail files, by place id
    static func bundledLicenses(_ places: [Place]) throws -> [String: [String]] {
        var out: [String: [String]] = [:]
        for region in Set(places.compactMap(\.region)) {
            guard let url = Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json") else { continue }
            for (id, d) in try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url)) where !d.licenses.isEmpty {
                out[id] = d.licenses.compactMap(\.id)
            }
        }
        return out
    }

    static func adultVenues(_ places: [Place]) -> [String] {
        places.filter { $0.name.range(of: adultNames, options: [.regularExpression, .caseInsensitive]) != nil }.map { "\($0.name) [\($0.id)]" }
    }

    /// a name cut off after "the" or "of" ("Kitchen the", "Wines of") or nothing but "The", among the places shown by default
    static func badNames(_ places: [Place]) -> [String] {
        places.filter { p in
            let n = p.name.trimmingCharacters(in: .whitespaces).lowercased()
            return !p.isVenue && (n.hasSuffix(" the") || n.hasSuffix(" of") || n == "the")
        }.map { "\($0.name) [\($0.id)]" }
    }

    /// the Clerk's Owner field is never read; a business name that's still a legal entity shouldn't be shown either
    static let legalSuffix = #"\b(llc|l\.l\.c|inc|corp|corporation)\.?$"#

    static func legalNames(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: legalSuffix, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }

    /// businesses that aren't places to eat, among the places shown by default
    /// and delivery-only brands cooked in another restaurant's kitchen: Denny's The Meltdown, The Burger Den and Banda Burrito (QA 2026-10-29)
    static let nonRestaurantNames = #"\bnails?\b|assisted living|elementary school|middle school|high school|child ?care|gun (?:club|range|shop|store)|shooting range|firearms|petroleum|\bauto (?:repair|parts)\b|^(?:the )?(?:meltdown|burger den)$|banda burrito|tenderfix|pardon my cheesesteak|neighborhood wings"#

    static func nonRestaurants(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: nonRestaurantNames, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }
}

/// pipeline/website_blocklist.json (hacked, taken-over, expired or another business's sites, confirmed by hand in the link sweeps):
/// no link on it may ship in any field of any JSON file the app bundles. The 2026-10-19 QA found the export had only filtered the
/// website field, or nothing, so hijacked links were still in the bundle. Read from the repo, so a new entry needs no code change.
final class LinkBlocklistTests: XCTestCase {
    func testNoBlocklistedLinkInBundledData() throws {
        let entries = try LinkBlocklist.entries()
        XCTAssertFalse(entries.isEmpty, "the blocklist is missing or empty")
        let files = LinkBlocklist.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            hits += LinkBlocklist.hits(in: text, entries).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits, [], "blocklisted links in the app's bundled data")
    }

    /// The guard fires on a copy of the bundled data broken three ways: a blocklisted domain, its subdomain, and a "url" entry.
    func testBlocklistGuardCatchesABrokenCopy() throws {
        let entries = try LinkBlocklist.entries()
        let file = try XCTUnwrap(LinkBlocklist.bundledJSON().max { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 < (try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 })
        let text = try String(contentsOf: file, encoding: .utf8)
        let domain = try XCTUnwrap(entries.first { ($0["match"] as? String ?? "domain") == "domain" }?["domain"] as? String)
        let fake: [[String: Any]] = entries + [["match": "url", "url": "https://example.org/hacked-page"]]
        let before = LinkBlocklist.hits(in: text, fake).count
        let broken = text + "{\"w\":\"https://www.\(domain)/menu\"}{\"src\":\"http://shop.\(domain)/\"}{\"w\":\"https://example.org/hacked-page/\"}"
        XCTAssertEqual(LinkBlocklist.hits(in: broken, fake).count, before + 3, "a domain, a subdomain and a url entry are all caught")
        XCTAssertEqual(LinkBlocklist.hits(in: "{\"w\":\"https://not\(domain)/\"}", entries), [], "a host that only ends with the domain's letters isn't it")
    }
}

enum LinkBlocklist {
    static func entries() throws -> [[String: Any]] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("pipeline/website_blocklist.json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
    }

    /// every .json file in the app bundle, subfolders included
    static func bundledJSON() -> [URL] {
        let root = Bundle.main.bundleURL
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { $0.pathExtension == "json" && !$0.path.contains("/PlugIns/") }
    }

    private static func host(_ u: URLComponents) -> String {
        var h = (u.host ?? "").lowercased()
        if h.hasSuffix(".") { h.removeLast() }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    private static func trimmedPath(_ p: String) -> String { p.hasSuffix("/") ? String(p.dropLast()) : p }

    /// the links in a JSON text that an entry covers: a "domain" entry its domain and subdomains, a "url" entry that page only
    static func hits(in text: String, _ entries: [[String: Any]]) -> [String] {
        let t = text.replacingOccurrences(of: "\\/", with: "/")
        let rx = try! NSRegularExpression(pattern: #"https?://[^"\s\\]+"#, options: [.caseInsensitive])
        return rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> String? in
            let s = String(t[Range(m.range, in: t)!])
            guard let u = URLComponents(string: s) else { return nil }
            let h = host(u)
            for e in entries {
                if (e["match"] as? String ?? "domain") == "url" {
                    guard let v = URLComponents(string: e["url"] as? String ?? "") else { continue }
                    if !h.isEmpty && h == host(v) && trimmedPath(u.path) == trimmedPath(v.path) { return s }
                } else {
                    var d = (e["domain"] as? String ?? "").lowercased()
                    if let r = d.range(of: "://") { d = String(d[r.upperBound...]) }
                    d = String(d.split(separator: "/").first ?? "")
                    if d.hasPrefix("www.") { d = String(d.dropFirst(4)) }
                    if !d.isEmpty && (h == d || h.hasSuffix("." + d)) { return s }
                }
            }
            return nil
        }
    }
}

/// QA 2026-10-19, P1 3a: the support address is nick@eatsranked.com (Nick, 2026-10-12). The old Gmail address must not come back
/// anywhere in the app's source or bundled files.
final class SupportEmailTests: XCTestCase {
    func testSupportEmailIsEatsRanked() {
        XCTAssertEqual(Links.supportEmail, "nick@eatsranked.com")
    }

    func testNoGmailInAppSource() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("AlaskaEats")
        XCTAssertGreaterThan(SupportEmailScan.textFiles(under: root).count, 5, "the app's source folder wasn't found")
        XCTAssertEqual(SupportEmailScan.hits(under: root), [], "the app's source still has a Gmail address")
    }

    /// The guard fires on a broken copy: a folder with one planted Gmail address.
    func testGmailGuardCatchesABrokenCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("App"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "static let supportEmail = \"someone@GMAIL.com\"\n".write(to: dir.appendingPathComponent("App/Links.swift"), atomically: true, encoding: .utf8)
        try "{\"ok\": \"nick@eatsranked.com\"}".write(to: dir.appendingPathComponent("App/data.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(SupportEmailScan.hits(under: dir), ["App/Links.swift"])
    }
}

enum SupportEmailScan {
    static let textExtensions: Set<String> = ["swift", "plist", "json", "strings", "xcstrings", "xcprivacy", "md", "txt", "html", "entitlements"]

    static func textFiles(under root: URL) -> [URL] {
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { textExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// paths (relative to root) of text files that mention gmail.com, in any case
    static func hits(under root: URL) -> [String] {
        let base = root.resolvingSymlinksInPath().path + "/"
        return textFiles(under: root).compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.range(of: "gmail.com", options: .caseInsensitive) != nil else { return nil }
            return url.resolvingSymlinksInPath().path.replacingOccurrences(of: base, with: "")
        }.sorted()
    }
}

/// QA 2026-10-19, P1 #13: outbound links ship without tracking tags (ref=google, referrer=google_food_ordering, cn_channel, utm_* …).
/// pipeline/tracking_params.py strips them in the export; these are the same rules.
final class TrackingParamTests: XCTestCase {
    func testNoTrackingParametersInBundledLinks() throws {
        let files = TrackingParams.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            hits += TrackingParams.tracked(in: text).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits, [], "links with tracking parameters in the app's bundled data")
    }

    /// The guard fires on a broken copy (four kinds of tracking tag, one in escaped JSON) and leaves a store's own parameters alone.
    func testTrackingGuardCatchesABrokenCopy() {
        let broken = #"[{"w":"https:\/\/places.example.com\/menu?ref=google"},{"w":"https://a.example/?utm_source=gmb&store=4"},"#
            + #"{"w":"https://b.example/x?referrer=google_food_ordering"},{"w":"https://c.example/order/1?cn_channel=cn_google"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: broken).count, 4)
        let clean = #"[{"w":"https://order.example.com/menu?restaurantId=51&location=7"},{"w":"https://shop.example.com/?cid=12&ref=gs"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: clean), [])
    }
}

enum TrackingParams {
    /// tracking by name, whatever the value
    static let keys = try! NSRegularExpression(pattern: #"^(?:utm[_-].*|gclid|gbraid|wbraid|dclid|fbclid|msclkid|mc_cid|mc_eid|_ga|_gl|igsh|"#
        + #"igshid|mibextid|srsltid|cn_channel|y_source|rwg_token|olonwp|ost_redirect_attribution|cmpid|yext_?.*)$"#, options: [.caseInsensitive])
    /// tracking only with these values
    static let values: [String: String] = ["ref": #"^(?:google|gmb|gbp|yext|bookmarks)\b"#, "referrer": "^google",
                                           "source": #"^(?:google|gmb|gbp|yext)\b"#, "cid": "^RF:YXT", "cmp": "^OKC-"]

    /// every .json file in the app bundle, subfolders included
    static func bundledJSON() -> [URL] {
        let all = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { $0.pathExtension == "json" && !$0.path.contains("/PlugIns/") }
    }

    static func isTracking(_ key: String, _ value: String) -> Bool {
        let k = key.trimmingCharacters(in: .whitespaces)
        if keys.firstMatch(in: k, range: NSRange(k.startIndex..., in: k)) != nil { return true }
        guard let pattern = values[k.lowercased()] else { return false }
        return value.trimmingCharacters(in: .whitespaces).range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// links in a JSON text whose query carries a tracking parameter
    static func tracked(in text: String) -> [String] {
        let t = text.replacingOccurrences(of: "\\/", with: "/")
        let rx = try! NSRegularExpression(pattern: #"https?://[^\s"'<>\\]+"#)
        return rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> String? in
            let s = String(t[Range(m.range, in: t)!])
            guard let q = s.split(separator: "?", maxSplits: 1).dropFirst().first else { return nil }
            let query = q.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            for part in query.split(separator: "&") {
                let kv = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let k = String(kv[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[0])
                let v = kv.count > 1 ? (String(kv[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[1])) : ""
                if isTracking(k, v) { return s }
            }
            return nil
        }
    }
}
