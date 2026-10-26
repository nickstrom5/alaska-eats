"""Official records for Alaska -> one table of licensed and permitted food and drink businesses.

Sources (see playbook/12-sources.md). Both are Anchorage's: no statewide list is open to scripts (DEC's permit list and DCCED's business
licenses sit behind DataDome, AMCO's AK-ACCIS is an interactive search), so official coverage is the Municipality of Anchorage only.
- "anc": Anchorage Health Department food establishment permits, from its published inspection file (opendata.muni.org/LIVES/LIVES-flat.csv,
         linked from muni.org's Open Data page): one facility id (FA…) per permit with its name, address, about two-thirds with a point,
         and every inspection since 2000. The file has no facility type, so schools, child care, care homes, hotel pools and spas,
         grocery and gas-station counters, caterers and mobile units are told apart by name. Mobile and temporary permits carry the
         department's own address (825 L St), which says nothing about where they sell.
- "liq": Municipality of Anchorage, Clerk's Office, current liquor licenses (ArcGIS Online layer LiquorLicenses_Hosted, "MOA Clerk
         approved liquor licenses. Does not reflect status of AMCO Licenses"): license number, establishment, license type, service
         location (geocoded), expiration year, endorsements. The Owner field is never read into the app or the site.

load() returns: jur, lic (our id), name, keys (name keys), addr, city, zip, num, street, lat, lon, kind, active, ltype, holder, county,
lottery, expires.
kind: restaurant | bar | brewery | maker | retail | venue | mobile | other.
"""
import os, re, json, glob
import numpy as np, pandas as pd
from common import norm_name, RAW, name_sim, _stems, GENERIC, canon_city

MUNI = os.path.join(RAW, "muni")
ARC = os.path.join(RAW, "arcgis")
DIRS = {"N": "N", "S": "S", "E": "E", "W": "W", "NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"}
TYPES = set("ST STREET AVE AV AVENUE BLVD BOULEVARD RD ROAD DR DRIVE LN LANE CT COURT PL PLACE PKWY PARKWAY TER TRL TRAIL WAY HWY CIR "
            "CIRCLE PLZ SQ MALL BND PASS XING RUN ROW WALK RDG LOOP LP FWY FREEWAY EXPY EXPRESSWAY".split())


def road(a):
    """One spelling for numbered and named highways: 'AK-1' = 'HIGHWAY 1' = 'HWY 1'; 'OLD SEWARD HIGHWAY' = 'OLD SEWARD HWY';
    'MILE 1.5 PARKS HWY' keeps the mile post out of the house number."""
    a = re.sub(r"(\d)\s*&\s*(\d)", r"\1-\2", a.upper())
    a = re.sub(r"\b(AK|US|CR|I)-(\w)", r"\1 \2", a)
    a = re.sub(r"\b(?:STATE (?:HIGHWAY|HWY|ROUTE|RTE)|ALASKA (?:HIGHWAY|HWY|ROUTE)|AK (?:HIGHWAY|HWY|ROUTE)|AK)\s+(?=\d)", "HWY ", a)
    a = re.sub(r"\b(?:US|U S)(?:\s+(?:HIGHWAY|HWY))?\s+(?=\d)", "HWY ", a)
    a = re.sub(r"\bHIGHWAY\b", "HWY", a)
    return re.sub(r"\b(CR|HWY|I) (\w+)\s*-\s*\w+", r"\1 \2", a)


ORD = {"FIRST": "1ST", "SECOND": "2ND", "THIRD": "3RD", "FOURTH": "4TH", "FIFTH": "5TH", "SIXTH": "6TH", "SEVENTH": "7TH",
       "EIGHTH": "8TH", "NINTH": "9TH", "TENTH": "10TH", "ELEVENTH": "11TH", "TWELFTH": "12TH"}


def street_key(a):
    """'2505 Spenard Rd' -> ('2505', 'SPENARD'); '1000 E 36TH AVE' -> ('1000', '36TH'); 'E Northern Lights Blvd' keeps
    'NORTHERN LIGHTS'."""
    if not isinstance(a, str):
        return None, None
    a = re.sub(r"[.,#]", " ", road(a))
    m = re.match(r"^\s*(\d+)[A-Z]?(?:\s*-\s*\d+[A-Z]?)?\s+(.*)$", a)
    if not m:
        return None, None
    words = [w for w in m.group(2).split() if w]
    if len(words) > 1 and words[0] in DIRS:
        words = words[1:]
    core = []
    for w in words:
        if w in TYPES and core:
            break
        core.append(w)
    core = [ORD.get(w, w) for w in core]
    return m.group(1), " ".join(core[:3]) or None


def street_compat(a, b):
    """Same street, or one is a whole-word prefix of the other (a record that truncates "1206 CENTAUR" = Centaur Village Dr)."""
    if not isinstance(a, str) or not isinstance(b, str) or not a or not b:
        return False
    return a == b or a.startswith(b + " ") or b.startswith(a + " ")


def street_nums(a):
    """'157-159 W Main St' -> {'157', '159'}; '2505 Spenard Rd' -> {'2505'}."""
    if not isinstance(a, str):
        return set()
    a = road(a)
    m = re.match(r"^\s*(\d+)[A-Z]?(?:\s*-\s*(\d+)[A-Z]?)?\s", a.upper() + " ")
    if not m:
        return set()
    lo = int(m.group(1)); hi = int(m.group(2)) if m.group(2) else lo
    if hi < lo:   # "1500-02"
        hi = int(str(lo)[: len(str(lo)) - len(m.group(2))] + m.group(2)) if m.group(2) else lo
    return {str(x) for x in range(lo, hi + 1, 2 if (hi - lo) % 2 == 0 else 1)} if 0 <= hi - lo <= 12 else {str(lo)}


def _names(*vals):
    out = []
    for v in vals:
        if not isinstance(v, str):
            continue
        v = re.sub(r"\s*\((?:MOBILE|MOBILE UNIT|COMMISSARY|CATERING|SPECIAL EVENT|SPEC EVENT|TEMP(?:ORARY)? EVENT|CP|TRUCK|TRAILER|INSIDE [^)]*)\)\s*$", "", v, flags=re.I)
        for part in re.split(r"\s*/\s*|\s+\bdba\b\s+|\s+&\s+(?=[A-Z][a-z])|\s*\(\s*|\s*\)\s*", v, flags=re.I):
            k = norm_name(re.sub(r"\b(?:LLC|INC|CORP|CORPORATION|LTD|CO)\b\.?", "", part, flags=re.I))
            if k and k not in out:
                out.append(k)
    return out


def _zip(z):
    z = re.sub(r"\D", "", str(z or ""))
    return z[:5] if len(z) >= 5 else ""


def _row(jur, lic, name, addr, city, z, la, lo, kind, active=True, ltype=None, holder=None, county=None, lottery=False, expires=None):
    num, st = street_key(addr)
    return {"jur": jur, "lic": lic, "name": name, "dba": name, "holder": holder, "keys": _names(name), "addr": addr, "city": city,
            "zip": _zip(z), "num": num, "street": st, "lat": la, "lon": lo, "kind": kind, "active": active, "ltype": ltype,
            "county": county, "lottery": lottery, "expires": expires}


# ---------------------------------------------------------------- Anchorage Health Department permits (the inspection file)
# Permit names carry the part of the business after " - ": "CARRS #1813 - RETAIL MEAT", "SPEEDWAY EXPRESS # 398 - SNACK",
# "WILD SCOOPS - FIXED MOBILE", "LA REYNA - S", "HILTON GARDEN INN - SPA", "CARRS #2628 - STARBUCKS", "EAGLE RIVER ALEHOUSE - DOWNSTAIRS BAR"
MOBILE_PART = {"MOBILE", "FIXED MOBILE", "S", "M", "T", "TFE", "SEASONAL", "PUSH CART", "FIXED MOBILE (C0NNEX)", "FIXED MOBILE / BONIFACE"}
WATER_PART = {"SPA", "POOL", "HOT TUB", "RELAXATION POOL", "SPLASH POOL", "COLD PLUNGE POOL", "LOWER HOT POOL", "UPPER HOT POOL",
              "POOL, THE", "SMALL POOL (WARM WATER POOL)", "COLD WALK THROUGH"}
RETAIL_PART = {"SNACK", "SNACK BAR", "DELI", "BAKERY", "GROCERY", "RETAIL FISH", "RETAIL MEAT", "MEAT", "FISH", "MARKET", "RETAIL STORE",
               "PROCESSOR", "STORAGE", "VENDING MACHINE", "FUELING STATION", "ORIENT EXPRESS", "CONCESSION DELI", "PRODUCE"}
CAFE_PART = {"STARBUCKS": "Starbucks"}
# grocery, big-box, drug and gas-station chains: their counters are store departments (Carrs's "Orient Express" is its in-store counter)
HOST = re.compile(r"^(?:CARRS|SAFEWAY|FRED MEYER|WAL-?MART|COSTCO|SAMS CLUB|TARGET|WALGREENS|CVS|CIRCLE K|SPEEDWAY|HOLIDAY|TESORO|"
                  r"NEW SAGAYA|THREE BEARS|GREEN EARTH|SPENARD ROADHOUSE MARKET)\b")
NONFOOD = re.compile(r"\b(?:SCHOOLS?|ELEMENTARY|ELEM|MIDDLE|JUNIOR HIGH|HIGH SCH\w*|ACADEMY|PRESCHOOL|PRE-?K|HEAD START|ELC|CHARTER|"
                     r"CHILD ?CARE|CHILDCARE|DAY ?CARE|CHILDRENS|KIDS|LEARNING|MONTESSORI|CAMP|ASSISTED LIVING|LIVING HOME|SENIOR|"
                     r"NURSING|PIONEER HOME|HOME CARE|CARE HOME|SHELTER|MISSION|RESCUE|BEAN'?S CAFE|HOSPITAL|MEDICAL|PROVIDENCE|"
                     r"ALASKA NATIVE MEDICAL|CORRECTION\w*|JAIL|DETENTION|YOUTH FACILITY|POOLS?|SPA|HOT TUB|AQUATIC|WATER PARK|"
                     r"SWIM\w*|GYM|FITNESS|YMCA|BOYS AND GIRLS|CHURCH|TEMPLE|MOSQUE|SYNAGOGUE|CHABAD|LUBAVITCH|CANNABIS|"
                     r"DISPENSARY|WEED|VENDING|COMMISSARY|EXTENDED CARE|CORPS|ALASKA CLUB|HT\s*#\s*\d+|DIETARY|HS|K-8|YOUTH|CHILD\w*|PLAYHOUSE|RECOVERY|"
                     r"CONGREGATION|SALVATION ARMY|AWAIC|BOARD ROOM|AIRLINES|PETROLEUM CLUB|MERCANTILE|DEVELOPMENT CENTER|"
                     r"TREATMENT|HOSPICE|CLINIC|SCHULE|KINDERGARTEN|PRE-SCHOOL|HEAD START|DORM\w*|CAFETERIA|EMPLOYEE)\b", re.I)
RETAIL = re.compile(r"\b(?:CARRS|SAFEWAY|FRED MEYER|WAL-?MART|COSTCO|SAMS CLUB|TARGET|WALGREENS|CVS|NATURAL PANTRY|NOURISH|"
                    r"CIRCLE K|SPEEDWAY|HOLIDAY|TESORO|CHEVRON|SHELL|TOTEM|STATIONSTORE|GROCERY|SUPERMARKET|MART|MARKET|"
                    r"STORE|MEAT|MEATS|SEAFOOD MARKET|LIQUOR|PACKAGE|CANDY|NUTRITION)\b", re.I)
# a grocery-store or gas-station name with a real restaurant inside ("TARGET SOUTH - STARBUCKS" is a café): kept as food
STORE_FOOD = re.compile(r"\b(?:STARBUCKS|PIZZA|SUBWAY|TACO|CAFE|COFFEE|ESPRESSO|DELI|GRILL|KITCHEN|SUSHI|BURGER|BAR|PUB|RESTAURANT)\b", re.I)
MOBILE = re.compile(r"\b(?:MOBILE|TRUCK|TRAILER|CART|KIOSK|FOOD TRUCK|TEMPORARY|TEMP|EVENT|CATER\w*|CONCESSIONS?)\b|\(TRUCK\)", re.I)
DEPT_ADDR = re.compile(r"^\s*825\s+L\s+(?:ST|STREET|RD|S)\b", re.I)   # the Anchorage Health Department's own building


def anc_frame():
    """The inspection file, one row per (inspection, violation), with the facility id split from its Envision Connect link."""
    d = pd.read_csv(f"{MUNI}/LIVES-flat.csv", dtype=str)
    d["fid"] = d.business_id.str.extract(r"^(\S+)")[0]
    d["link"] = d.business_id.str.extract(r"\((https://[^)]+)\)")[0]
    d["d"] = d.inspection_date.str[:10]
    global RECORDS_THROUGH
    RECORDS_THROUGH = d.d.max()
    return d


RECORDS_THROUGH = None


def anc_permits():
    d = anc_frame()
    end = pd.Timestamp(RECORDS_THROUGH)
    rows = []
    for fid, g in d.sort_values(["d", "inspection_id"]).groupby("fid", sort=False):
        last = g.iloc[-1]
        name = re.sub(r"\s+", " ", (last.business_name or "").strip())
        base, _, part = name.rpartition(" - ") if " - " in name else (name, "", "")
        base, part = base.strip(" -"), part.strip().upper()
        addr = re.sub(r"\s+", " ", (last.business_address or "").strip())
        u = name.upper()
        dept = bool(DEPT_ADDR.match(addr))
        kind = "restaurant"
        host = HOST.search(base.upper())
        if host and part in CAFE_PART:          # "CARRS #2628 - STARBUCKS": the café inside the store
            base, kind = CAFE_PART[part], "restaurant"
        elif MOBILE.search(u) or dept or part in MOBILE_PART:
            kind = "mobile"
        elif part in WATER_PART or re.search(r"\bPOOL\b|\bSPA\b|HOT TUB|PLUNGE", part):
            kind = "other"
        elif NONFOOD.search(u):
            kind = "other"
        elif host or part in RETAIL_PART or (RETAIL.search(u) and not STORE_FOOD.search(u)):
            kind = "retail"
        descs = g.drop_duplicates("inspection_id").inspection_description.fillna("").str.upper()
        closed = descs.iat[-1] in ("CLOSED FACILITY", "INACTIVATE PERMIT")
        # a permit the department hasn't visited in two years before the file ends is probably gone (most are seen every 12 months)
        recent = pd.Timestamp(g.d.max()) >= end - pd.Timedelta(days=730)
        la = pd.to_numeric(last.business_latitude, errors="coerce"); lo = pd.to_numeric(last.business_longitude, errors="coerce")
        city = canon_city((last.business_city or "").replace("ANCHROAGE", "ANCHORAGE")) or "Anchorage"
        row = _row("anc", "ANC-" + fid, base, None if dept else addr, city, last.business_postal_code, np.nan if dept else la,
                   np.nan if dept else lo, kind, active=bool(recent and not closed), ltype="Food establishment permit",
                   county="Anchorage")
        row["keys"] = _names(base, name)
        row["link"] = last.link if isinstance(last.link, str) else None
        row["last_seen"] = g.d.max()
        rows.append(row)
    return pd.DataFrame(rows)


def anc_inspections():
    """One row per inspection: facility, date, the official score (only Regular, Reinspection and Enforcement inspections carry one),
    type, the department's next step (inspection_description: "SCHEDULE REGULAR INSPECTION WITHIN 12 MONTHS", "REINSPECTION REQUIRED
    WITHIN 6 MONTHS", "CLOSED FACILITY" ...) and the cited violation descriptions, as published. Oldest first."""
    d = anc_frame()
    viol = d.groupby("inspection_id").violation_description.agg(lambda s: [re.sub(r"^\d+\s+", "", v).strip() for v in dict.fromkeys(s.dropna())])
    i = d.drop_duplicates("inspection_id").set_index("inspection_id")
    out = pd.DataFrame({"lic": "ANC-" + i.fid, "d": i.d, "score": pd.to_numeric(i.inspection_score, errors="coerce"),
                        "typ": i.inspection_type.fillna(""), "next": i.inspection_description.fillna(""), "viol": viol.reindex(i.index)})
    return out.sort_values(["lic", "d"]).reset_index(drop=True)


# ---------------------------------------------------------------- Municipality of Anchorage liquor licenses (Clerk's Office)
# Title 4's license names as the Clerk's layer spells them. A Beverage Dispensary serves beer, wine and spirits; a Restaurant or Eating
# Place serves beer and wine with meals; a Package Store sells to take away. Clubs, sporting events, golf courses and theaters are venues.
LIQ_KIND = {"Retail Community-Beverage Dispensary": "bar", "Retail Tourism-Bev Dispensary": "bar", "Beverage Dispensary - Duplicate": "bar",
            "Beverage Dispensary - Tourism Duplicate": "bar", "Retail Community-Resturant/Eating Place": "restaurant",
            "Retail Community-(University) Pub": "bar", "Retail Community-Brewery/Manufacturing-Brewery": "maker",
            "Manufacturing -Brewery": "maker", "Retail Community-Winery/Manufacturing-Winery": "maker",
            "Retail Community-Distillery/Manufacturing-Distillery": "maker", "Retail Community-Package Store": "retail",
            "Retail Community-Club": "venue", "Retail Community-Sporting Event": "venue", "Retail Community-Golf Course": "venue",
            "Retail Community- Theater": "venue", "Wholesale-General": "other", "Wholesale-Limited Beer + Wine": "other"}
LIQ_LABEL = {"bar": "Beverage Dispensary (beer, wine, spirits)", "restaurant": "Restaurant or Eating Place (beer and wine)",
             "maker": None, "retail": "Package Store (to go)", "venue": None, "other": None}
MAKER_LABEL = {"Brewery": "Brewery", "Winery": "Winery", "Distillery": "Distillery"}
ONPREM = ("restaurant", "bar", "brewery", "maker")
LIST_DATE = None


def liq_kind(t):
    return LIQ_KIND.get((t or "").strip(), "other")


def liq_label(t):
    k = liq_kind(t)
    if k == "maker":
        m = re.search(r"Brewery|Winery|Distillery", t or "")
        return f"{MAKER_LABEL[m.group(0)]} (maker)" if m else None
    return LIQ_LABEL.get(k)


def moa_list_date():
    """The Clerk's layer's own PUBDATE (the newest one), as YYYY-MM-DD: the export reads it without rebuilding official.pkl."""
    d = pd.read_csv(f"{ARC}/LiquorLicenses_Hosted.csv", dtype=str, usecols=["PUBDATE"])
    pub = pd.to_datetime(pd.to_numeric(d.PUBDATE, errors="coerce"), unit="ms").max()
    return pub.strftime("%Y-%m-%d") if pub == pub else None


def load_moa_liquor():
    global LIST_DATE
    f = f"{ARC}/LiquorLicenses_Hosted.csv"
    d = pd.read_csv(f, dtype=str).fillna("")
    LIST_DATE = moa_list_date()
    rows = []
    for r in d.itertuples():
        lt = (r.LicenseType or "").strip()
        loc = (r.ServiceLocation or "").strip()
        if not loc or re.match(r"(?i)no premises", loc):
            continue
        street = re.split(r",|\s+(?:STE|SUITE|UNIT|SPC|SPACE|#)\b", loc, flags=re.I)[0].strip()
        try:
            year = int(r.ExpirationYear)
        except (TypeError, ValueError):
            year = None
        la, lo = pd.to_numeric(r.lat or None, errors="coerce"), pd.to_numeric(r.lon or None, errors="coerce")
        name = (r.Establishment or "").strip()
        row = _row("liq", "MOA-" + (r.LicenseNumber or "").strip(), name, street, "Anchorage", "", la, lo, liq_kind(lt),
                   active=bool(year and year >= 2026), ltype=lt, holder=None, county="Anchorage",
                   expires=str(year) if year else None)
        rows.append(row)
    return pd.DataFrame(rows)


def load():
    df = pd.concat([anc_permits(), load_moa_liquor()], ignore_index=True)
    # one business can hold several records (a restaurant permit and its bar permit, a liquor license): same address and a name in common
    df["biz"] = np.arange(len(df))
    town = df.city.fillna("").str.upper().str.strip()
    for num, g in df[df.num.notna() & df.street.notna()].groupby("num"):
        idx = list(g.index)
        if len(idx) < 2 or len(idx) > 400:
            continue
        for x in range(len(idx)):
            for y in range(x + 1, len(idx)):
                a, b = idx[x], idx[y]
                if not street_compat(df.at[a, "street"], df.at[b, "street"]):
                    continue
                if not ((df.at[a, "zip"] and df.at[a, "zip"] == df.at[b, "zip"]) or (town[a] and town[a] == town[b])):
                    continue
                ka, kb = [norm_name(df.at[a, "dba"] or "")], [norm_name(df.at[b, "dba"] or "")]
                if not ka[0] or not kb[0]:
                    continue
                if any(name_sim(p, q) >= 85 or ((_stems(p) - GENERIC) & (_stems(q) - GENERIC)) for p in ka for q in kb):
                    old, new = df.at[b, "biz"], df.at[a, "biz"]
                    df.loc[df.biz == old, "biz"] = new
    return df
