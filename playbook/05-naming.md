# Alaska brand (Nick's calls, 2026-10-26, AskUserQuestion)

- **Name:** "Alaska Eats: Restaurants". Home Screen "Alaska Eats" (11 characters). Subtitle "Halibut, Roadhouses & Reindeer" (30).
  Checked 2026-10-26: no app or restaurant named "Alaska Eats" found by web search; "Alaska Eats" is a recipe-category label in the
  Alaska from Scratch blog's menu (alaskafromscratch.com, under Recipes), not an app or a restaurant brand; alaskaeats.com is
  registered to someone else (GoDaddy, 2018), which doesn't matter because the site is alaska.eatsranked.com.
  Other options shown: Last Frontier Eats (lastfrontiereats.com unregistered, weaker search fit), North Star Eats (northstareats.com
  unregistered; North Star is also an Anchorage neighborhood and many Northstar brands).
  Avoided: "Alaska Dining" (an App Store app by Cuisine Development, id694332960), "Midnight Sun" (Midnight Sun Brewing), "Travel Alaska"
  (the state tourism brand), "Alaska Grown" (the state's registered certification mark), the motto "North to the Future".
  Not checked automatically: apps.apple.com and itunes.apple.com disallow Claude, so App Store collisions are a hand search; the USPTO
  lookup (tmsearch.uspto.gov) is done by hand before the App Store record.
- **Icon:** concept A, a wild salmon fillet in plan view on flag navy #0F204B: flesh coral #F2845C, skin edge #C9583A, five white fat lines
  #FBE3D3 (36 px round-cap strokes). `scripts/icon-concepts.swift` `salmon()`; passes `state-prompts/icon-style/check.swift` (4 colours,
  box 0.710 x 0.358, coverage 20.1%). Rejected: B a red king crab in plan view, C a reindeer dog (read as a hot dog, close to Chicago's
  and Michigan's icons). Sheet: `playbook/brand/concepts-sheet.png`, 60 px strip `playbook/brand/strip60-x3.png`.
- **Palette:** option 1, the flag: navy #0F204B (15.8:1 on white) for text, headings and accents; a lighter navy #2A4A8C for links
  (8.5:1); gold #FFB612 only as a fill under navy text (9.0:1; gold text on white is 1.8:1 and fails AA). Avoids the seal and team marks
  (no big-league team; the colleges, UAA green/gold and UAF blue/gold, aren't used).
- **Header element:** the flag's Big Dipper and North Star, eight flat gold five-point stars on a navy band (leaderboard; the app and site
  get the same idea).

## Data calls (same question, 2026-10-26)
- Draft a Public Records Act (AS 40.25) request to DEC for a bulk retail-food inspection extract and the active retail permit list:
  **Nick sends it** (`playbook/records-requests.md`).
- Draft a note asking the Municipality of Anchorage to restart the stalled inspection export (LIVES-flat.csv stopped 2026-05-19):
  **Nick sends it** (`playbook/records-requests.md`).
- Nick downloads by hand: DCCED's Active Business License CSV and an AMCO AK-ACCIS Excel export (steps in `playbook/records-requests.md`);
  the pipeline reads them from `data/raw/hand/` once saved.
