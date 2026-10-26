import SwiftUI
import MapKit

struct PlaceDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location
    let place: Place

    @State private var mapItem: MKMapItem?
    @State private var lookingUp = false
    @State private var notOnAppleMaps = false
    @State private var appleMapsFailed = false
    /// Anchorage permit and liquor licenses, inspection history, phone and website, from the place's region file (read when it opens)
    @State private var detail: PlaceDetail?
    @State private var detailLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                actions
                if let c = place.coordinate { mapSnippet(c) }
                if place.handChecked && (place.note != nil || place.dishes != nil || place.founded != nil || place.seasonal != nil) { checked }
                if place.hasHonors { honors }
                inspections   // Anchorage's score before the permit numbers, as on the web
                records
                listing
            }
            .padding(16)
        }
        .background(Theme.surface)
        .inlineTitle(place.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.toggleSaved(place) } label: {
                    Label(model.isSaved(place) ? "Saved" : "Save", systemImage: model.isSaved(place) ? "heart.fill" : "heart")
                }
                .accessibilityIdentifier("saveHeart")   // the Saved tab is also a "Saved" button
                ShareLink(item: Links.share(place), subject: Text(place.name), message: Text(Links.shareMessage(place))) { Label("Share", systemImage: "square.and.arrow.up") }
            }
        }
        .task(id: place.id) {
            detailLoaded = false
            detail = await model.detail(for: place)
            detailLoaded = true
        }
        .mapItemDetailSheet(item: $mapItem)
        .alert("Not on Apple Maps", isPresented: $notOnAppleMaps) {
            Button("Open Apple Maps anyway") { AppleMaps.openInMaps(place) }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple Maps doesn't have a listing for \(place.name) at this spot, so there are no ratings or hours to show here.")
        }
        .alert("Couldn't reach Apple Maps", isPresented: $appleMapsFailed) {
            Button("Try again") { lookUp() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    /// Apple's place card for this place; "not on Apple Maps" only when Apple answered and had no listing here.
    private func lookUp() {
        lookingUp = true
        Task {
            let result = await AppleMaps.findItem(for: place)
            lookingUp = false
            switch result {
            case .found(let item): mapItem = item
            case .notListed: notOnAppleMaps = true
            case .failed: appleMapsFailed = true
            }
        }
    }

    // MARK: sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "HOMER · KENAI PENINSULA BOROUGH" (the data's area names already say Borough, Census Area or Municipality)
            Text((place.city ?? "Alaska").uppercased() + (place.county.map { " · " + $0.uppercased() } ?? ""))
                .monoFont(12).tracking(0.4).foregroundStyle(Theme.green2)
            Text(place.name.uppercased())
                .displayFont(38).foregroundStyle(Theme.green)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text([place.fullAddress, place.cuisine].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(Theme.ink2)
                .textSelection(.enabled)
            if let here = model.screenshotLocation ?? location.location, let l = place.location {
                Text("\(here.milesText(to: l)) away").font(.subheadline).foregroundStyle(Theme.muted)
            }
            PlaceChips(place: place)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { lookUp() } label: {
                HStack {
                    if lookingUp { ProgressView().tint(.white) } else { Image(systemName: "star.bubble") }
                    Text("Ratings, hours & photos").fontWeight(.semibold)
                    Spacer()
                    Text("Apple Maps").font(.caption).foregroundStyle(Theme.goldSoft)
                }
                .padding(14)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.green))
            }
            .disabled(place.coordinate == nil || lookingUp)
            .accessibilityHint("Opens the Apple Maps place card with current ratings and hours")

            HStack(spacing: 10) {
                actionButton("Directions", "arrow.triangle.turn.up.right.diamond") { AppleMaps.openInMaps(place, directions: true) }
                if let phone = detail?.ph, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                    actionButton("Call", "phone") { UIApplication.shared.open(url) }
                }
                if let web = detail?.website {
                    actionButton("Website", "safari") { UIApplication.shared.open(web) }
                }
            }
        }
    }

    private func actionButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(Theme.green)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule2))
        }
    }

    private func mapSnippet(_ c: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: c, latitudinalMeters: 900, longitudinalMeters: 900)), interactionModes: []) {
            Marker(place.name, systemImage: "fork.knife", coordinate: c).tint(Theme.green)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { AppleMaps.openInMaps(place) }
        .accessibilityLabel("Map of \(place.name). Opens Apple Maps.")
        .accessibilityAddTraits(.isButton)
    }

    private var checked: some View {
        section("Hand-checked") {
            VStack(alignment: .leading, spacing: 8) {
                if let note = place.note { Text(note).font(.subheadline).foregroundStyle(Theme.ink2) }
                if let d = place.dishes { fact("On the menu", d.components(separatedBy: "; ").joined(separator: ", ")) }
                if let f = place.founded {
                    fact("Open here since", "\(f)")
                    // the note explains the year; without a year it only repeated the description above
                    if let fn = place.foundedNote { Text(fn).font(.caption).foregroundStyle(Theme.ink2) }
                }
                if let sea = place.seasonal { fact("Season", sea) }
                Text("Checked by hand: a 2025 or 2026 source names it (the place's own site, local news or a tourism listing), or an older one does and it holds an active Anchorage food permit. Many Alaska places open only in summer, and food trucks move, so check before you go.")
                    .font(.caption).foregroundStyle(Theme.ink2)
            }
        }
    }

    private var honors: some View {
        section("Honors") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines(place.jamesBeard, prefix: "James Beard: "), id: \.self) { l in
                    Label(l, systemImage: "rosette").font(.subheadline).foregroundStyle(Theme.ink)
                }
                Text("Honors are facts, not ratings. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    /// Anchorage's own scores where the department published them; elsewhere, say plainly that DEC publishes none in bulk.
    @ViewBuilder
    private var inspections: some View {
        if let i = place.inspection {
            section("Health inspections · Anchorage") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(i.score)").monoFont(34, weight: .bold).foregroundStyle(Theme.green)
                        Text("out of 100 · \(DayFormat.text(i.d) ?? i.d)").font(.subheadline).foregroundStyle(Theme.ink2)
                    }
                    .accessibilityElement(children: .combine)
                    if let s = model.step(i.step) { HStack { Text("Next step").font(.subheadline).foregroundStyle(Theme.ink2); Spacer(); StepBadge(step: s) } }
                    if let h = detail?.inspection?.h, h.count > 1 {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(h.prefix(8).enumerated()), id: \.offset) { _, v in
                                Text([DayFormat.text(v.d) ?? v.d, model.itype(v.t), "\(v.score)/100", model.step(v.step)?.label].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(Theme.ink2)
                            }
                        }
                    }
                    if let v = detail?.inspection?.v, !v.isEmpty {
                        Text("Cited at this visit: " + v.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: "; ") + ".")
                            .font(.caption).foregroundStyle(Theme.ink2)
                    }
                    Text(Inspections.scale + " Shown as the \(Inspections.agency) published it; we compute no grade. " + inspectionsSource)
                        .font(.caption).foregroundStyle(Theme.muted)
                    Link(destination: detail?.inspection?.reportURL ?? Inspections.lookupURL) {
                        Label("Full reports on the department's site", systemImage: "arrow.up.right.square").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.green2)
                }
            }
        } else {
            section("Health inspections") {
                Text(place.county == "Anchorage Municipality"
                     ? "No scored inspection matched this place in the Anchorage Health Department's file. Its own lookup has every permitted place."
                     : "Outside Anchorage the Alaska Department of Environmental Conservation inspects restaurants, but it publishes no results in bulk and its site doesn't allow apps to read it, so this app shows none.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    private var inspectionsSource: String {
        var out = "Source: the department's inspection file (Municipality of Anchorage Open Data)"
        if let t = DayFormat.text(model.inspectionsThrough) { out += ", records through \(t)" }
        if let m = DayFormat.text(model.inspectionsFileModified) { out += "; the file hasn't been updated since \(m), so newer visits are only on the department's site" }
        return out + "."
    }

    private var records: some View {
        section("Official records") {
            VStack(alignment: .leading, spacing: 8) {
                let ls = detail?.licenses ?? []
                ForEach(ls, id: \.self) { l in
                    kv(l.source + (l.id.map { " " + Self.unbroken($0) } ?? ""),
                       l.type + (l.expires.map { ", expires " + $0 } ?? ""))
                }
                if ls.isEmpty {
                    kv("Permit or license", detailLoaded ? (place.county == "Anchorage Municipality" ? "— (none matched)" : "— (only Anchorage's are published)") : "…")
                }
                kv("Serves alcohol", place.servesAlcohol ? "Yes (Anchorage liquor license)" : "—")
                Text(recordsNote).font(.caption).foregroundStyle(Theme.muted)
                Link(destination: Links.anchorageData) {
                    Label("Anchorage's open data", systemImage: "arrow.up.right.square").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.green2)
            }
        }
    }

    private var listing: some View {
        section("How we know it's here") {
            VStack(alignment: .leading, spacing: 8) {
                kv("Listed as", place.tier.label)
                if place.tier == .licensed { kv("Official record", "Anchorage food permit or liquor license") }
                if place.chainCount >= 2 { kv("Locations in Alaska", place.chainCount.formatted()) }
                Text(listingNote).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    /// "123456", never broken across lines
    private static func unbroken(_ id: String) -> String { id.replacingOccurrences(of: "-", with: "\u{2011}") }

    /// Where the records come from; a missing record is unknown, not "no".
    private var recordsNote: String {
        let read = DayFormat.text(model.licensesUpdated) ?? model.liquorUpdated
        return "Only the Municipality of Anchorage publishes its records: the Health Department's food permits (from its inspection file) and the Clerk's list of liquor licenses (published \(read)), with the license type and expiration year. Outside Anchorage the state's permit and license lists aren't open to apps, so a missing record means unknown, not unlicensed. Dry and damp communities never show \"No\": only \"—\"."
    }

    private var listingNote: String {
        let checked = place.handChecked
        if place.source == "research" {
            return "On our hand-checked list (checked against a 2025 or 2026 source). The open map data didn't list it as a place to eat, so it's placed from its own map listing or street address."
        }
        switch place.tier {
        case .licensed:
            return place.source == "official"
                ? "From the Municipality of Anchorage's records. The open map data didn't have it, so it's placed on its permitted street address."
                : "Matched to an active Anchorage food permit or liquor license."
        case .confirmed, .listing:
            let rate = model.matchRate(for: place)
            let base = place.tier == .confirmed
                ? "A high-confidence listing in Overture's open map data."
                : "A single listing in Overture's open map data, so it may be closed, seasonal or misfiled."
            let measured = rate.map { " In Anchorage, where every food business needs a health permit, listings like this matched one \($0) of the time." } ?? ""
            return base + measured + (checked ? " It's also on our hand-checked list, checked against a 2025 or 2026 source." : "")
        }
    }

    // MARK: helpers

    private func lines(_ s: String?, prefix: String) -> [String] {
        (s ?? "").components(separatedBy: "; ").filter { !$0.isEmpty }.map { prefix + $0 }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.ink2)
            Divider()
            content()
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(value).font(.subheadline).foregroundStyle(Theme.ink2)
        }
    }

    @ViewBuilder
    private func kv(_ k: String, _ v: String?) -> some View {
        if let v {
            HStack(alignment: .firstTextBaseline) {
                Text(k).font(.subheadline).foregroundStyle(Theme.ink2)
                Spacer(minLength: 12)
                Text(v).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
            }
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
