# Alaska Eats (ak-eats) — notes for Claude Code sessions

Started 2026-10-26 from `../state-prompts/ALASKA_PROMPT.md` and `../STATE_EATS_PLAYBOOK.md`. Pipeline, app, site and QA ported from
`../or-eats/` (inspection models from `../tx-eats/`, link checker and injection detector from `../co-eats/`); never modify another
state's folder. Guideline 4.3(a): share no places or copy with other states.

- Brand (Nick, 2026-10-26, `playbook/05-naming.md`): "Alaska Eats: Restaurants", Home Screen "Alaska Eats", subtitle "Halibut,
  Roadhouses & Reindeer", salmon fillet icon on flag navy #0F204B (`scripts/make-brand.swift`), navy #0F204B + link navy #2A4A8C + gold
  #FFB612 (fill only), Big Dipper header. Bundle id com.alaskaeats.ios; site alaska.eatsranked.com (until the CNAME: nickstrom5.github.io/alaska-eats).
- Sources and calibration: `playbook/12-sources.md`. Official data is Anchorage only: the Health Department's inspection file (official
  0–100 scores, shown as published with the department's next step; the file stalled 2026-05-19, newest visit 2026-05-18) and the
  Clerk's liquor layer. DEC, DCCED and AMCO sit behind bot checks: never script them. Drafts for Nick in `playbook/records-requests.md`.
- Antimeridian: the pipeline writes longitudes past 180° as lon − 360; the app export and the web data wrap them back to ±180 (MapKit);
  the app's AlaskaOutline, the web app's inAlaska and the map projection unwrap lon > 0 first. In-state test = Census TIGER polygon.
- Private leaderboard artifact: link in `LOCAL.md` (republish site/index.html + alaska.json, ak_detail.json, ak_shapes.json).
- Rebuild: `cd pipeline && ../.venv/bin/python listings.py && ../.venv/bin/python geocode_official.py && ../.venv/bin/python calibrate.py &&
  ../.venv/bin/python alaska.py && AK_APP=1 ../.venv/bin/python alaska.py && cd ..`, then
  `cp data/app/places.json data/app/detail-*.json AlaskaEats/Resources/`, `.venv/bin/python scripts/make-leaderboard.py`,
  `.venv/bin/python scripts/make-site.py`, `.venv/bin/python scripts/make-listing.py`. Website links: `pipeline/check_websites.py`
  (`--retry-transient` after a busy run; back up data/ak/website_check.json before stopping it).
- App: `xcodegen generate`; build/test with `DEVELOPER_DIR="/Applications/Xcode 1.app/Contents/Developer"`, `-derivedDataPath DerivedData`,
  own simulator in data/sim-iphone.txt (one booted at a time on this shared Mac; check `uptime` and the process count first; shut it
  down after use). Both installed Xcodes are 27.1 (27A9269 in Xcode.app, a beta per the prompt; 27A9275 in "Xcode 1.app"): check against
  a public release before any archive.
- Site QA: `.venv/bin/python scripts/qa-site.py` (`--static` for the fast half; `QA_PORT=87xx` on this shared Mac).
- Screenshots: `bash scripts/capture-screenshots.sh <udid>` (home seafood global roadhouses detail map honors oldest saved about; detail
  opens Whisky & Ramen, honored and scored 100), then `bash scripts/site-images.sh`, `scripts/make-site.py`; App Store frames
  `scripts/appstore-screenshots.py` (raw captures in playbook/app-store/raw/{iphone,ipad}).
- Research: `data/research/app/alaska.json` and `jbf.json`; leads that didn't qualify yet in `LEADS.md`. Reindeer (2) and sourdough (1)
  are under the four-place mark for a web page.
- Share sends `Links.site + explore/#p=<id>` (SHARE-LINK.md); no Bib Gourmand (no MICHELIN in Alaska).
- Status 2026-10-26 (afternoon): app bundle 1,906 restaurants in 85 towns, 458 with Anchorage's score, 25 hand-checked (21 with a
  checked website), 10 honored. Unit 26/26, iPhone UI 7/7 and iPad UI 6/6 pass (the iPad launch-time test skipped itself under load;
  mutation: removing the outline's date-line unwrap fails the Attu test); full site QA OK, four QA mutations caught; iPad simulator
  in data/sim-ipad.txt; App Store frames in playbook/app-store/{iphone,ipad}; listing copy in
  playbook/06 and 13. Pipeline rules added today: one permit = one place, a permit counts only within 400 m or at its street number;
  Denny's delivery brands and grocery sushi counters hidden; no Google field in the app's calibration.
- Outward actions (public repo nickstrom5/alaska-eats, Pages, ASC record, Cloudflare CNAME alaska, the DEC request and Anchorage note,
  USPTO check) need Nick's explicit yes each time; never submit for review. Support email nick@eatsranked.com. Nothing is committed.
