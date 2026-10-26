"""How often is a map listing a real, permitted food business? Measured against Anchorage's permits -> data/ak/calibration*.json

Adapted from or-eats/pipeline/calibrate.py. Alaska's only official list open to scripts is the Municipality of Anchorage's: every
food establishment there needs a health permit, and the Health Department's inspection file names each one (official.py). So in
Anchorage the match rate is close to a real "is this a working food business" rate (Oregon's liquor licenses only gave a floor):
- Match rate: the share of each listing group that matches an active Anchorage food permit (fixed or mobile) or an active
  on-premises liquor license from the Clerk's list.
- Coverage: the share of active fixed food-service permits (restaurants, cafés, bars with food; not schools, care homes, pools, store
  departments or mobile units) found among the open listings.
- Google 2021 open: the share of each group also listed as open by Google in Sep 2021 (UCSD snapshot), Idaho's second signal.
"Active" means the department saw the permit within two years before its file ends (2026-05-18) and its last visit didn't close it.
Places that opened after May 2026 have no permit in the file yet, so the newest listings undercount a little.
A match is the same business name nearby, or the same street address with a distinctive name word in common.
"""
import json
import numpy as np, pandas as pd
from common import AK
from listings_util import official_match
from towns import area_of
import official

o = pd.read_pickle(f"{AK}/stage1.pkl")
F = pd.read_pickle(f"{AK}/official.pkl")
F["county"] = [area_of(la, lo) if la == la else ("Anchorage Municipality" if c == "Anchorage" else c) for la, lo, c in zip(F.lat, F.lon, F.county)]
F.loc[F.county.isna() & F.jur.isin(["anc", "liq"]), "county"] = "Anchorage Municipality"
F.to_pickle(f"{AK}/official.pkl")
base = ~o.j_junk & ~o.j_outside
print("listings with an area:", int(o.county.notna().sum()), "of", len(o))


def groups(L, app=False):
    s = L.src.fillna("none")
    if app:
        conf = L.confidence.fillna(0)
        return np.select([L.ov_closed | L.j_closedname, (s == "meta") & (conf >= 0.95), (s == "meta") & (conf >= 0.9),
                          s.isin(["AllThePlaces", "DAC"]), (s == "BrightQuery") & (conf >= 0.95), s == "meta"],
                         ["closed per Overture/name", "meta_high", "meta_mid", "brand_feed", "bq_high", "meta_low"], "other_sources")
    return np.select([L.closed21, L.ov_closed, (s == "meta") & L.in21, s == "meta", s.isin(["AllThePlaces", "DAC"]) & L.in21,
                      s.isin(["AllThePlaces", "DAC"]), L.in21, s == "Foursquare", s == "BrightQuery", s == "Microsoft"],
                     ["Google 2021 says closed", "Overture says closed", "Meta + open in Google 2021", "Meta only",
                      "brand feed + Google 2021", "brand feed only", "Foursquare/BrightQuery/Microsoft + Google 2021",
                      "Foursquare only", "BrightQuery only", "Microsoft only"], "other")


ANC = "Anchorage Municipality"
FOOD = F.active & (((F.jur == "anc") & F.kind.isin(["restaurant", "mobile"])) | ((F.jur == "liq") & F.kind.isin(list(official.ONPREM))))
L = o[base & (o.county == ANC)].reset_index(drop=True)
R = F[FOOD & (F.county == ANC)].reset_index(drop=True)
m = official_match(L, R)
L["hit"] = L.index.map(lambda i: i in m)
L["hit_permit"] = L.index.map(lambda i: i in m and R.jur.iat[m[i]] == "anc")
L["g_open"] = L.in21 & ~L.closed21
res, app = {}, {}
for mode, store in ((False, res), (True, app)):
    L["grp"] = groups(L, mode)
    t = L.groupby("grp").agg(n=("id", "size"), official=("hit", "mean"), permit=("hit_permit", "mean"), g_open=("g_open", "mean")).sort_values("n", ascending=False)
    print(f"\n== Anchorage ({'app grouping' if mode else 'web grouping'}): {len(L)} listings, {len(R)} active food permits and on-premises licenses")
    print(t.assign(official=(t.official * 100).round(1), permit=(t.permit * 100).round(1), g_open=(t.g_open * 100).round(1)).to_string())
    store[ANC] = {"listings": int(len(L)), "official_records": int(len(R)),
                  "groups": {g: {"n": int(r.n), "official": round(float(r.official), 3), "permit": round(float(r.permit), 3),
                                 "google21_open": round(float(r.g_open), 3)} for g, r in t.iterrows()}}
# the other direction: how many permitted fixed food businesses do the (cleaned, open) map listings hold?
keepish = ~(L.ov_closed | L.j_closedname | L.closed21)
got = set(R.biz.iloc[[m[i] for i in L.index[keepish] if i in m]])
Rr = R[(R.jur == "anc") & (R.kind == "restaurant")].drop_duplicates("biz")
cover = float(np.mean([b in got for b in Rr.biz])) if len(Rr) else None
print(f"\nAnchorage: permitted fixed food businesses found among open map listings: {cover*100:.1f}% of {len(Rr)}")
res[ANC]["coverage"] = round(cover, 3)
res[ANC]["official_food"] = int(len(Rr))
missing = Rr[~Rr.biz.isin(got)]
print("not in the listings (sample):", missing.name.head(25).tolist())
json.dump({"areas": res, "unplaced_official_records": int(F.lat.isna().sum()), "permits_through": official.RECORDS_THROUGH,
           "liquor_list": official.LIST_DATE},
          open(f"{AK}/calibration.json", "w"), indent=1)
json.dump(app, open(f"{AK}/calibration_app.json", "w"), indent=1)
