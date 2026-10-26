"""Overture address points for Alaska -> data/or/addresses_ak.parquet

Places official records that have no coordinates (OLCC liquor licenses) and researched addresses
the map listings lack. Adapted from co-eats/pipeline/fetch_extras.py.
"""
import os, time
import duckdb

RELEASE = "2026-10-21.0"
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "ak")
t = time.time()
con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial; SET s3_region='us-west-2';")
addr = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=addresses/type=address/*.parquet"
con.execute(f"""COPY (SELECT number, street, unit, postcode, postal_city, address_levels[1].value AS state, address_levels[-1].value AS muni,
  ST_Y(geometry) lat, CASE WHEN ST_X(geometry) > 0 THEN ST_X(geometry) - 360 ELSE ST_X(geometry) END lon FROM read_parquet('{addr}', hive_partitioning=1)
  WHERE country = 'US' AND bbox.ymin BETWEEN 51.0 AND 71.6 AND ((bbox.xmin >= -180 AND bbox.xmax <= -129.8) OR (bbox.xmin >= 172.0 AND bbox.xmax <= 180)))
  TO '{OUT}/addresses_ak.parquet' (FORMAT PARQUET)""")
print(con.execute(f"select count(*), count(*) filter (where state='AK') from '{OUT}/addresses_ak.parquet'").fetchall(), round(time.time() - t), "s")
