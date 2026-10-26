"""Writes data/research/app/*.json (hand-checked Oregon guides), data/research/jbf.json, data/research/app/closed_research.json and
data/research/adult_venues.json from the compact lists below.

Each entry cites the page that names it (a robots-checked host: check_sources.py). A page dated 2025-26 is enough. An undated or older
page is enough only when the place also holds an active OLCC liquor license (read 2026-10-24), which is the 2026 evidence it operates;
places with neither stay out and are listed in data/research/app/LEADS.md. The address comes from the map listing or license we
already hold for that name in that town (site/oregon.json), never from memory; a dated page's own street address wins when our
listing sits elsewhere (oregon.py moves a listing more than 1.5 km off), and places our data lacks are added from that address.
Usage: ../.venv/bin/python build_research.py   (then oregon.py)"""
import json, os, re
ROOT = os.path.join(os.path.dirname(__file__), "..")
R = os.path.join(ROOT, "data", "research")
os.makedirs(f"{R}/app", exist_ok=True)
d = json.load(open(os.path.join(ROOT, "site", "oregon.json")))
C, M = d["cols"], d["meta"]
norm = lambda s: re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", (s or "").lower().replace("'", "").replace("’", "").replace("ä", "a")
                                            .replace("í", "i").replace("é", "e").replace("ø", "o"))).strip()

OLCC = "https://data.oregon.gov/Business/Liquor-Business-Licenses-Endorsements/srxe-qkm2"
MERC_CARTS = "https://www.portlandmercury.com/food/food-issue-2026/portlands-top-20-food-carts/"          # Jul 9, 2026
BULLETIN_CARTS = "https://bendbulletin.com/2026/09/04/risky-business-is-bend-maxed-out-on-food-carts/"   # Sep 4, 2026
EUG_CARTS = "https://www.eugenecascadescoast.org/blog/post/guide-to-eugene-food-truck-pods/"             # Apr 10, 2026
TO_CHOWDER = "https://traveloregon.com/things-to-do/eat-drink/seafood/warm-chowder-spots-oregon-coast/"  # 2019, updated Nov 29, 2023
NEWPORT_FISH = "https://www.discovernewport.com/post/newport-restaurants-freshest-fish"                   # May 28, 2024
TILL_OYSTERS = "https://tillamookcoast.com/blog/top-5-tillamook-coast-oyster-spots/"                    # Jun 21, 2018
OCVA_OYSTERS = "https://visittheoregoncoast.com/dine/keep-local-seafood-local/oysters/"                  # undated
TO_PIES = "https://traveloregon.com/things-to-do/eat-drink/artisan-producers/oregons-pit-stop-worthy-pies/"  # 2022, updated Feb 23, 2026
WV_REST = "https://www.willamettevalley.org/explore-the-best-restaurants-in-the-willamette-valley"         # undated
WV_WEEKEND = "https://www.willamettevalley.org/weekend-in-oregon-wine-country"                             # undated
TO_DONUTS = "https://traveloregon.com/things-to-do/eat-drink/top-doughnut-shops-in-oregon/"               # Feb 9, 2026
TO_WOODBURN = "https://traveloregon.com/things-to-do/trip-ideas/favorite-trips/tour-woodburn-oregons-little-mexico/"  # 2019, upd. 2021
TO_HR_TAQ = "https://traveloregon.com/things-to-do/eat-drink/restaurants/hood-river-taqueria-mexican-restaurant/"   # undated listing
HUBERS = "https://www.hubers.com/"
DAN_LOUIS = "https://www.danandlouis.com/"
DATED = {MERC_CARTS, BULLETIN_CARTS, EUG_CARTS, TO_PIES, TO_DONUTS}

# (name as the page writes it, town, street number the page gives (or None), note, founded, founded_note, source)
GUIDES = {
 "food cart": [
  ("Kee's #Loaded Kitchen", "Portland", "3625", "Soul food cart on NE Martin Luther King Jr. Blvd.", None, None, MERC_CARTS),
  ("Chochu Local", "Portland", "5235", "Chamoru barbecue cart on NE Sandy Blvd.", None, None, MERC_CARTS),
  ("J Vein Caffe", "Portland", "5235", "Italian-style espresso cart on NE Sandy Blvd.", None, None, MERC_CARTS),
  ("Yoshi's Sushi", "Portland", "3530", "Sushi cart on SW Multnomah Blvd.; order by phone ahead.", None, None, MERC_CARTS),
  ("Golden Triangle Asian Fusion", "Portland", "4727", "Lao, Cambodian and Thai cart at the Woodstock pod.", None, None, MERC_CARTS),
  ("Kim Jong Grillin", "Portland", "4727", "Korean cart at the Woodstock pod.", None, None, MERC_CARTS),
  ("Frybaby", "Portland", "4727", "Korean fried chicken cart at the Woodstock pod.", None, None, MERC_CARTS),
  ("Cookie McCakeFace", "Portland", "4727", "Warm, thick cookies at the Woodstock pod.", None, None, MERC_CARTS),
  ("Bark City BBQ", "Portland", "4727", "Barbecue cart at the Woodstock pod.", None, None, MERC_CARTS),
  ("El Sazon de Mi Rancho", "Portland", "4606", "Tacos and chilaquiles on SE Division St.", None, None, MERC_CARTS),
  ("Merendero Estela", "Portland", "7107", "Honduran baleadas and fried chicken on SE 82nd Ave.", None, None, MERC_CARTS),
  ("Nice Time", "Portland", "3757", "Handmade pasta with Italian and Korean ideas, on SE Hawthorne.", None, None, MERC_CARTS),
  ("Mama Chow's Kitchen", "Portland", "3757", "Oakland Chinatown-style wings and wontons, on SE Hawthorne.", None, None, MERC_CARTS),
  ("Makulit", "Portland", "3829", "Filipino-inspired burgers and fries on SE Division St.", None, None, MERC_CARTS),
  ("Hawker Station", "Portland", "3829", "Singapore-style chicken rice on SE Division St.", None, None, MERC_CARTS),
  ("Chick and Pig", "Portland", "3829", "Thai street food on SE Division St.", None, None, MERC_CARTS),
  ("A Comer", "Portland", "2788", "Mexico City-style tacos de canasta and pambazos on NW Thurman St.", None, None, MERC_CARTS),
  ("Bari", "Portland", "625", "Panzerotti, cannoli and tiramisu on NE Killingsworth St.", None, None, MERC_CARTS),
  ("Loncheria Los Mayas", "Portland", "2515", "Yucatecan panuchos and tacos on NE Alberta St.", None, None, MERC_CARTS),
  ("Mole Mole", "Portland", "2231", "Mole and enchiladas on NE Alberta St.", None, None, MERC_CARTS),
  ("The Podski", "Bend", None, "Downtown Bend food cart lot.", None, None, BULLETIN_CARTS),
  ("Ballers & Brews", "Bend", None, "Food cart lot with a bar.", None, None, BULLETIN_CARTS),
  ("Midtown Yacht Club", "Bend", None, "Food cart lot and bar on NE 4th St.", None, None, BULLETIN_CARTS),
  ("On Tap", "Bend", None, "Food cart lot and taproom.", None, None, BULLETIN_CARTS),
  ("The Lot", "Bend", None, "Bend's first food cart pod, opened 2013.", None, None, BULLETIN_CARTS),
  ("Crosscut", "Bend", None, "Food cart lot with a bar.", None, None, BULLETIN_CARTS),
  ("Louka's", "Eugene", None, "Cart at The Garden on Friendly pod (2760 Friendly St).", None, None, EUG_CARTS),
  ("BHeavenly", "Eugene", None, "Cart at the Kesey Square pod downtown.", None, None, EUG_CARTS),
  ("Play", "Eugene", None, "Downtown pod and bar with several carts.", None, None, EUG_CARTS),
  ("Bounty Meat and Cheese", "Eugene", None, "Cart at the PLAY pod downtown.", None, None, EUG_CARTS),
  ("Paper Plate BBQ", "Eugene", None, "Barbecue cart at the PLAY pod downtown.", None, None, EUG_CARTS),
  ("Beergarden", "Eugene", None, "Downtown beer garden with food carts.", None, None, EUG_CARTS),
  ("PublicHouse", "Springfield", None, "Food court with carts in a former church.", None, None, EUG_CARTS),
  ("Shalosh", "Springfield", None, "Cart at the PublicHouse food court.", None, None, EUG_CARTS),
  ("Soi 44", "Springfield", None, "Thai cart at the Monkey Paw pod.", None, None, EUG_CARTS),
 ],
 "coast seafood": [
  ("South Bay Wild Fish House", "Astoria", None, "Clam chowder.", None, None, TO_CHOWDER),
  ("Bridgewater Bistro", "Astoria", None, "Clam and mussel chowder by the Astoria-Megler Bridge.", None, None, TO_CHOWDER),
  ("Dooger's Seafood & Grill", "Seaside", None, "Family-recipe clam chowder.", None, None, TO_CHOWDER),
  ("Offshore Grill and Coffee House", "Manzanita", None, "Clam chowder.", None, None, TO_CHOWDER),
  ("Gracie's Sea Hag", "Depoe Bay", None, "Clam chowder.", None, None, TO_CHOWDER),
  ("Chowder Bowl", "Newport", None, "Clam chowder by Nye Beach.", None, None, NEWPORT_FISH),
  ("Luna Sea Fish House", "Yachats", None, "Clam chowder.", None, None, TO_CHOWDER),
  ("The Crazy Norwegian's Fish & Chips", "Port Orford", None, "Chowder, fish and chips.", None, None, TO_CHOWDER),
  ("Mo's Seafood & Chowder", "Newport", "622", "Mo's clam chowder on Newport's Historic Bayfront.", None, None, NEWPORT_FISH),
  ("Clearwater Restaurant", "Newport", None, "Dungeness crab, from whole crab to salads.", None, None, NEWPORT_FISH),
  ("Ocean Bleu Seafoods", "Newport", None, "Clam chowder on the Bayfront.", None, None, NEWPORT_FISH),
  ("Local Ocean Seafoods", "Newport", None, "Dungeness crab cakes and oysters on the Bayfront.", None, None, NEWPORT_FISH),
  ("The Schooner", "Netarts", None, "Oysters on the half shell on Netarts Bay.", None, None, TILL_OYSTERS),
  ("Jandy Oyster", "Tillamook", None, "Oysters grown in Netarts Bay, with an oyster bar.", None, None, TILL_OYSTERS),
  ("7 Devils Waterfront Alehouse", "Coos Bay", None, "Local Coos Bay oysters.", None, None, OCVA_OYSTERS),
 ],
 "marionberry pie": [
  ("Otis Cafe", "Lincoln City", "4618", "Long-time roadside stop known for marionberry pie, now in Lincoln City (it moved from Otis).", None, None, TO_PIES),
  ("Bipartisan Cafe", "Portland", None, "Coffee shop with marionberry among its pies, in Montavilla.", None, None, TO_PIES),
 ],
 "wine country": [
  ("The Painted Lady", "Newberg", None, None, None, None, WV_REST),
  ("Red Hills Market", "Dundee", None, None, None, None, WV_REST),
  ("Joel Palmer House", "Dayton", None, None, None, None, WV_REST),
  ("Rosmarino Osteria Italiana", "Newberg", None, "Handmade pasta.", None, None, WV_WEEKEND),
  ("Hayward", "Carlton", None, None, None, None, WV_WEEKEND),
 ],
 "doughnut": [
  ("Heavenly Donuts", "Portland", "504", "Open around the clock at the Hazelwood location.", None, None, TO_DONUTS),
  ("Joe's Donut Shop", "Sandy", None, None, None, "Travel Oregon (Feb 2026): in Sandy since 1974.", TO_DONUTS),
  ("Mediterranean Grill", "Happy Valley", None, "Lebanese-inspired lunch and dinner, with a rack of doughnuts each morning.", None, None, TO_DONUTS),
  ("Depoe Baykery", "Gleneden Beach", None, "Across Highway 101 from Salishan.", None, None, TO_DONUTS),
  ("Daynight Donuts", "Salem", None, None, None, None, TO_DONUTS),
  ("Daynight Donuts", "Eugene", None, None, None, None, TO_DONUTS),
  ("Blue Mountain Donut Company", "Joseph", None, None, None, None, TO_DONUTS),
  ("Annie's Bakery", "Burns", None, None, None, None, TO_DONUTS),
  ("Pip's Original Doughnuts", "Portland", None, None, None, None, TO_DONUTS),
  ("Oyatsupan Bakers", "Beaverton", None, "Japanese bakery with curry pan.", None, None, TO_DONUTS),
  ("Donut Country", "Medford", None, None, None, None, TO_DONUTS),
  ("Mochi Donut House", "Central Point", None, None, None, None, TO_DONUTS),
  ("The Dough Nut", "Bend", None, None, None, None, TO_DONUTS),
  ("Sugar Shack Bakery", "Reedsport", None, None, None, None, TO_DONUTS),
  ("Mikiko Mochi Donuts", "Portland", None, "Gluten-free, dairy-free and nut-free mochi doughnuts.", None, None, TO_DONUTS),
  ("Doe Donuts", "Portland", None, "Vegan doughnuts.", None, None, TO_DONUTS),
  ("Pacific Donuts", "Forest Grove", None, None, None, None, TO_DONUTS),
  ("Bigwig Donuts", "Salem", None, None, None, None, TO_DONUTS),
  ("Dough Hook", "Salem", None, None, None, None, TO_DONUTS),
 ],
 "taqueria": [
  ("Luis's Taqueria", "Woodburn", None, "A Woodburn institution on Front Street.", None, None, TO_WOODBURN),
  ("Hood River Taqueria", "Hood River", None, None, None, None, TO_HR_TAQ),
  ("El Sazon de Mi Rancho", "Portland", "4606", "Taco cart on SE Division; the three-taco plate.", None, None, MERC_CARTS),
  ("Loncheria Los Mayas", "Portland", "2515", "Yucatecan tacos on handmade tortillas, NE Alberta St.", None, None, MERC_CARTS),
  ("A Comer", "Portland", "2788", "Mexico City-style tacos de canasta.", None, None, MERC_CARTS),
 ],
 "oldest": [
  ("Dan & Louis Oyster Bar", "Portland", "208", "Louis C. Wachsmuth opened it in 1907; the downtown spot has served for over a century.", 1907,
   "Its own site: \"Serving Portland since 1907.\"", DAN_LOUIS),
  ("Huber's", "Portland", "411", "Portland's oldest restaurant, per its own site.", None,
   "Its own site: \"Established in 1879.\" The site doesn't say since when it has been at 411 SW 3rd Ave, so no year is shown.", HUBERS),
 ],
}

# street addresses as the dated page prints them, for places the map data lacks or places elsewhere
ADDR = {("Golden Triangle Asian Fusion", "Portland"): "4727 SE Woodstock Blvd", ("Frybaby", "Portland"): "4727 SE Woodstock Blvd",
        ("Mama Chow's Kitchen", "Portland"): "3757 SE Hawthorne Blvd", ("Makulit", "Portland"): "3829 SE Division St",
        ("Chick and Pig", "Portland"): "3829 SE Division St", ("A Comer", "Portland"): "2788 NW Thurman St",
        ("Bari", "Portland"): "625 NE Killingsworth St", ("Loncheria Los Mayas", "Portland"): "2515 NE Alberta St",
        ("Mole Mole", "Portland"): "2231 NE Alberta St"}

JBF_2026_W = "https://www.jamesbeard.org/stories/james-beard-award-winners-2026"
JBF_2026_N = "https://www.jamesbeard.org/stories/james-beard-awards-restaurant-and-chef-nominees-2026"
JBF_2026_S = "https://www.jamesbeard.org/stories/james-beard-award-semifinalists-2026"
JBF_2025_W = "https://www.jamesbeard.org/stories/the-2025-james-beard-award-winners"
JBF_2025_N = "https://www.jamesbeard.org/stories/2025-james-beard-awards-restaurant-and-chef-nominees"
JBF_2025_S = "https://www.jamesbeard.org/stories/the-2025-james-beard-award-semifinalists"
JBF = [  # (name, town, street number, honors, sources) - confirmed on jamesbeard.org 2026-10-24
 ("Scotch Lodge", "Portland", None, ["Outstanding Bar winner 2026", "Outstanding Bar finalist 2025"], [JBF_2026_W, JBF_2025_N]),
 ("Nodoguro", "Portland", None, ["Best Chef: Northwest and Pacific winner 2026 (Ryan Roadhouse)", "Best Chef: Northwest and Pacific finalist 2025 (Ryan Roadhouse)"], [JBF_2026_W, JBF_2025_N]),
 ("Gado Gado", "Portland", None, ["Best Chef: Northwest and Pacific finalist 2026 (Thomas Pisha-Duffly)", "Best Chef: Northwest and Pacific semifinalist 2025 (Thomas Pisha-Duffly)"], [JBF_2026_N, JBF_2025_S]),
 ("Le Pigeon", "Portland", None, ["Outstanding Restaurant semifinalist 2026", "Outstanding Chef semifinalist 2025 (Gabriel Rucker)"], [JBF_2026_S, JBF_2025_S]),
 ("Coquine", "Portland", None, ["Outstanding Wine and Other Beverages Program semifinalist 2026", "Outstanding Restaurant finalist 2025"], [JBF_2026_S, JBF_2025_N]),
 ("Heavenly Creatures", "Portland", None, ["Outstanding Professional in Beverage Service semifinalist 2026 and 2025 (Joel Gunderson)"], [JBF_2026_S, JBF_2025_S]),
 ("Cafe Olli", "Portland", None, ["Best Chef: Northwest & Pacific semifinalist 2026 (Taylor Manning and Siobhan Speirits)"], [JBF_2026_S]),
 ("Maurice", "Portland", None, ["Best Chef: Northwest & Pacific semifinalist 2026 (Kristen Murray)"], [JBF_2026_S]),
 ("Mäs", "Ashland", None, ["Best Chef: Northwest & Pacific semifinalist 2026 (Josh Dorcak)", "Best Chef: Northwest and Pacific finalist 2025 (Joshua Dorcak)"], [JBF_2026_S, JBF_2025_N]),
 ("JORY Restaurant", "Newberg", None, ["Best Chef: Northwest & Pacific semifinalist 2026 (Jack Strong)"], [JBF_2026_S]),
 ("JinJu Patisserie", "Portland", None, ["Outstanding Bakery winner 2025"], [JBF_2025_W]),
 ("Lovely's Fifty Fifty", "Portland", None, ["Outstanding Chef semifinalist 2025 (Sarah Minnick)"], [JBF_2025_S]),
 ("Yardy Rum Bar", "Eugene", None, ["Best Chef: Northwest & Pacific semifinalist 2025 (Isaiah Martinez)"], [JBF_2025_S]),
 ("Hayward", "Carlton", None, ["Best Chef: Northwest & Pacific semifinalist 2025 (Kari Shaughnessy; the Foundation lists McMinnville)"], [JBF_2025_S]),
 ("Nick's Italian Cafe", "McMinnville", "521", ["America's Classics 2014"], ["https://www.jamesbeard.org/stories/2014-americas-classics-nicks-italian-caf"]),
]

# closures, each with a dated 2026 page; a place the research found closed comes off the list whatever the map data says
CLOSED = [
 ("Big Ski's Pierogis", "Bend", "536", "Closed Sept. 14, 2026 after 12 years at The Podski.", BULLETIN_CARTS),
 ("Himalayan Bites", "Bend", "1424", "Closed at On Tap at the end of August 2026.", BULLETIN_CARTS),
 ("IndoDaddy", "Bend", None, "Closed in late July 2026.", BULLETIN_CARTS),
 ("Dump City Dumplings", "Bend", None, "Closed at the end of August 2026 after 17 years.", BULLETIN_CARTS),
 ("MidCity SmashedBurger", "Bend", None, "Closed in June 2026.", BULLETIN_CARTS),
 ("Otis Cafe", "Otis", None, "Moved from Otis to Lincoln City.", TO_PIES),
]

# adult clubs our name and Overture-category rules miss (a one-letter name, a plain trade name); each with a source
ADULT = [
 {"name": "Acropolis Club", "address": "8325 SE McLoughlin Blvd", "towns": ["Portland", "Milwaukie"],
  "sources": ["https://www.wweek.com/bars/2019/06/06/dont-freak-out-iconic-portland-steakhouse-strip-club-the-acropolis-has-closed-but-only-temporarily/"]},
 {"name": "Silverado", "address": "610-611 NW Couch St", "towns": ["Portland"],
  "sources": ["https://www.wweek.com/bars/2018/12/24/portlands-oldest-male-strip-club-is-moving-into-a-new-location-the-day-after-christmas/"]},
 {"name": "X Exotic Lounge", "address": "15 SW 2nd Ave", "towns": ["Portland"],
  "sources": ["Overture Maps 2026-10-21.0, category adult_entertainment_venue (\"X Exotic Lounge\", 15 SW 2nd Ave)"]},
]


def town_of(i):
    return M["cities"][C["city"][i]] if C["city"][i] is not None else None


def find(name, town, num):
    k = norm(name)
    hits = [i for i, n in enumerate(C["name"]) if town_of(i) == town
            and (norm(n) == k or norm(n).startswith(k + " ") or k.startswith(norm(n) + " ") or norm(n).replace(" ", "") == k.replace(" ", ""))]
    if num:
        hits = [i for i in hits if (C["addr"][i] or "").split(" ")[0] == num]
    return hits


leads, n_out = [], {}
for kind, rows in GUIDES.items():
    out = []
    for name, town, num, note, founded, fnote, src in rows:
        dated = src in DATED
        hits = find(name, town, num) or (find(name, town, None) if dated and (name, town) in ADDR else [])
        if len(hits) > 1:   # several licensed branches in one town (Daynight Donuts): every licensed one, else every one
            lic = [i for i in hits if C["tier"][i] == 2]
            hits = lic if lic else hits
        addr = ADDR.get((name, town))
        if not hits and dated and addr:
            # a dated 2025-26 page with a street address, for a place the map data lacks: placed from that address (oregon.py)
            out.append({"name": name, "address": addr, "city": town, "zip": None, "kinds": [kind], "dishes": [], "note": note,
                        "founded": founded, "founded_note": fnote, "website": None, "open": True, "evidence_date": "2026",
                        "sources": [src], "match_names": []})
            continue
        if not hits:
            leads.append(f"- {kind}: {name} ({town}{', ' + num if num else ''}): not in our data; not added"); continue
        for i in hits:
            if not dated and C["tier"][i] != 2:
                leads.append(f"- {kind}: {name} ({town}): the page ({src}) isn't dated 2025-26 and no active OLCC license matched; not added")
                continue
            out.append({"name": C["name"][i], "address": addr or C["addr"][i], "city": town,
                        "zip": str(C["zip"][i]) if C["zip"][i] else None, "kinds": [kind], "dishes": [], "note": note, "founded": founded,
                        "founded_note": fnote, "website": None, "open": True, "evidence_date": "2026",
                        "sources": [src] + ([OLCC] if C["tier"][i] == 2 else []),
                        "match_names": [name.upper()] if norm(name) != norm(C["name"][i]) else []})
    fn = re.sub(r"[^a-z]+", "_", kind).strip("_")
    json.dump(out, open(f"{R}/app/{fn}.json", "w"), indent=1, ensure_ascii=False)
    n_out[kind] = len(out)
jb = []
for name, town, num, honors, srcs in JBF:
    hits = find(name, town, num)
    if len(hits) != 1:
        leads.append(f"- James Beard: {name} ({town}): {len(hits)} matches in our data; not added"); continue
    i = hits[0]
    jb.append({"name": C["name"][i], "address": C["addr"][i], "city": town, "zip": None, "honors": honors, "open": True,
               "sources": srcs + ([OLCC] if C["tier"][i] == 2 else []), "match_names": [name.upper()]})
json.dump(jb, open(f"{R}/jbf.json", "w"), indent=1, ensure_ascii=False)
# the export this reads has already dropped the places closed last time, so a closure found then is kept from the last file (with the
# address that run matched) rather than dropped: otherwise every second rebuild would bring the closed places back
try:
    prev_closed = json.load(open(f"{R}/app/closed_research.json"))
except (OSError, ValueError):
    prev_closed = []
closed = []
for name, town, num, note, src in CLOSED:
    hits = find(name, town, num)
    for i in hits:
        closed.append({"name": C["name"][i], "address": C["addr"][i], "city": town, "note": note, "sources": [src], "open": False,
                       "match_names": [name.upper()]})
    kept = [dict(c, note=note, sources=[src]) for c in prev_closed if c.get("match_names") == [name.upper()] and c.get("city") == town]
    if not hits and kept:
        closed += kept
    elif not hits:
        leads.append(f"- closed: {name} ({town}): not in our data (nothing to remove)")
json.dump(closed, open(f"{R}/app/closed_research.json", "w"), indent=1, ensure_ascii=False)
json.dump({"note": "Oregon adult clubs the name and Overture-category rules miss; each entry sourced (oregon.py removes every place at "
                   "these addresses in these towns)", "venues": ADULT}, open(f"{R}/adult_venues.json", "w"), indent=1, ensure_ascii=False)
open(f"{R}/app/LEADS.md", "w").write("# Oregon research leads (not yet verified)\n\nWritten by pipeline/build_research.py.\n\n" + "\n".join(leads) + """

## Hosts
- Blocked for our research (robots.txt or a 403 to our fetcher, 2026-10-24): oregonlive.com, pdx.eater.com, registerguard.com,
  statesmanjournal.com, koin.com, kezi.com, kptv.com; travelportland.com and foodcartsportland.com answer 403.
- Usable: wweek.com, portlandmercury.com, kgw.com, opb.org, traveloregon.com, bendbulletin.com, ktvz.com, dailyastorian.com,
  eugenecascadescoast.org, willamettevalley.org, visittheoregoncoast.com, tillamookcoast.com, discovernewport.com, jamesbeard.org.
  Readers' polls (Willamette Week's Best of Portland) are never a source: honors are facts, not votes.

## Thin guides, next pass
- Taquerias: Woodburn (El Tule, Santana, Los Laureles), Salem, Hillsboro (Ochoa's) and Hood River (Ayala) need a 2025-26 page or an
  OLCC license. Travel Oregon's Woodburn tour is from 2021.
- Marionberry pie: Willamette Valley Pie Company (Salem, 2994 82nd Ave NE) sells pie by the slice, but the pages found don't name a
  marionberry pie there; Hiatt Farm isn't in our data.
- Coast seafood without a license or a dated page: Buttercup (Nehalem), Georgie's Beachside Grill, Krab Kettle, Novelli's (Florence),
  Tony's Crab Shack (Bandon), Bowpicker (Astoria). Not in our data: Captain's Corner (Garibaldi), Ecola Seafoods (Cannon Beach),
  Crabby Bar & Grill (Winchester Bay), SOURCE Oyster and Wine Bar (Garibaldi), Nevør Shellfish Farm (Netarts).
- Wine country: Grounded Table and La Rambla (McMinnville), Thistle, Tina's (Dundee), Anthology and Field + Stream (Dundee) need a page.
- Oldest: Huber's needs a source for the year at 411 SW 3rd Ave; Jake's Famous Crawfish and others need "at this address" sources.
- James Beard places not in our data as places to eat: Humble Spirit (McMinnville), Antica Terra (Amity; a winery).
""")
print(n_out, "| James Beard:", len(jb), "| closed:", len(closed), "| leads:", len(leads))
