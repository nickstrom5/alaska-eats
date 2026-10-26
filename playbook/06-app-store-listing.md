# App Store listing (ASO)

Written by `scripts/make-listing.py` from `site-numbers.json` (2026-10-26); re-run it after every data refresh, never hand-edit.
The machine copy is `app-store/listing.json` (read by `../scripts/asc_listing.py` once Nick creates the App Store Connect record and
adds `"com.alaskaeats.ios": "ak-eats"` to its FOLDERS). The URLs assume alaska.eatsranked.com is live; until Nick's CNAME
resolves, use https://nickstrom5.github.io/alaska-eats/.

## Name (30 max)
`Alaska Eats: Restaurants` (24)

## Subtitle (30 max)
`Halibut, Roadhouses & Reindeer` (30)

Together they index: alaska, eats, restaurants, halibut, roadhouses, reindeer. Home Screen name: Alaska Eats.

## Keywords (100 max)
`anchorage,juneau,fairbanks,homer,seward,ketchikan,kenai,wasilla,sitka,talkeetna,crab,salmon,seafood` (99)

- No word repeats the name or subtitle; no trademarks (no Lucky Wishbone, Simon & Seafort's, Humpy's), no "best", "top" or "#1".
- Towns are the biggest win; Palmer, Valdez, Kodiak, Girdwood and Eagle River didn't fit. Rotate them in after a month of App Store
  Connect search-term data. Apple's public search can't be used for this research (itunes.apple.com's robots.txt blocks Claude).

## Promotional text (170 max, editable any time without review)
`6 halibut, salmon and crab houses, 6 of Anchorage's global kitchens and 3 roadhouses, checked by hand. Plus Anchorage's inspection scores and 1,900+ restaurants.` (161)

## Description (2915 of 4,000)
```
Alaska's restaurants, from halibut and chips on the Homer Spit to a reindeer dog in downtown Anchorage.

Alaska Eats is a free guide to eating in Alaska: 6 halibut, salmon and crab houses from Ketchikan to Homer, 6 of Anchorage's Filipino, Korean, Hawaiian, Polynesian and Lao kitchens, plus roadhouses and lodges, reindeer dog stands and sourdough breakfasts, each checked by hand. Behind them, 1,906 restaurants, cafés, bars and espresso stands in 85 towns, from Anchorage, Fairbanks and Juneau to Utqiaġvik. In Anchorage, 458 of them show the Health Department's own inspection score, with its date and the department's next step. No account, no ads.

ALASKA GUIDES
• Halibut, Salmon & Crab: halibut and chips, salmon bakes and king crab.
• Anchorage's Global Kitchens: Filipino, Korean, Hawaiian, Polynesian and Lao kitchens.
• Roadhouses & Lodges: highway roadhouses and lodges, many open summers only.
• Reindeer Dogs and Sourdough: street carts and breakfast counters.
• Award honorees: 7 James Beard semifinalists, finalists and an America's Classic.
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

An independent app, not affiliated with any restaurant, chain or government agency (including the State of Alaska, the Department of Environmental Conservation and the Municipality of Anchorage), or with the James Beard Foundation. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation. Place data from Overture Maps Foundation (CDLA Permissive 2.0) and others; sources and licenses are on the About tab.
```

## What's New (1.0)
`First release: halibut, salmon and crab, Anchorage's global kitchens, roadhouses, reindeer dogs and 1,900+ Alaska restaurants.`

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
