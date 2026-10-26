"""US Census Bureau boundaries for Alaska (public domain; data/raw/census/, downloaded from www2.census.gov) -> data/ak/

- ak_instate.geojson         TIGER/Line 2024 state polygon. It runs out to the 3-nautical-mile line, so places on Ketchikan's and
                             Kodiak's docks and the Homer Spit are inside, while the land border leaves Stewart, B.C. (3 km from Hyder)
                             and the Yukon out, and the maritime line leaves Big Diomede out. Used for the in-state test.
- ak_areas_detail.geojson    the 30 boroughs and census areas (cartographic boundary file, 500k), for each place's area.
- ak_places.pkl              the 355 incorporated cities and census-designated places (500k), for each place's town.
- ak_shapes.json             simplified state and area outlines for the web leaderboard's and the web app's map.

Every longitude east of 180° (the western Aleutians) is written as lon - 360, as in fetch_overture.py, so shapes stay continuous.
"""
import os, json
import numpy as np, pandas as pd, shapely, duckdb
from shapely import wkb
from shapely.geometry import mapping

D = os.path.join(os.path.dirname(__file__), "..", "data")
RAW, OUT = os.path.join(D, "raw", "census"), os.path.join(D, "ak")
con = duckdb.connect()
con.execute("INSTALL spatial; LOAD spatial;")


def unwrap(g):
    return shapely.transform(g, lambda c: np.column_stack([np.where(c[:, 0] > 0, c[:, 0] - 360, c[:, 0]), c[:, 1]])).buffer(0)


def read(zipname, where=""):
    return con.execute(f"SELECT * EXCLUDE (geom), ST_AsWKB(geom) AS g FROM ST_Read('/vsizip/{RAW}/{zipname}') {where}").df()


st = read("tl_2024_us_state.zip", "WHERE STUSPS = 'AK'")
state = unwrap(wkb.loads(bytes(st.g.iat[0])))
json.dump(mapping(state.simplify(0.0005, preserve_topology=True)), open(f"{OUT}/ak_instate.geojson", "w"))

co = read("cb_2024_us_county_500k.zip", "WHERE STATEFP = '02'")
areas = {r.NAMELSAD: unwrap(wkb.loads(bytes(r.g))) for r in co.itertuples()}
json.dump({n: mapping(g.simplify(0.0003, preserve_topology=True)) for n, g in areas.items()}, open(f"{OUT}/ak_areas_detail.geojson", "w"))

pl = read("cb_2024_02_place_500k.zip")
P = pd.DataFrame({"name": pl.NAME, "lsad": pl.NAMELSAD, "geom": [unwrap(wkb.loads(bytes(g))) for g in pl.g]})
P["rep"] = [g.representative_point() for g in P.geom]
P["lat"], P["lon"] = [p.y for p in P.rep], [p.x for p in P.rep]
P["aland"] = pl.ALAND.astype(float)
P.drop(columns=["rep"]).to_pickle(f"{OUT}/ak_places.pkl")


def rings(geom, tol, min_area):
    geom = geom.simplify(tol, preserve_topology=True)
    polys = [p for p in getattr(geom, "geoms", [geom]) if p.geom_type == "Polygon" and p.area >= min_area]
    return [[[round(x, 3), round(y, 3)] for x, y in p.exterior.coords] for p in polys]


land = shapely.union_all(list(areas.values()))
out = {"state": [[r] for r in rings(land, 0.01, 0.002)],
       "counties": [{"name": n, "c": rings(g, 0.02, 0.01)} for n, g in sorted(areas.items())],
       "source": "U.S. Census Bureau, 2024 cartographic boundary files (public domain)"}
json.dump(out, open(f"{OUT}/ak_shapes.json", "w"), separators=(",", ":"))
print("state polygon parts:", len(getattr(state, "geoms", [state])), "| areas:", len(areas), "| places:", len(P),
      "| map rings: state", len(out["state"]), "areas", sum(len(c["c"]) for c in out["counties"]),
      "| ak_shapes.json", os.path.getsize(f"{OUT}/ak_shapes.json") // 1024, "KB")
