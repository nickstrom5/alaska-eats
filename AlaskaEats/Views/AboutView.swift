import SwiftUI

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALASKA EATS").displayFont(32).foregroundStyle(Theme.green)
                    Text("A free guide to \(model.restaurantCount.formatted()) Alaska restaurants, with hand-checked lists of Alaska's own food (halibut, salmon and king crab, reindeer dogs, sourdough, roadhouses and lodges, Anchorage's Filipino, Korean, Hawaiian, Polynesian and Lao kitchens, the oldest places), James Beard honors, and Anchorage's own inspection scores. No account, no ads, no tracking.")
                        .font(.subheadline).foregroundStyle(Theme.ink2)
                    Text("Alaska Eats is an independent app by Nicholas Soderstrom. It is not affiliated with, endorsed by or operated by the State of Alaska, the Alaska Department of Environmental Conservation, the Alcohol and Marijuana Control Office, the Municipality of Anchorage or its Health Department, Travel Alaska, the James Beard Foundation, Apple, or any restaurant or chain. Other names are trademarks of their owners.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 4)
            }
            Section("How the lists are built") {
                Text("The seafood, reindeer dog, sourdough, roadhouse, global-kitchen and oldest-places lists are hand-checked: a 2025 or 2026 source names each place (the place's own site, local news or an official tourism listing), or an older one does and the place holds an active Anchorage food permit. Addresses are checked too. Founding years mean the year it opened at this address. Many places open only in summer; they stay listed year-round.")
                Text("Honors are James Beard Foundation awards and nominations from 2025 and 2026, plus America's Classics. The MICHELIN Guide covers no Alaska restaurant.")
                Text("Places start from open map listings (Overture Maps). In Anchorage, where every food business needs a health permit, listings were checked against the Health Department's permits and the Clerk's liquor licenses: listings that match are marked official, and permitted places the map data missed are added. High-confidence listings matched a permit or license \(rate("meta_high")) of the time there, and the app keeps the kinds of listing that proved reliable statewide. Map listings are thin off the road system, so a village with nothing here may still have a café. Places on military bases, adult clubs and store counters are left out or listed with the non-restaurants. Website links are checked, and any that no longer belong to the place are left out.")
                Text("Anchorage's places show the Health Department's own inspection score and next step, as published; the app computes no grade. Outside Anchorage the state DEC inspects restaurants but publishes no results in bulk, so there are none.")
                Text("Ratings, reviews, hours and photos are Apple Maps' own, shown live in Apple's place card. This app doesn't store or rank by them.")
            }
            .font(.subheadline).foregroundStyle(Theme.ink2)
            Section("Sources") {
                source("Anchorage Health Department", "Restaurant Health Inspection Data (Municipality of Anchorage Open Data), the scored inspections of the last three years\(DayFormat.text(model.inspectionsThrough).map { ", through \($0)" } ?? "")\(DayFormat.text(model.inspectionsFileModified).map { "; the file hasn't been updated since \($0)" } ?? ""). Scores, dates and next steps as the department published them; permits from the same file. For a facility's full reports, see the department's own lookup.", Links.anchorageData.absoluteString)
                source("Municipality of Anchorage, Clerk's Office", "Approved liquor licenses (the Municipality's ArcGIS layer, published \(DayFormat.text(model.licensesUpdated) ?? model.liquorUpdated)), with the license type and expiration year. It doesn't reflect the status of state AMCO licenses. Licensee names are left out.", nil)
                source("U.S. Census Bureau", "Town and borough boundaries (2024 TIGER/Line and cartographic boundary files), public domain, used to name each place's town and area.", "https://www.census.gov/geographies/mapping-files.html")
                source("Overture Maps Foundation", "Restaurant listings and websites come from Overture Maps Foundation places data (overturemaps.org)\(model.overtureRelease.map { ", release \($0)" } ?? ""), filtered and reformatted for this app.\n• Data from Meta, Microsoft, DAC and BrightQuery. Available under CDLA Permissive 2.0.\n• Data from Foursquare. \(foursquareCopyright) Available under Apache 2.0. Foursquare data was transformed to the Overture schema; this app further filtered and reformatted it. See the NOTICE below.\n• Data from AllThePlaces. Available under CC0 1.0.", "https://overturemaps.org")
                source("Honors", "James Beard Foundation awards, finalists, semifinalists and America's Classics are reported as facts and checked by hand against the Foundation's announcements. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation. Other names belong to their owners.", "https://www.jamesbeard.org/awards")
                source("Maps", "Maps, place cards and directions by Apple Maps.", nil)
            }
            Section("Licenses") {
                NavigationLink("Community Data License Agreement – Permissive 2.0") { LicenseText(file: "CDLA-Permissive-2.0", title: "CDLA Permissive 2.0") }
                NavigationLink("Apache License 2.0") { LicenseText(file: "Apache-2.0", title: "Apache License 2.0") }
                NavigationLink("Foursquare OS Places NOTICE") { LicenseText(file: "Foursquare-NOTICE", title: "Foursquare NOTICE") }
            }
            Section("Privacy") {
                Text("The app collects nothing. Your location, if you allow it, only sorts lists by distance and shows where you are on the map, on this device. Saved places stay on this device.")
                    .font(.subheadline).foregroundStyle(Theme.ink2)
                Link("Privacy policy", destination: Links.privacy)
                Link("Terms of use", destination: Links.terms)
            }
            Section("Help") {
                Link("Report a missing or closed place", destination: Links.correctionEmail)
                Link("Email \(Links.supportEmail)", destination: URL(string: "mailto:\(Links.supportEmail)")!)
                Link("Website", destination: Links.site)
                Text("Data as of \(DayFormat.text(model.generated) ?? model.generated). Places open and close; check before you go. Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .navigationTitle("About")
        .tint(Theme.green)
    }

    /// the copyright line exactly as the bundled Foursquare NOTICE has it, so the two can't disagree
    private var foursquareCopyright: String {
        guard let url = Bundle.main.url(forResource: "Foursquare-NOTICE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let line = text.split(separator: "\n").first(where: { $0.hasPrefix("©") }) else { return "© Foursquare Labs, Inc. All rights reserved." }
        return line.trimmingCharacters(in: .whitespaces)
    }

    private func rate(_ group: String) -> String {
        let v = model.calibration.areas.values.compactMap { $0.groups[group]?.official }.map { Int(($0 * 100).rounded()) }.sorted()
        guard let lo = v.first, let hi = v.last else { return "most" }
        return lo == hi ? "\(lo)%" : "\(lo)–\(hi)%"
    }

    @ViewBuilder
    private func source(_ name: String, _ detail: String, _ url: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let url, let u = URL(string: url) { Link(name, destination: u).font(.subheadline.weight(.semibold)) }
            else { Text(name).font(.subheadline.weight(.semibold)) }
            Text(detail).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

/// A bundled license text (Resources/Licenses), reflowed rather than shown as raw 80-column lines.
struct LicenseText: View {
    let file: String
    let title: String

    var body: some View {
        ScrollView {
            Text(text).font(.footnote).foregroundStyle(Theme.ink).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
        }
        .inlineTitle(title)
    }

    private var text: String {
        guard let url = Bundle.main.url(forResource: file, withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return "License text missing." }
        // join hard-wrapped lines into paragraphs; keep blank lines and list items as breaks
        var out: [String] = []
        for para in raw.components(separatedBy: "\n\n") {
            let lines = para.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            var joined = ""
            for l in lines where !l.isEmpty {
                let startsItem = l.hasPrefix("–") || l.hasPrefix("-") || l.range(of: #"^\(?[a-z0-9]{1,3}[.)]\s"#, options: .regularExpression) != nil
                joined += joined.isEmpty ? l : (startsItem ? "\n" + l : " " + l)
            }
            if !joined.isEmpty { out.append(joined) }
        }
        return out.joined(separator: "\n\n")
    }
}
