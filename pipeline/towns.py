"""Which Alaska town and which borough or census area a point is in (Census boundaries from fetch_census.py).

Map listings often carry a mailing town or a borough instead of the community: Girdwood's cafés are filed as "Anchorage" (the
municipality), Hyder's Glacier Inn and Copper Center's saloons as "Unorganized Borough", and some chain feeds leave every store
"Anchorage" (Papa Murphy's in Soldotna, Wasilla, Fairbanks and Juneau). The rule, in order:
1. The listing's own town, when it names a community whose centre is within 30 km (the Mat-Su's mailing towns cover a wide area:
   a Wasilla address in the Tanaina CDP stays Wasilla). Anchorage's municipality is 4,400 km², so inside it the own-town test uses
   Anchorage's own communities (Eagle River, Chugiak, Girdwood, Indian) and the zip.
2. Else the Census city or census-designated place the point is in.
3. Else the nearest community within 25 km (a roadhouse a few miles out of town).
4. Else the listing's own town unless it is a borough or area name; else none (the place still shows, with its area).
"""
import os, re, json, math
import pandas as pd
from shapely.geometry import shape, Point
from shapely.prepared import prep
from shapely.strtree import STRtree
from common import AK, canon_city

P = pd.read_pickle(f"{AK}/ak_places.pkl")
P["town"] = P.name.map(lambda n: canon_city(n) or n)
_tree = STRtree(list(P.geom))
AREAS = {n: shape(g) for n, g in json.load(open(f"{AK}/ak_areas_detail.geojson")).items()}
_AREA_P = {n: prep(g) for n, g in AREAS.items()}
# communities inside Anchorage's municipality (no Census places there) and the consolidated city-boroughs' own neighborhoods, with
# their zip codes (USPS) and a centre point
SUB = {"Eagle River": ((61.3214, -149.5679), {"99577"}), "Chugiak": ((61.3876, -149.4836), {"99567"}),
       "Peters Creek": ((61.4097, -149.4525), set()), "Girdwood": ((60.9425, -149.1660), {"99587"}),
       "Indian": ((60.9867, -149.5136), {"99540"}), "Bird Creek": ((60.9726, -149.4629), set()),
       "Joint Base Elmendorf-Richardson": ((61.2580, -149.6900), {"99505", "99506"}),
       "Douglas": ((58.2758, -134.3940), {"99824"}), "Auke Bay": ((58.3836, -134.6450), {"99821"}),
       "Dutch Harbor": ((53.8898, -166.5422), {"99692"}), "Ward Cove": ((55.4092, -131.7230), {"99928"}),
       "Fort Wainwright": ((64.8278, -147.6420), {"99703"})}
CENTRES = {t: (la, lo) for t, la, lo in zip(P.town, P.lat, P.lon)}
CENTRES.update({t: c for t, (c, _) in SUB.items()})
ZIP_TOWN = {z: t for t, (_, zs) in SUB.items() for z in zs}
ANCHORAGE = AREAS["Anchorage Municipality"]
_ANC = prep(ANCHORAGE)
AREA_WORDS = re.compile(r"(?i)\b(?:borough|census area|municipality|unorganized)\b")


def km(a, b):
    return math.hypot((a[0] - b[0]) * 111.2, (a[1] - b[1]) * 111.2 * math.cos(math.radians((a[0] + b[0]) / 2)))


def area_of(lat, lon):
    if lat != lat:
        return None
    p = Point(lon, lat)
    for n, g in _AREA_P.items():
        if g.contains(p):
            return n
    # a dock or a point just offshore (the cartographic outlines stop at the shoreline): the nearest area within ~3 km
    d, n = min((g.distance(p), n) for n, g in AREAS.items())
    return n if d < 0.05 else None


def town_of(lat, lon, own=None, zip5=None):
    if lat != lat:
        return canon_city(own) if own else None
    own = canon_city(own) if isinstance(own, str) and own.strip() else None
    pt = (lat, lon)
    if _ANC.contains(Point(lon, lat)):
        z = (zip5 or "")[:5]
        if own in SUB and km(pt, SUB[own][0]) < 15:
            return own
        if z in ZIP_TOWN and km(pt, CENTRES[ZIP_TOWN[z]]) < 15:
            return ZIP_TOWN[z]
        # no town or zip of its own: only the communities well apart from the city's built-up area (JBER's gates are 5 km from
        # downtown, so a point near it says nothing)
        best = min(((km(pt, c), t) for t, (c, _) in SUB.items() if t in ("Eagle River", "Chugiak", "Peters Creek", "Girdwood", "Indian", "Bird Creek")))
        return best[1] if best[0] < 4 else "Anchorage"
    if own and own in CENTRES and km(pt, CENTRES[own]) < (8 if own in SUB else 30):
        return own
    hits = [i for i in _tree.query(Point(lon, lat)) if P.geom.iat[i].contains(Point(lon, lat))]
    if hits:
        return P.town.iat[min(hits, key=lambda i: P.aland.iat[i])]
    d, t = min((km(pt, c), t) for t, c in CENTRES.items())
    if d < 25:
        return t
    return own if own and not AREA_WORDS.search(own) else None
