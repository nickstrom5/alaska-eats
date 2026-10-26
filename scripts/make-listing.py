#!/usr/bin/env python3
"""Writes the App Store listing and the App Review reply from the build's own counts (playbook/site-numbers.json, which
scripts/make-site.py rewrites on every run), so the copy never drifts from the data. Ported from or-eats/scripts/make-listing.py.

Usage (from ak-eats/): .venv/bin/python scripts/make-listing.py   (after make-site.py)
Writes playbook/06-app-store-listing.md, playbook/13-app-review-reply.md and playbook/app-store/listing.json (what
../scripts/asc_listing.py uploads once Nick creates the App Store Connect record and its FOLDERS line is added).
Checks before writing anything: Apple's length limits, no keyword repeating a name/subtitle word, no "best"/"top"/"#1", no price
claim outside the description's plain "free guide", the reply under 4,000 characters.
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
N = json.load(open(os.path.join(ROOT, "playbook", "site-numbers.json")))
R, T, LIC, HON, INS = N["restaurants"], N["towns"], N["on_an_official_list"], N["honors"], N["anc_inspected"]
G = {k[6:]: v for k, v in N.items() if k.startswith("guide_") and isinstance(v, int)}
FLOOR = R // 100 * 100   # "1,900+": promo text and What's New outlive small data changes
SITE = "https://alaska.eatsranked.com/"   # until the CNAME resolves: https://nickstrom5.github.io/alaska-eats/
CLASSICS = N["americas_classics"]

NAME = "Alaska Eats: Restaurants"            # Nick, 2026-10-26 (playbook/05-naming.md)
SUB = "Halibut, Roadhouses & Reindeer"
# no word from the name or subtitle; towns are the biggest search win (rotate after a month of App Store Connect search-term data)
KW = "anchorage,juneau,fairbanks,homer,seward,ketchikan,kenai,wasilla,sitka,talkeetna,crab,salmon,seafood"
PROMO = (f"{G['seafood']} halibut, salmon and crab houses, {G['global']} of Anchorage's global kitchens and {G['roadhouse']} roadhouses, "
         f"checked by hand. Plus Anchorage's inspection scores and {FLOOR:,}+ restaurants.")
WHATS_NEW = f"First release: halibut, salmon and crab, Anchorage's global kitchens, roadhouses, reindeer dogs and {FLOOR:,}+ Alaska restaurants."

DESC = f"""Alaska's restaurants, from halibut and chips on the Homer Spit to a reindeer dog in downtown Anchorage.

Alaska Eats is a free guide to eating in Alaska: {G['seafood']} halibut, salmon and crab houses from Ketchikan to Homer, {G['global']} of Anchorage's Filipino, Korean, Hawaiian, Polynesian and Lao kitchens, plus roadhouses and lodges, reindeer dog stands and sourdough breakfasts, each checked by hand. Behind them, {R:,} restaurants, cafés, bars and espresso stands in {T} towns, from Anchorage, Fairbanks and Juneau to Utqiaġvik. In Anchorage, {INS:,} of them show the Health Department's own inspection score, with its date and the department's next step. No account, no ads.

ALASKA GUIDES
• Halibut, Salmon & Crab: halibut and chips, salmon bakes and king crab.
• Anchorage's Global Kitchens: Filipino, Korean, Hawaiian, Polynesian and Lao kitchens.
• Roadhouses & Lodges: highway roadhouses and lodges, many open summers only.
• Reindeer Dogs and Sourdough: street carts and breakfast counters.
• Award honorees: {HON} James Beard semifinalists, finalists and {"an America's Classic" if CLASSICS == 1 else f"{CLASSICS} America's Classics"}.
• Anchorage Inspection Scores: the Health Department's own scores out of 100, as published.

FIND IT FAST
• Sort by distance, or browse the map by guide.
• Search by name, town, street or dish: "king crab juneau", "reindeer dog".
• Filter by town or cuisine, or hide chains.
• Save places, and find hand-checked places from iPhone search (Spotlight).

LIVE DETAILS FROM APPLE MAPS
Tap "Ratings, hours & photos" on any place to open Apple Maps' own place card, with current hours, photos, ratings and directions.

HOW THE LISTS ARE BUILT
Every guide place was checked by hand in October 2026: a dated 2025 or 2026 source names it (the place's own site, local news or a tourism listing), or an older one does and the place holds an active Anchorage food permit. The rest come from Overture Maps open data, checked in Anchorage against the Health Department's food permits and the Municipal Clerk's liquor licenses. Website links are checked too. Anchorage's scores are shown as the department publishes them; the state publishes no inspection results elsewhere, so the app shows none there. Nothing is ranked by star ratings, and the app computes no grades.

PRIVATE BY DESIGN
No account, no tracking, no ads. Your location, if you share it, only sorts lists on your device. Saved places stay on your device.

Many Alaska places open only in summer, so check before you go. Spot a mistake? Email nick@eatsranked.com.

An independent app, not affiliated with any restaurant, chain or government agency (including the State of Alaska, the Department of Environmental Conservation and the Municipality of Anchorage), or with the James Beard Foundation. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation. Place data from Overture Maps Foundation (CDLA Permissive 2.0) and others; sources and licenses are on the About tab."""

REPLY = f"""Thank you. Here is the information requested. A screen recording from an iPhone running the latest iOS is attached. It starts at launch and shows the full flow.

1. Screen recording: attached. There is no account, login, user-generated content or paid content.

2. Purpose and audience: Alaska Eats is a free guide to restaurants in Alaska. Its focus is the state's own food: {G['seafood']} halibut, salmon and crab houses, {G['global']} of Anchorage's global kitchens, and roadhouses, reindeer dog stands and sourdough breakfasts, each checked by hand in October 2026 against a public source. It also lists {R:,} restaurants, cafés and bars statewide, and in Anchorage it shows the Health Department's own published inspection scores. It is for Alaska residents and visitors deciding where to eat, with no ads, account or tracking.

3. How to use it (no login, no setup, no sample files needed):
- Home → Halibut, Salmon & Crab (or Anchorage's Global Kitchens, Roadhouses & Lodges, James Beard Honors, Anchorage Inspection Scores, Near Me) → tap any place.
- On a place, tap "Ratings, hours & photos" to open Apple Maps' own place card through MapKit. Directions, Call and Website are below it.
- Search from the Home search box by name, town, street or dish ("king crab juneau", "reindeer dog").
- The Map tab shows each guide as pins. "My location" and the Nearest sort use location only if allowed, on the device.
- The heart saves a place on the device, under the Saved tab. The About tab lists the data sources, licenses and the independence statement.
- On iPad, a sidebar replaces the tabs; a place opens in the right-hand column.
- Location: if you're outside Alaska (as App Review usually is), the map says so and stays on Alaska, and distance sorting still works from where you are.
- "Alaska Eats" is the short Home Screen name of "Alaska Eats: Restaurants".

4. External services and data:
- Apple MapKit: maps, local search to find a place's Apple Maps listing, and Apple's place card for live hours, photos and ratings.
- Core Location: optional, on-device only, for distance sorting.
- Core Spotlight: on-device indexing so places appear in iPhone search.
- No backend, accounts, analytics, advertising, payments or AI services. The restaurant data is bundled in the app.
- Bundled data sources: Overture Maps Foundation open place data (CDLA Permissive 2.0, with Foursquare-sourced records under Apache 2.0 and AllThePlaces under CC0; license texts are in the app); the Municipality of Anchorage's open data (the Health Department's restaurant inspection file: facility name, address, inspection date, score, next step and cited items; and the Municipal Clerk's liquor licenses: trade name, type, number and expiration year); U.S. Census Bureau boundaries (public domain); James Beard Foundation award records (facts only); and our own research of public websites and local news.
- The website with the privacy policy and support page is static and hosted on GitHub Pages: {SITE}

5. Regional differences: none. The content covers Alaska; the app is offered in the United States and works the same everywhere.

6. Regulated or protected material: the app is not in a regulated industry and includes no protected third-party material. The data is open-licensed or public record, with attribution and licenses on the About tab. Ratings, hours and photos are shown only inside Apple's own place card through MapKit; the app stores no ratings or reviews. Anchorage's inspection scores are public records, shown exactly as the department published them with their dates; the app never computes grades. Every website link was checked before release, and adult venues are excluded. The app is independent and not affiliated with any restaurant, agency or the James Beard Foundation.

Support: nick@eatsranked.com"""

# ---------------- checks (nothing is written unless all pass)
problems = []
for label, text, limit in (("name", NAME, 30), ("subtitle", SUB, 30), ("keywords", KW, 100), ("promotional text", PROMO, 170),
                           ("What's New", WHATS_NEW, 4000), ("description", DESC, 4000), ("review notes", REPLY, 4000)):
    if len(text) > limit:
        problems.append(f"{label}: {len(text)} characters, limit {limit}")
title_words = set(re.findall(r"[a-z]+", (NAME + " " + SUB).lower()))
for kw in KW.split(","):
    if kw != kw.strip() or not kw:
        problems.append(f"keyword {kw!r}: no spaces around commas, no empty entries")
    if set(kw.split()) & title_words:
        problems.append(f"keyword {kw!r} repeats a word from the name or subtitle")
for text, label in ((KW, "keywords"), (PROMO, "promotional text"), (SUB, "subtitle"), (WHATS_NEW, "What's New")):
    for bad in (r"\bbest\b", r"\btop\b", r"#1", r"\bfree\b", r"\bevery\b"):
        if re.search(bad, text, re.I):
            problems.append(f"{label}: contains {bad!r}")
if re.search(r"\bevery (?:restaurant|place|cart|roadhouse)\b|\ball [\d,]+ ", DESC + REPLY, re.I):
    problems.append("description/reply: an 'every restaurant' or 'all N' claim the data can't back")
if problems:
    sys.exit("not written:\n  " + "\n  ".join(problems))

listing = {"bundleId": "com.alaskaeats.ios", "name": NAME, "subtitle": SUB, "privacyPolicyUrl": SITE + "privacy.html",
           "primaryCategory": "FOOD_AND_DRINK", "secondaryCategory": "TRAVEL", "description": DESC, "keywords": KW,
           "promotionalText": PROMO, "supportUrl": SITE, "marketingUrl": SITE, "reviewNotes": REPLY}
os.makedirs(os.path.join(ROOT, "playbook", "app-store"), exist_ok=True)
json.dump(listing, open(os.path.join(ROOT, "playbook", "app-store", "listing.json"), "w"), indent=1, ensure_ascii=False)

open(os.path.join(ROOT, "playbook", "06-app-store-listing.md"), "w").write(f"""# App Store listing (ASO)

Written by `scripts/make-listing.py` from `site-numbers.json` ({N['generated']}); re-run it after every data refresh, never hand-edit.
The machine copy is `app-store/listing.json` (read by `../scripts/asc_listing.py` once Nick creates the App Store Connect record and
adds `"com.alaskaeats.ios": "ak-eats"` to its FOLDERS). The URLs assume alaska.eatsranked.com is live; until Nick's CNAME
resolves, use https://nickstrom5.github.io/alaska-eats/.

## Name (30 max)
`{NAME}` ({len(NAME)})

## Subtitle (30 max)
`{SUB}` ({len(SUB)})

Together they index: alaska, eats, restaurants, halibut, roadhouses, reindeer. Home Screen name: Alaska Eats.

## Keywords (100 max)
`{KW}` ({len(KW)})

- No word repeats the name or subtitle; no trademarks (no Lucky Wishbone, Simon & Seafort's, Humpy's), no "best", "top" or "#1".
- Towns are the biggest win; Palmer, Valdez, Kodiak, Girdwood and Eagle River didn't fit. Rotate them in after a month of App Store
  Connect search-term data. Apple's public search can't be used for this research (itunes.apple.com's robots.txt blocks Claude).

## Promotional text (170 max, editable any time without review)
`{PROMO}` ({len(PROMO)})

## Description ({len(DESC)} of 4,000)
```
{DESC}
```

## What's New (1.0)
`{WHATS_NEW}`

## Screenshots
Framed by `scripts/appstore-screenshots.py`: `app-store/iphone/` (8, 1320x2868, the 6.9" slot) and `app-store/ipad/` (6, 2064x2752, the
13" slot). Upload one file at a time in file order and check the order after a reload. No image shows an inspection list, and the
detail shot's place (Whisky & Ramen) scored 100 on the regular schedule, so no negative board appears.

## Category and age rating
Primary Food & Drink, secondary Travel. Age rating: alcohol references "Infrequent" (bars, saloons, brewpubs) → 13+; everything else
None/No. Pricing $0.00, available in the United States. Content rights: yes, third-party content, with the rights (open data, public
records, Apple's place card). Untick "Sign-in required".

## App Review
Reply and recording script: `13-app-review-reply.md`. Put the reply in App Review Information → Notes from the start.
""")

open(os.path.join(ROOT, "playbook", "13-app-review-reply.md"), "w").write(f"""# App Review: prepared before submitting (Guideline 2.1 "Information Needed")

Written by `scripts/make-listing.py` ({N['generated']}). Wisconsin's new-developer review asked for a screen recording from a physical
device, starting at launch, plus answers to six questions; Alaska Eats should expect the same. Put the reply below in **App Review
Information → Notes** from the start ({len(REPLY):,} of 4,000 characters), and record the video before submitting. If Apple raises
Guideline 4.3(a), answer with Alaska's own guides and sources (halibut, salmon and crab, Anchorage's global kitchens, roadhouses,
reindeer dogs, Anchorage's published inspection scores, the antimeridian-aware map); never compare with the other state apps in the Notes.

## Screen recording (Nick, on his iPhone, latest iOS, 60–120 seconds, no sound)

Install from TestFlight first (the internal tester's email must be the Apple ID under Settings › your name › Media & Purchases on the
phone, or TestFlight says "not available"). Record with Control Center → Screen Recording:

1. Start on the Home Screen and tap **Alaska Eats**. The recording must begin with the launch.
2. Home: scroll the cards a little.
3. Tap **Halibut, Salmon & Crab**, then **Simon & Seafort's Saloon & Grill**.
4. Tap **Ratings, hours & photos**; Apple's place card opens. Close it, then scroll to the Anchorage inspection and permit sections.
5. Tap the **heart** (Save), then go back to Home.
6. Tap the search box and type `king crab juneau`. Open one result.
7. Tap the **Map** tab, then **Seafood**, then a pin and its name.
8. Tap the **Saved** tab, where the saved place shows. Then tap **About** and scroll to the sources.

## Reply text

```
{REPLY}
```
""")
print(f"wrote listing.json, 06-app-store-listing.md, 13-app-review-reply.md | keywords {len(KW)}/100, promo {len(PROMO)}/170, "
      f"description {len(DESC):,}/4,000, reply {len(REPLY):,}/4,000")
