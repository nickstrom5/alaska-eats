"""Download the Overture Maps extracts that alaska.py reads -> data/ak/

- overture_ak_bbox.parquet     every place in Alaska's two longitude ranges (name, category, address, point)
- overture_ak_sources.parquet  which datasets each Alaska eating/drinking listing came from (Meta, Foursquare, ...)
- ak_shapes.json               simplified state and borough outlines for the map (longitudes east of 180° shifted by -360)
- ak_state_detail.geojson      the state outline at full detail, for the in-state test (same shift)
- ak_counties_detail.geojson   borough / census-area outlines for assigning each place (not shipped)

Reads the public Overture bucket over S3 with DuckDB (no account needed). Adapted from or-eats/pipeline/fetch_overture.py.
Alaska crosses the 180th meridian (the western Aleutians, Attu to Semisopochnoi, sit at 172°E–180°), so there is no single
longitude box: the filter is two ranges, and every longitude east of 180° is written as lon - 360 (Attu 173°E -> -187°) so the
outline and the points stay one continuous shape for drawing and for the point-in-polygon test.
"""
import os, json, time
import duckdb
from shapely import wkb
from shapely.geometry import mapping
import numpy as np
import shapely

RELEASE = "2026-10-21.0"
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "ak")
# Alaska: 51.2°N (Amchitka) to 71.4°N (Utqiaġvik); 129.97°W (Hyder) west to 180°, and 172.4°E (Attu) to 180°.
# Yukon/BC points in the margin are dropped later by the state outline.
BBOX = """bbox.ymin BETWEEN 51.0 AND 71.6 AND (
  (bbox.xmin >= -180 AND bbox.xmax <= -129.8) OR (bbox.xmin >= 172.0 AND bbox.xmax <= 180))"""
EAT = "('restaurant','casual_eatery','bar','fast_food_restaurant','coffee_shop','cafe','smoothie_juice_bar','brewery','food_court','food_truck_stand')"
os.makedirs(OUT, exist_ok=True)

con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial; SET s3_region='us-west-2';")
places = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=places/type=place/*.parquet"

t = time.time()
if not os.path.exists(f"{OUT}/overture_ak_bbox.parquet"):
    con.execute(f"""
COPY (
  SELECT id, names.primary AS name, basic_category AS cat, taxonomy.primary AS tax, taxonomy.hierarchy AS hier, confidence,
         operating_status AS status, brand.names.primary AS brand, addresses[1].freeform AS street, addresses[1].locality AS city,
         addresses[1].postcode AS zip, addresses[1].region AS region, ST_Y(geometry) AS lat,
         CASE WHEN ST_X(geometry) > 0 THEN ST_X(geometry) - 360 ELSE ST_X(geometry) END AS lon, websites[1] AS web,
         phones[1] AS phone
  FROM read_parquet('{places}', hive_partitioning=1) WHERE {BBOX}
) TO '{OUT}/overture_ak_bbox.parquet' (FORMAT PARQUET)""")
    print("places in bbox", round(time.time() - t), "s", flush=True)
if not os.path.exists(f"{OUT}/overture_ak_sources.parquet"):
    con.execute(f"""
COPY (
  SELECT id, list_transform(sources, lambda x: x.dataset) AS ds, list_transform(sources, lambda x: x.update_time) AS ut,
         list_transform(sources, lambda x: x.record_id) AS rid,
         len(socials) AS n_soc, len(websites) AS n_web, len(phones) AS n_ph
  FROM read_parquet('{places}', hive_partitioning=1)
  WHERE {BBOX} AND basic_category IN {EAT}
) TO '{OUT}/overture_ak_sources.parquet' (FORMAT PARQUET)""")
    print("sources", round(time.time() - t), "s", flush=True)

areas = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=divisions/type=division_area/*.parquet"
rows = con.execute(f"""
  SELECT subtype, names.primary AS name, ST_AsWKB(geometry) AS g
  FROM read_parquet('{areas}', hive_partitioning=1)
  WHERE country = 'US' AND region = 'US-AK' AND subtype IN ('region', 'county') AND class = 'land'""").fetchall()


def unwrap(geom):
    """Shift longitudes east of 0° by -360 so a shape cut at the antimeridian joins back up."""
    return shapely.transform(geom, lambda c: np.column_stack([np.where(c[:, 0] > 0, c[:, 0] - 360, c[:, 0]), c[:, 1]]))


def rings(geom, tol, min_area):
    geom = geom.simplify(tol, preserve_topology=True)
    polys = [p for p in getattr(geom, "geoms", [geom]) if p.geom_type == "Polygon" and p.area >= min_area]
    return [[[round(x, 3), round(y, 3)] for x, y in p.exterior.coords] for p in polys]


out = {"state": None, "counties": []}
det = {}
for sub, name, g in rows:
    geom = unwrap(wkb.loads(bytes(g))).buffer(0)
    if sub == "region":
        json.dump(mapping(geom.simplify(0.0005, preserve_topology=True)), open(f"{OUT}/ak_state_detail.geojson", "w"))
        # Alaska has ~2,600 named islands; keep every ring big enough to hold a town (0.0004 sq deg ≈ 1.5 km²)
        out["state"] = [[r] for r in rings(geom, 0.004, 0.0004)]
    else:
        out["counties"].append({"name": name, "c": rings(geom, 0.006, 0.001)})
        det[name] = mapping(geom.simplify(0.0003, preserve_topology=True))
json.dump(det, open(f"{OUT}/ak_counties_detail.geojson", "w"))
json.dump(out, open(f"{OUT}/ak_shapes.json", "w"), separators=(",", ":"))
print("outlines: state", len(out["state"] or []), "rings +", len(out["counties"]), "boroughs/census areas;", round(time.time() - t), "s total")

# The in-state test. Overture's land outline stops at the shoreline, so 171 listings on Ketchikan's, Petersburg's and Kodiak's
# docks and the Homer Spit sit 10-350 m offshore. Widen the outline about 2 km (0.02°), then take back the neighbours' land so
# Stewart, B.C. (3 km from Hyder), the Yukon side of the border and Big Diomede (4 km from Little Diomede) stay out.
if not os.path.exists(f"{OUT}/ak_instate.geojson"):
    nb = con.execute(f"""
      SELECT names.primary, ST_AsWKB(geometry) FROM read_parquet('{areas}', hive_partitioning=1)
      WHERE subtype = 'region' AND class = 'land' AND region IN ('CA-BC', 'CA-YT', 'RU-CHU')""").fetchall()
    land = shapely.union_all([unwrap(wkb.loads(bytes(g))).buffer(0) for sub, name, g in rows if sub == "region"])
    near = shapely.union_all([unwrap(wkb.loads(bytes(g))).buffer(0) for _, g in nb])
    inst = land.buffer(0.02).difference(near).simplify(0.001, preserve_topology=True)
    json.dump(mapping(inst), open(f"{OUT}/ak_instate.geojson", "w"))
    print("in-state test outline: neighbours", [n for n, _ in nb], round(time.time() - t), "s")
