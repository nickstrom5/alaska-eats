# Alaska sources (checked 2026-10-26)

Every host was checked against its robots.txt first (`pipeline/check_sources.py`, cache in `data/research/source_hosts.json`). Nothing
behind a bot check was fetched by script. Official coverage is **Anchorage only** until Nick gets a statewide list by hand or by request.

## Official records

### Anchorage Health Department: food permits and inspection scores (used)
- **URL:** `https://opendata.muni.org/LIVES/LIVES-flat.csv`, linked as "2026 Restaurant Health Inspection Data - CSV" from
  muni.org/Departments/it/Pages/opendata.aspx. robots.txt: none (404), so nothing is disallowed.
- **Terms:** none posted on the Open Data page or the file. It is the Municipality's public record, published for download.
- **Fields:** business_id (facility id FA… plus its Envision Connect link), name, address, city, zip, lat/lon (1,300 of 1,942 facilities;
  the rest are placed on Overture address points, 169 still unplaced), phone, inspection id/date/score/type/description, violation
  id/description/code. `inspection_result` and `violation_critical` are empty in every row.
- **Coverage:** 25,287 inspections of 1,942 facilities (restaurants, bars, coffee stands, mobile units, store departments, schools, child
  care, care homes, hotel pools and spas), 2000-01-03 to 2026-05-18. The Municipality only: Anchorage, Eagle River, Chugiak, Girdwood,
  Indian, JBER.
- **Scores:** only Regular, Reinspection and Enforcement inspections carry one (16,106 inspections; 63–100). Envision Connect shows the
  same visits as "Score: 99%" with "Points: - 1" per cited item, so the score is points kept out of 100, as published. We show it as
  the department's, with its date and the department's next step for that visit (`inspection_description`: "Schedule regular
  inspection within 12 months", "Reinspection required within 6 months", "Enforcement inspection required", "Closed facility"…), and
  compute nothing of our own. There is no pass/fail line in the data, so there is no band or grade. AMC 16.60 (the food code) is cited
  on Envision's violation text; the section that sets the scoring method isn't confirmed here (ecode360.com, where the current code
  lives, disallows Claude in robots.txt).
- **Freshness, and why it stalled:** nothing is newer than 2026-05-18; the CSV's Last-Modified is 2026-05-19 07:00 GMT (fetched
  2026-10-26), while the child-care CSV beside it was modified 2026-10-26. The ArcGIS layer `Restaurants_Inspected_Hosted`
  (services2.arcgis.com/Ce3DhLRthdwbHlfF) carries PUBDATE 2026-10-19, so it is republished weekly, but its latest inspection is also
  2026-05-18. Envision Connect (anchorageonline.envisionconnect.com, the department's own lookup) shows inspections after that: 907
  Alehouse & Grill's regular inspection of **June 3, 2026** (99%) is on Envision and not in the file. So the department kept inspecting
  and only the open-data export stopped. Fixing it is the Municipality's (OIT open data / Environmental Health, 907-343-4200,
  AHDEnvironmentalHealth@anchorageak.gov). We show "records through 2026-05-18" from data meta everywhere.
- **Gaps inside the file:** some open places have no recent record at all, so a missing score means the file has none, not that the
  place went uninspected or closed. Lucky Wishbone (a 2025 James Beard America's Classic, open) has no inspection after 2019, and
  Kincaid Grill none after 2023. Hand-checked places therefore never rely on the file alone to be called open, and the app says "No
  scored inspection matched this place in the Anchorage Health Department's file. Its own lookup has every permitted place."
- **Envision Connect links:** each facility's page (`…/#/pa1/detail/FA…/PR…`) renders in a browser (a JS app; checked by opening four
  pages once each, 2026-10-26). Safe to link as "full reports"; never scraped.
- **Cleanup** (`pipeline/official.py`): the file has no facility type, so kinds come from the name. Schools, child care, care homes,
  shelters, hospitals, jails, pools/spas/hot tubs, cannabis shops and the like are "other"; store departments ("CARRS #2628 - DELI",
  "SPEEDWAY - SNACK", Carrs's in-store "Orient Express") are "retail", except a Starbucks inside a store; mobile and temporary permits
  ("- MOBILE", "- S", "(TRUCK)") carry the department's own address (825 L St) and are never placed from the permit. A permit is active
  when the department saw it within two years before the file ends and its last visit didn't close it: 725 active fixed food permits.

### Municipality of Anchorage, Clerk: liquor licenses (used)
- **URL:** ArcGIS Online layer `LiquorLicenses_Hosted/FeatureServer/0` (services2.arcgis.com/Ce3DhLRthdwbHlfF), "MOA Clerk approved
  liquor licenses. Does not reflect status of AMCO Licenses"; copyright "GDIC, City Clerk". PUBDATE 2026-10-25 (republished daily).
  ArcGIS Online's REST API is a documented API (its robots.txt answers 403 "Invalid URL", not a bot check).
- **Fields:** license number, establishment, license type, community council, service location (geocoded), Owner (never read into our
  data), expiration year, endorsements (RE = restaurant endorsement, PST, MFC…).
- **Coverage:** 501 licenses, 497 with a premises. Types as the layer spells them: Beverage Dispensary (incl. Tourism and Duplicate),
  Restaurant/Eating Place, Package Store, Club, Brewery/Winery/Distillery (manufacturing), Sporting Event, Golf Course, Theater,
  University Pub, Wholesale. Active = expiration year 2026 or later.
- **"Serves alcohol":** Beverage Dispensary → beer, wine, spirits; Restaurant or Eating Place → beer and wine with meals; maker → its
  own product; Package Store → to go only (not "serves"). Unknown is "—", never "No", and outside Anchorage it's always "—" (dry and
  damp local-option communities included).

### Anchorage property values (not used)
- `opendata.muni.org/CAMA/CAMACommercial.csv` (2026 CAMA, Last-Modified 2026-10-24). No terms posted. Anchorage-only, and the other
  boroughs publish under their own terms; the Unorganized Borough levies no property tax. Left out for now; an Anchorage-only,
  labeled building-value board on the web leaderboard is possible later (owners hidden) if Nick wants it.

### Not reachable by script (never scraped)
- **DEC Food Safety & Sanitation** (dec.alaska.gov/eh/fss/inspections/, the active retail permit list at
  dec.alaska.gov/eh/fss/active-permits-retail, and cms.dec.alaska.gov): DataDome / bot check on every request from our honest user
  agent. DEC inspects every retail food establishment outside Anchorage. Search results describe its reports as risk-factor-first with
  corrected-on-site (COS) and repeat (R) marks; whether they carry any score could not be confirmed without opening the site, so any
  grade from DEC data would be "our grade, not an official grade". Records before August 2017 aren't online (DEC's own note).
  **Ask Nick:** request a bulk inspection extract and the active retail permit list under the Public Records Act (AS 40.25).
- **DCCED business licenses** (the "Active Business License CSV" on commerce.alaska.gov, and the monthly ArcGIS layer
  maps.commerce.alaska.gov/server/rest/services/Economics_Related/Business_Licenses/MapServer/2): both answer our script with a DataDome
  403 ("AI Threats Detection", 2026-10-26), so the layer is no longer script-reachable either. **Ask Nick:** download the CSV by hand
  from the state geoportal; it would be the statewide existence check (NAICS 722xxx if present; hide owners and legal names).
- **AMCO liquor licenses statewide** (AK-ACCIS, accis.elicense365.com/Apps/LicenceSimpleSearch/): robots.txt none; the page posts no
  terms. It's an interactive search (Kendo grid) with an "Export to Excel" button. **Ask Nick:** export it in a browser (by him, or in the
  built-in browser with his OK, since it's a download). commerce.alaska.gov/web/amco itself is behind the bot check.

## Map listings, boundaries and the 2021 snapshot
- **Overture Maps places**, release 2026-10-21.0 (CDLA-Permissive-2.0 / Apache-2.0, Foursquare NOTICE). Alaska crosses the 180th
  meridian, so the extract uses two longitude ranges (172°E–180° and 180°–129.8°W) and writes longitudes past 180° as lon − 360.
  3,681 eating and drinking listings tagged Alaska (or untagged) inside the state; Meta 2,523, Foursquare 459, BrightQuery 255,
  Microsoft 183, chain feeds 64.
- **US Census Bureau boundaries** (public domain): TIGER/Line 2024 state polygon (it runs to the 3-nautical-mile line, so docks and spits
  are inside while Stewart, B.C., the Yukon and Big Diomede are out; it agrees with an Overture-outline-plus-2-km test on every one of
  3,659 listings), 2024 cartographic boundary files for the 30 boroughs/census areas and the 355 cities and CDPs. Towns come from where
  a place sits, not its mailing town (`pipeline/towns.py`).
- **Google 2021 snapshot** (UCSD Google Local, `meta-Alaska.json.gz`, 12,774 listings): web leaderboard only, labeled "2021".

## Calibration (Anchorage, `data/ak/calibration.json`)
Every food business in Anchorage needs a health permit, so the share of each kind of map listing that matches an active permit or
on-premises liquor license is close to a real "working business" rate there (Oregon's liquor-only check was a floor).

| Kind of listing (web grouping) | Listings | Matched |
|---|---|---|
| Meta + open in Google 2021 | 524 | 74.8% |
| Meta only | 385 | 30.9% |
| Foursquare/BrightQuery/Microsoft + Google 2021 | 100 | 29.0% |
| Microsoft only | 37 | 24.3% |
| BrightQuery only | 100 | 8.0% |
| Foursquare only | 109 | 5.5% |
| Google 2021 says closed | 53 | 1.9% |
| Overture says closed | 59 | 0.0% |

App grouping (no Google): Meta ≥ 0.95 confidence 72.8% of 591; Meta 0.90–0.95 41.0% of 161; Meta < 0.90 9.8% of 164; chain feeds 44.4%
of 18; BrightQuery ≥ 0.95 13.0%; other sources 14.7%. Coverage the other way: the open map listings held **69.8%** of Anchorage's 613
permitted fixed food businesses; the rest are added from the permits. Rules picked from these numbers: the app keeps Meta ≥ 0.95, Meta
≥ 0.90 with a website, chain feeds, records and hand-checked places; the web build also drops Meta < 0.90 without a second source
(Idaho's rule; 9.8% here). Census County Business Patterns 2023 counts 1,718 NAICS 722 employer establishments; the web build has
2,093 restaurants and the app 1,906 (map listings include seasonal places, food trucks and espresso stands with no employer record).

## Honors
- **MICHELIN Guide:** no Alaska restaurant (per the prompt's September 2026 check; guide.michelin.com answers our checker with an AWS WAF
  bot check, so it isn't re-verified here). Its only Alaska listings are hotels (Stillpoint Lodge, Two MICHELIN Keys; Aurora Villa;
  Kenai Peninsula Suites), which aren't restaurant honors. No Bib Gourmand filter.
- **James Beard** (jamesbeard.org, usable; `data/research/jbf.json`): Lucky Wishbone, America's Classic 2025; In Bocca al Lupo (Beau
  Schooler), Best Chef: Northwest and Pacific finalist 2025; The Cookery (Kevin Lane, Seward), semifinalist 2025; Altura Bistro (Nathan
  Bentley) finalist 2026; Fire Island Rustic Bakeshop, Outstanding Bakery finalist 2026; Whisky & Ramen (Mike Dodge) semifinalist 2026;
  Tutka Bay Lodge, Outstanding Hospitality semifinalist 2026. No Alaska winner in 2025 or 2026 (Wastell, Antica Terra; Roadhouse,
  Nodoguro; Wild Crumb won those categories).

## Press and guide hosts for the hand-checked research
- Blocked for Claude (robots.txt): adn.com, alaskasnewssource.com, alaskapublic.org, newsminer.com, ktuu.com, ecode360.com. Bot check:
  travelalaska.com, dec.alaska.gov, commerce.alaska.gov, guide.michelin.com, library.municode.com.
- Usable: jamesbeard.org, anchorage.net (Visit Anchorage), ktoo.org, juneauempire.com, kdll.org, homernews.com, alaskafromscratch.com,
  places' own sites.
- Cited in the shipped research (`data/research/app/alaska.json`, `jbf.json`; every one passed `check_sources.py`): jamesbeard.org (13),
  the Anchorage permit file on opendata.muni.org (11, for the "older source plus an active permit" rule), alaska.org (2),
  traveljuneau.com, and the places' own sites (manleyroadhouse.com, sheepmountain.com, hulahands.com, pholena.com, simonandseaforts.com,
  akchowder.com, alaskafishhouse.com, sewardhospitalitygroup.com, ihohak.com, redumbrellareindeer.com, kennicottlodge.com,
  jeepney907.com, jinmi-korean.com, luckywishbonealaska.com, doublemuskyinn.com).
