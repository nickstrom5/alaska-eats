// Alaska Eats web app: the iPhone app's guides, search, filters, map and place details, in the browser.
// Keep its guide rules in step with AlaskaEats/Models/Guide.swift and its search with AlaskaEats/Models/Search.swift.
// Same data as the app, split by scripts/make-site.py into data/core.json (list, search and map columns), data/ids.json (each place's
// stable id, fetched at the first tap, key, scroll or hover, so a visit that only looks doesn't download it; saved places and #p= links
// wait for it) and data/detail-<borough>.json (phones, websites, notes, Anchorage permits and liquor licenses, inspection histories),
// fetched per borough or census area when a place there is opened. Every data file carries the version of the core.json it was built with (core.json "ver",
// detail "_v", ids "v"): files from another build are fetched again, and never mixed in, because ids and details are keyed by row. No cookies, no trackers; saved places and the last guide live in this browser's localStorage only
// (keys start with akeats-: other state sites share the nickstrom5.github.io origin).
// Alaska crosses the 180th meridian: the data keeps ordinary longitudes (Attu is at +172.9), and the map and the outline test move
// anything east of 0 to lon - 360 so the Aleutians draw and test as one chain.
// The page runs under a strict Content-Security-Policy (hash-pinned inline script and style): never add inline event handlers or
// inline style attributes to the HTML built here; set properties from code instead.
(() => {
  "use strict";
  const BASE = document.documentElement.dataset.base || "";
  const $ = (s) => document.querySelector(s);
  // every value that goes into innerHTML passes through esc(), numbers included (the data file is trusted, but not that much)
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const own = (o, k) => typeof k === "string" && Object.prototype.hasOwnProperty.call(o, k);   // Object.hasOwn, for older Safari too
  const PREFIX = "akeats-";
  const store = {
    get(k, d) { try { const v = localStorage.getItem(PREFIX + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
    set(k, v) { try { localStorage.setItem(PREFIX + k, JSON.stringify(v)); } catch { /* private mode */ } },
  };
  // only http(s) links leave the page; bare hosts ("example.com/menu") get https://
  const safeUrl = (u) => {
    u = String(u ?? "").trim();
    if (/^https?:\/\/[^\s"'<>\\]+$/i.test(u)) return u;
    if (/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}(?:[/?#][^\s"'<>\\]*)?$/i.test(u)) return "https://" + u;
    return null;
  };
  const num = (x) => (x == null || x === "" || !Number.isFinite(Number(x)) ? null : Number(x));
  const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const fmtDate = (s) => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s ?? "")); return m ? `${MONTHS[+m[2] - 1]} ${+m[3]}, ${m[1]}` : String(s ?? ""); };
  const fmtMonth = (s) => { const m = /^(\d{4})-(\d{2})/.exec(String(s ?? "")); return m ? `${MONTHS[+m[2] - 1]} ${m[1]}` : String(s ?? ""); };
  // the Municipality of Anchorage's Open Data page (the inspection file and the Clerk's liquor layer) and the Health Department's lookup
  const ANC_DATA = "https://www.muni.org/Departments/it/Pages/opendata.aspx";
  const ANC_LOOKUP = "https://anchorageonline.envisionconnect.com/#/pa1/search";
  const ANC_REPORT = /^https:\/\/anchorageonline\.envisionconnect\.com\/#\/pa1\/detail\/[A-Za-z0-9]+\/[A-Za-z0-9]+$/;
  // AlaskaEats/Models/Place.swift's Inspections.scale
  const INS_SCALE = "Scores are the points a place kept out of 100 at a regular, reinspection or enforcement visit; each cited item takes points off. Complaint and opening visits carry no score. The department publishes no pass/fail line.";

  // ---------------------------------------------------------------- search (a port of AlaskaEats/Models/Search.swift)
  const typeSyn = { avenue: "ave", av: "ave", street: "st", boulevard: "blvd", road: "rd", drive: "dr", place: "pl", court: "ct",
    parkway: "pkwy", highway: "hwy", lane: "ln", trail: "trl", circle: "cir", terrace: "ter" };
  // directions and road names: "east fifth" finds "E 5th Ave", "seward highway" finds "Seward Hwy"
  const syn = { ...typeSyn, north: "n", south: "s", east: "e", west: "w", northwest: "nw", northeast: "ne", southwest: "sw", southeast: "se",
    saint: "st", mount: "mt", fort: "ft", interstate: "i", ih: "i", freeway: "fwy", expressway: "expy" };
  const abbrs = new Set(Object.values(syn)), typeAbbrs = new Set(Object.values(typeSyn));
  const SEAFOOD = 1, REINDEER = 2, SOURDOUGH = 4, ROADHOUSE = 8, GLOBAL = 16, OLDEST = 32;
  // a dish ("halibut", "king crab") is not a tag: it's in names and each hand-checked place's search text, so it finds those places
  const tagPhrases = [["reindeer dogs", REINDEER], ["reindeer dog", REINDEER], ["reindeer sausage", REINDEER], ["sourdough pancakes", SOURDOUGH],
    ["sourdough", SOURDOUGH], ["roadhouses", ROADHOUSE], ["roadhouse", ROADHOUSE], ["salmon bake", SEAFOOD], ["global kitchens", GLOBAL]];
  // letters NFD doesn't take apart (Search.swift's unaccented table): "bruto" finds "Brutø"
  const UNACCENTED = { "ø": "o", "æ": "ae", "œ": "oe", "đ": "d", "ł": "l", "ß": "ss", "þ": "th", "ı": "i" };
  function normalize(s) {
    let t = String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[øæœđłßþı]/g, (c) => UNACCENTED[c]);
    t = t.replace(/\b([a-z0-9])\s*&\s*([a-z0-9])\b/g, "$1$2").replace(/&/g, " and ").replace(/['’`]/g, "");
    return t.replace(/[^\p{L}\p{N}]+/gu, " ").trim();
  }
  const normAddr = (s) => normalize(s).split(" ").map((w) => (own(syn, w) ? syn[w] : w)).join(" ");

  function parse(text) {
    const q = { tokens: [], town: null, townPhrase: null, tag: 0, tagPhrase: null, tagStem: null, townNeedle: null };
    let raw = normalize(text).split(" ").filter(Boolean);
    if (!raw.length) return q;
    let mapped = raw.map((w) => (own(syn, w) ? syn[w] : w));
    const find = (phrase) => {
      const p = phrase.split(" ");
      for (let i = 0; i + p.length <= mapped.length; i++) if (p.every((w, k) => mapped[i + k] === w)) return [i, i + p.length];
      return null;
    };
    const cut = ([a, b]) => { const words = raw.slice(a, b).join(" "); raw.splice(a, b - a); mapped.splice(a, b - a); return words; };
    for (const [phrase, tag] of tagPhrases) { const r = find(normalize(phrase)); if (r) { q.tag = tag; q.tagPhrase = cut(r); break; } }
    if (q.tagPhrase) { const stem = normalize(q.tagPhrase).replace(/s$/, ""); q.tagStem = stem ? " " + stem : null; }
    // the longest town named in the query wins, unless a street type follows it ("houston st" is a street)
    for (const key of TOWN_KEYS_BY_LENGTH) {
      const r = find(key);
      if (r && !(r[1] < mapped.length && typeAbbrs.has(mapped[r[1]]))) { q.town = TOWN_KEYS[key]; q.townPhrase = cut(r); q.townNeedle = " " + normalize(q.townPhrase); break; }
    }
    const stop = new Set(["the", "and", "of", "a", "in", "near", "me"]);   // "halibut near me" isn't a place named "Me"
    let idx = raw.map((_, i) => i);
    // stop words stay only when they're all there is ("the"); next to a guide or a town ("roadhouse near me") they go
    if (q.tag || q.town || idx.some((i) => !stop.has(mapped[i]))) idx = idx.filter((i) => !stop.has(mapped[i]));
    idx.forEach((i, n) => {
      const token = raw[i], isLast = n === idx.length - 1;
      if (own(syn, token)) { q.tokens.push([` ${syn[token]} `, ` ${token}`]); return; }
      const whole = (abbrs.has(token) && (!isLast || token.length > 1)) || (token.length <= 2 && !isLast);
      const needles = [" " + token + (whole ? " " : "")];
      if (isLast && token.length >= 3) for (const [word, abbr] of Object.entries(typeSyn)) if (word !== token && word.startsWith(token)) needles.push(` ${abbr} `);
      q.tokens.push(needles);
    });
    // "spenard rd": a finished street type sticks to the word before it
    if (q.tokens.length >= 2 && idx.length && typeAbbrs.has(mapped[idx[idx.length - 1]])) {
      const last = idx[idx.length - 1], prev = idx[idx.length - 2];
      q.tokens.splice(-2, 2, [` ${mapped[prev]} ${mapped[last]} `, ` ${raw[prev]} ${raw[last]}`]);
    }
    return q;
  }
  const qEmpty = (q) => !q.tokens.length && !q.town && !q.tag;
  function matches(p, q) {
    if (q.tag && !(p.g & q.tag)) { if (!q.tagStem || !p.nameText.includes(q.tagStem)) return false; }
    if (q.town && p.c !== q.town) { if (!q.townNeedle || !p.nameText.includes(q.townNeedle)) return false; }
    return q.tokens.every((needles) => needles.some((n) => p.search.includes(n)));
  }
  const nameMatches = (p, q) => q.tokens.length && q.tokens.every((needles) => needles.some((n) => p.nameText.includes(n)));

  // ---------------------------------------------------------------- guides (AlaskaEats/Models/Guide.swift)
  const NO_GRADE = "Shown as the Anchorage Health Department published it; we compute no grade.";
  const hcTag = (t) => (p) => p.hc && Boolean(p.g & t);
  const HC_SORTS = ["featured", "nearest", "name"];
  const GUIDES = {
    seafood: { title: "Halibut, Salmon & Crab", sub: "Hand-checked halibut and chips, salmon bakes and king crab", inc: hcTag(SEAFOOD), sorts: HC_SORTS },
    global: { title: "Anchorage's Global Kitchens", sub: "Hand-checked Filipino, Korean, Hawaiian, Polynesian and Lao kitchens", inc: hcTag(GLOBAL), sorts: HC_SORTS },
    roadhouse: { title: "Roadhouses & Lodges", sub: "Hand-checked roadhouses and lodges, many open summers only", inc: hcTag(ROADHOUSE), sorts: HC_SORTS },
    reindeer: { title: "Reindeer Dogs", sub: "Hand-checked carts and kitchens serving reindeer sausage", inc: hcTag(REINDEER), sorts: HC_SORTS },
    sourdough: { title: "Sourdough", sub: "Hand-checked sourdough pancakes, bread and breakfasts", inc: hcTag(SOURDOUGH), sorts: HC_SORTS },
    honors: { title: "James Beard Honors", sub: "James Beard finalists, semifinalists and America's Classics", inc: (p) => p.jb, sorts: ["iconic", "nearest"] },
    oldest: { title: "Oldest Places", sub: "Founding years checked at the same address, oldest first", inc: (p) => p.f != null && p.hc && Boolean(p.g & OLDEST), sorts: ["oldest"], ranked: true },
    inspections: { title: "Anchorage Inspection Scores", sub: "The Anchorage Health Department's own scores", inc: (p) => p.idt != null && p.isc != null, sorts: ["recent", "high", "low", "nearest"] },
    all: { title: "All Restaurants", sub: "Restaurants, cafés, bars and espresso stands statewide", inc: () => true, sorts: ["name", "nearest"] },
    saved: { title: "Saved", sub: "Places you saved in this browser", inc: (p) => saved.has(p.id), sorts: ["name", "nearest"] },
  };
  const HC_GUIDES = ["seafood", "global", "roadhouse", "reindeer", "sourdough"];
  const SORT_LABEL = { featured: "Featured first", nearest: "Nearest", oldest: "Oldest first", name: "A to Z", iconic: "America's Classics, then finalists",
    recent: "Latest inspection first", high: "Highest inspection score", low: "Lowest inspection score" };
  // the department's next steps (core.json "results"), shown as published
  let RESULTS = [];
  const bandOf = (b) => (Number.isInteger(b) && b >= 0 && b < RESULTS.length ? RESULTS[b] : "");
  // amber when the department will be back sooner or acted (a reinspection, enforcement, a closure); never red: it's not a verdict
  const resCls = (b) => { const l = bandOf(b); return /^(Reinspection|Enforcement|Closed)/.test(l) ? "mid" : l ? "ok" : "x"; };
  const CHIP = [[SEAFOOD, "Halibut, salmon & crab"], [REINDEER, "Reindeer dogs"], [SOURDOUGH, "Sourdough"], [ROADHOUSE, "Roadhouse"], [GLOBAL, "Global kitchen"]];
  const FIRST = "seafood";   // the guide the page opens on

  // ---------------------------------------------------------------- state
  let P = [], CAL = {}, TOWN_KEYS = {}, TOWN_KEYS_BY_LENGTH = [], GENERATED = "", META = {};
  let here = null, shown = 100, current = [], view = "list";
  const savedRaw = store.get("saved", []);
  const saved = new Set(Array.isArray(savedRaw) ? savedRaw.filter((x) => typeof x === "string" && x.length < 64) : []);
  const st = { g: FIRST, q: "", sort: "", town: "", cuisine: "", chains: false, p: "" };

  const miles = (a, b) => {
    const r = Math.PI / 180, dLa = (b.la - a.la) * r, dLo = (b.lo - a.lo) * r;
    const h = Math.sin(dLa / 2) ** 2 + Math.cos(a.la * r) * Math.cos(b.la * r) * Math.sin(dLo / 2) ** 2;
    return 3958.8 * 2 * Math.asin(Math.sqrt(h));
  };
  const milesText = (m) => (m < 10 ? m.toFixed(1) : Math.round(m)) + " mi";

  function order() {
    const g = GUIDES[st.g];
    let o = st.sort && g.sorts.includes(st.sort) ? st.sort : HC_GUIDES.includes(st.g) && here ? "nearest" : g.sorts[0];
    if (o === "nearest" && !here) o = g.sorts.find((s) => s !== "nearest") || o;   // no location yet: say what the list is really sorted by
    return o;
  }

  function allows(p) {
    if (st.town && p.c !== st.town) return false;
    if (st.cuisine && p.cu !== st.cuisine) return false;
    if (st.chains && p.ch >= 5) return false;
    return true;
  }

  function list() {
    const g = GUIDES[st.g], q = parse(st.q), o = order();
    if (qEmpty(q) && st.q.trim()) return [];   // typed something, but nothing searchable ("🍕", "!!!")
    let out = P.filter((p) => g.inc(p) && allows(p) && (qEmpty(q) || matches(p, q)));
    const byName = (a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : a.i - b.i);
    if (o === "nearest" && here) {
      const dist = new Map(out.map((p) => [p, p.la != null ? miles(here, p) : Infinity]));
      out.sort((a, b) => dist.get(a) - dist.get(b) || byName(a, b));
    }
    else if (o === "featured") out.sort((a, b) => (b.ip ?? -1) - (a.ip ?? -1) || (a.f ?? 9999) - (b.f ?? 9999) || byName(a, b));
    else if (o === "oldest") out.sort((a, b) => (a.f ?? 9999) - (b.f ?? 9999) || byName(a, b));
    else if (o === "iconic") {   // the James Beard honor, then name (the app's order)
      const jb = (p) => (p.h & 1 ? 4 : p.h & 2 ? 3 : p.h & 4 ? 2 : p.h & 8 ? 1 : 0);
      out.sort((a, b) => jb(b) - jb(a) || byName(a, b));
    }
    else if (o === "recent") out.sort((a, b) => String(b.idt || "").localeCompare(String(a.idt || "")) || byName(a, b));
    else if (o === "high" || o === "low") {   // the department's score, then the latest visit first (the app's order)
      const hi = o === "high";
      const key = (p) => p.isc ?? (hi ? -1 : 999);
      out.sort((a, b) => (hi ? key(b) - key(a) : key(a) - key(b)) || String(b.idt || "").localeCompare(String(a.idt || "")) || byName(a, b));
    }
    else out.sort(byName);
    if (q.tokens.length && !g.ranked) {       // name matches first when searching
      const named = out.filter((p) => nameMatches(p, q));
      if (named.length && named.length < out.length) { const ids = new Set(named); out = named.concat(out.filter((p) => !ids.has(p))); }
    }
    return out;
  }

  // ---------------------------------------------------------------- rendering
  const jbLabel = (p) => (p.h & 1 ? "America's Classic" : p.h & 2 ? "James Beard winner" : p.h & 4 ? "James Beard finalist" : p.h & 8 ? "James Beard semifinalist" : p.jb ? "James Beard (restaurateur)" : null);
  function chips(p, max) {
    const c = [];
    const jb = jbLabel(p);
    if (jb) c.push(`<span class="tag tag-jb">${esc(jb)}</span>`);
    for (const [t, label] of CHIP) if (p.g & t && p.hc) c.push(`<span class="tag">${esc(label)}</span>`);
    if (p.hc && p.g & OLDEST && p.f) c.push(`<span class="tag tag-plain">Since ${esc(p.f)}</span>`);
    if (p.ch >= 5) c.push(`<span class="tag tag-plain">Chain · ${esc(p.ch)}</span>`);
    if (p.t === 0 && !p.h && !p.hc) c.push('<span class="tag tag-dash">Listing only</span>');
    return (max ? c.slice(0, max) : c).join("");
  }

  function metric(p, o) {
    // an inspection row always shows its score and the department's next step (the distance goes in the address line)
    if ((st.g === "inspections" || ["recent", "high", "low"].includes(o)) && p.idt && p.isc != null) return [`${p.isc}/100`, bandOf(p.ib), "ins"];
    if (o === "nearest" && here && p.la != null) return [milesText(miles(here, p)), "away"];
    if (p.f && st.g !== "all" && st.g !== "inspections") return [String(p.f), "since"];
    return null;
  }

  function render() {
    const g = GUIDES[st.g], o = order();
    if (st.g === "saved" && !idsReady) loadIds().then(() => { if (st.g === "saved") render(); });
    current = list();
    document.querySelectorAll(".ex-guides button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.g === st.g)));
    $("#ex-sub").textContent = g.sub + (st.g === "inspections" && META.through && META.through.anc
      ? `. Scored visits through ${fmtDate(META.through.anc)}: the department's open-data file hasn't been updated since ${fmtDate(META.fileMod)}, so newer visits are only on its own site.` : "");
    const sortSel = $("#ex-sort");
    sortSel.innerHTML = g.sorts.map((s) => `<option value="${esc(s)}"${s === o ? " selected" : ""}>${esc(SORT_LABEL[s])}</option>`).join("");
    sortSel.disabled = g.sorts.length < 2;
    const filters = [st.town && `in ${st.town}`, st.cuisine && st.cuisine, st.chains && "no chains"].filter(Boolean);
    $("#ex-count").textContent = `${current.length.toLocaleString()} ${current.length === 1 ? "place" : "places"} · ${SORT_LABEL[o]}` + (filters.length ? ` · ${filters.join(", ")}` : "");
    $("#ex-clear").hidden = !filters.length;
    // Near me stays: each tap asks for a fresh fix (people move), and it's how to retry after a timeout
    if (view === "list") renderList(o); else drawMap();
    saveHash();
  }

  // typing searches only the open guide (the page opens on Halibut, Salmon & Crab): when that finds little, the same words across every
  // restaurant, with the same filters, so a famous place outside the guide isn't a dead end
  const FEW = 5;
  function elsewhereCount() {
    const q = parse(st.q);
    if (st.g === "all" || qEmpty(q) || current.length >= FEW) return 0;
    let n = 0;
    for (const p of P) if (allows(p) && matches(p, q)) n++;
    return n > current.length ? n : 0;
  }
  const allButton = (n) => `<button type="button" class="ex-small" id="ex-all">Search all restaurants (${esc(n.toLocaleString())} ${n === 1 ? "match" : "matches"})</button>`;
  function wireAll() {
    const b = $("#ex-all");
    if (b) b.onclick = () => { st.g = "all"; st.sort = ""; shown = 100; render(); const r = $(".ex-row"); if (r) r.focus(); };
  }

  function renderList(o) {
    const ol = $("#ex-list");
    const g = GUIDES[st.g];
    const elsewhere = elsewhereCount();
    if (!current.length) {
      ol.innerHTML = `<li class="ex-empty">${st.g === "saved" && !idsReady ? "Loading your saved places…" : st.g === "saved" && idsFailed && saved.size ? "Your saved places couldn't load: you may be offline, or the site was just updated. Reload the page to try again." : elsewhere ? `Nothing in ${esc(g.title)} matches that. ${allButton(elsewhere)}` : st.g === "saved" ? "Nothing saved yet. Open a place and tap Save to keep it here, in this browser." : "No places match. Try fewer words or clear the filters."}</li>`;
      wireAll();
      $("#ex-more").hidden = true;
      return;
    }
    ol.innerHTML = current.slice(0, shown).map((p, i) => {
      const m = metric(p, o);
      const rank = g.ranked ? `<span class="ex-rank${i < 3 ? " top" : ""}" aria-label="Rank ${i + 1}">${i + 1}</span>` : "";
      const ins = m && m[2] === "ins";
      const where = st.g === "inspections"
        ? [p.a, `inspected ${fmtDate(p.idt)}`, o === "nearest" && here && p.la != null ? `${milesText(miles(here, p))} away` : ""].filter(Boolean).join(" · ")
        : [p.c, p.cu].filter(Boolean).join(" · ");
      const metricHtml = !m ? "" : ins
        ? `<span class="ex-metric"><b aria-label="Anchorage inspection score ${esc(p.isc)} out of 100">${esc(m[0])}</b>${m[1] ? `<span class="ex-res ex-res-${resCls(p.ib)}">${esc(m[1])}</span>` : ""}</span>`
        : `<span class="ex-metric"><b>${esc(m[0])}</b><small>${esc(m[1])}</small></span>`;
      return `<li><button class="ex-row" data-i="${esc(p.i)}">${rank}<span class="ex-main"><b>${esc(p.n)}</b><span class="ex-town">${esc(where)}</span><span class="ex-chips">${chips(p, 4)}</span></span>${metricHtml}</button></li>`;
    }).join("") + (elsewhere ? `<li class="ex-empty">Only ${esc(current.length)} in ${esc(g.title)}. ${allButton(elsewhere)}</li>` : "");
    wireAll();
    const left = current.length - shown;
    $("#ex-more").hidden = left <= 0;
    $("#ex-more").textContent = `Show more (${left.toLocaleString()} left)`;
  }

  // ---------------------------------------------------------------- place panel
  const TIER = { 2: "On an official list", 1: "High-confidence listing", 0: "Listing only" };   // "High-confidence", not "confirmed" (Nick, 2026-10-13)

  // how often listings like this one matched an active Anchorage food permit or liquor license (pipeline/calibrate.py); the app's matchRate
  function rate(p) {
    if (p.t === 2) return null;
    const src = SOURCES[p.s] || "meta";
    const group = src === "meta" ? (p.t === 1 ? "meta_high" : "meta_mid") : (src === "AllThePlaces" || src === "DAC") ? "brand_feed" : null;
    if (!group) return null;
    const v = Object.values(CAL || {}).map((a) => a?.groups?.[group]?.official).filter((x) => typeof x === "number").map((x) => Math.round(x * 100)).sort((a, b) => a - b);
    if (!v.length) return null;
    return v[0] === v[v.length - 1] ? `${v[0]}%` : `${v[0]}–${v[v.length - 1]}%`;
  }

  function howWeKnow(p) {
    const src = SOURCES[p.s] || "meta";
    if (src === "research") return "On our hand-checked list (checked against a 2025 or 2026 source). The open map data didn't list it as a place to eat, so it's placed from its own map listing or street address.";
    if (p.t === 2) return src === "official"
      ? "From the Municipality of Anchorage's records. The open map data didn't have it, so it's placed on its permitted street address."
      : "Matched to an active Anchorage food permit or liquor license.";
    const r = rate(p);
    return (p.t === 1 ? "A high-confidence listing in Overture's open map data." : "A single listing in Overture's open map data, so it may be closed, seasonal or misfiled.")
      + (r ? ` In Anchorage, where every food business needs a health permit, listings like this matched one ${r} of the time.` : "")
      + (p.hc ? " It's also on our hand-checked list, checked against a 2025 or 2026 source." : "");
  }

  const kv = (k, v) => (v == null || v === "" ? "" : `<div class="ex-kv"><span>${esc(k)}</span><b>${esc(v)}</b></div>`);
  const section = (t, body) => `<section class="ex-sec"><h3>${esc(t)}</h3>${body}</section>`;
  let listAtPush = null;   // the list's URL state when a place was opened with pushState (Back then closes the panel)

  // the open place is a modal dialog at every width (a bottom sheet on phones, a side sheet on wider screens, which would otherwise
  // cover Near me and the List/Map buttons): everything behind it is inert, and a click on the dimmed backdrop closes it
  function panelMode() {
    const panel = $("#ex-panel"), modal = !panel.hidden;
    if (modal) { panel.setAttribute("role", "dialog"); panel.setAttribute("aria-modal", "true"); }
    else { panel.removeAttribute("role"); panel.removeAttribute("aria-modal"); }
    $("#ex-backdrop").hidden = !modal;
    const behind = [...document.querySelectorAll("body > .skip, .wrap > header, .wrap > nav, .wrap > footer, #main > *")].filter((el) => el !== panel && el.id !== "ex-backdrop");
    behind.forEach((el) => { el.inert = modal; });
  }

  const vtype = (i) => (Number.isInteger(i) && i >= 0 && i < (META.itypes || []).length ? META.itypes[i] : "");
  // "FOOD PROTECTED FROM CONTAMINATION" -> "Food protected from contamination" (the app's wording)
  const sentence = (x) => { const t = String(x ?? "").trim(); return t ? t[0].toUpperCase() + t.slice(1).toLowerCase() : ""; };

  // Anchorage's own scores where the department published them; elsewhere, say plainly that the state publishes none in bulk
  function inspectionSection(p, d) {
    if (!p.idt || p.isc == null) {
      return section("Health inspections", `<p class="ex-fine">${p.co != null && COUNTY_NAMES[p.co] === "Anchorage Municipality"
        ? "No scored inspection matched this place in the Anchorage Health Department's file. Its own lookup has every permitted place."
        : "Outside Anchorage the Alaska Department of Environmental Conservation inspects restaurants, but it publishes no results in bulk and its site doesn't allow apps to read it, so this site shows none."}</p>`
        + (p.co != null && COUNTY_NAMES[p.co] === "Anchorage Municipality" ? `<p><a href="${esc(ANC_LOOKUP)}" rel="noopener" target="_blank">The department's inspection lookup</a></p>` : ""));
    }
    const i = d.in && typeof d.in === "object" ? d.in : {};
    const hist = Array.isArray(i.h) ? i.h.filter(Array.isArray) : [];
    const cited = Array.isArray(i.v) ? i.v.filter((x) => typeof x === "string" && x.trim()) : [];
    let h = `<p class="ex-result"><b class="ex-score">${esc(p.isc)}</b><span>out of 100 · ${esc(fmtDate(p.idt))}</span></p>`;
    if (bandOf(p.ib)) h += `<div class="ex-kv"><span>Next step</span><b><span class="ex-res ex-res-${resCls(p.ib)}">${esc(bandOf(p.ib))}</span></b></div>`;
    if (hist.length > 1) h += `<ul>${hist.slice(0, 8).map((v) => `<li>${esc([fmtDate(v[0]), vtype(v[3]), num(v[2]) != null ? `${v[2]}/100` : "", bandOf(v[1])].filter(Boolean).join(" · "))}</li>`).join("")}</ul>`;
    if (cited.length) h += `<p>Cited at this visit: ${esc(cited.map(sentence).join("; "))}.</p>`;
    h += `<p class="ex-fine">${esc(INS_SCALE)} ${esc(NO_GRADE)} Source: the department's inspection file (Municipality of Anchorage Open Data)${META.through && META.through.anc ? `, records through ${esc(fmtDate(META.through.anc))}` : ""}${META.fileMod ? `; the file hasn't been updated since ${esc(fmtDate(META.fileMod))}, so newer visits are only on the department's site` : ""}.</p>`;
    const report = typeof i.r === "string" && ANC_REPORT.test(i.r) ? i.r : ANC_LOOKUP;
    h += `<p><a href="${esc(report)}" rel="noopener" target="_blank">Full reports on the department's site</a></p>`;
    return section("Health inspections · Anchorage", h);
  }

  function openPlace(p, push = true) {
    const panel = $("#ex-panel");
    const wasOpen = !panel.hidden;
    // the place opens at once; its id (for Save, the #p= link and the Back step) follows when ids.json arrives, which the first tap
    // only starts, so a tap never waits on it. If ids.json can't load (offline, or a build changed under us), the place stays open
    // without Save and without a link.
    const waiting = p.id == null && !idsReady;
    if (waiting && (push || !wasOpen)) loadIds().then(() => { if (!panel.hidden && panel.dataset.i === String(p.i)) openPlace(p, push); });
    const noId = p.id == null, pid = p.id ?? "";
    // a re-render (the county's details just arrived) replaces the panel's buttons: remember where keyboard focus was, to put it back
    const focused = wasOpen && panel.contains(document.activeElement) ? document.activeElement : null;
    const refocus = focused && (focused.id ? `#${focused.id}` : focused.textContent.trim());
    st.p = pid;
    const loaded = DETAIL_LOADED.has(p.co), failed = DETAIL_FAILED.has(p.co);
    const d = DETAIL.get(p.i) || {};
    const la = num(p.la), lo = num(p.lo);
    const addr = [p.a, [p.c, p.z].filter(Boolean).join(" ")].filter(Boolean).join(", ");
    const apple = la != null && lo != null
      ? `https://maps.apple.com/?q=${encodeURIComponent(p.n)}&ll=${la},${lo}`
      : `https://maps.apple.com/?q=${encodeURIComponent(p.n + ", " + addr)}`;
    const dirs = la != null && lo != null ? `https://maps.apple.com/?daddr=${la},${lo}&dirflg=d` : apple;
    const site = safeUrl(d.w);
    const tel = d.ph ? String(d.ph).replace(/[^\d+]/g, "") : "";
    let html = `<button class="ex-close" id="ex-close" aria-label="Close">×</button>
      <p class="ex-kicker">${esc((p.c || "Alaska").toUpperCase())}</p>
      <h2 id="ex-pname">${esc(p.n)}</h2>
      <p class="ex-addr">${esc([addr, p.cu].filter(Boolean).join(" · "))}</p>
      ${here && la != null ? `<p class="ex-dist">${esc(milesText(miles(here, p)))} away</p>` : ""}
      <p class="ex-chips">${chips(p)}</p>
      <div class="ex-actions">
        <a class="btn ex-apple" href="${esc(apple)}" rel="noopener" target="_blank">Ratings, hours &amp; photos · Apple Maps</a>
        <div class="ex-act-row">
          <a href="${esc(dirs)}" rel="noopener" target="_blank">Directions</a>
          ${tel ? `<a href="tel:${esc(tel)}">Call</a>` : ""}
          ${site ? `<a href="${esc(site)}" rel="noopener nofollow" target="_blank">Website</a>` : ""}
          ${waiting ? '<button id="ex-save" aria-pressed="false" disabled>Save</button>' : noId ? "" : `<button id="ex-save" aria-pressed="${saved.has(pid)}">${saved.has(pid) ? "Saved" : "Save"}</button>`}
        </div>
      </div>`;
    if (!loaded) html += `<p class="ex-fine">Loading details…</p>`;
    if (p.hc && (d.note || p.dish || p.f || d.seas)) {
      html += section("Hand-checked", (d.note ? `<p>${esc(d.note)}</p>` : "") + kv("On the menu", p.dish ? String(p.dish).split("; ").join(", ") : "")
        + kv("Open here since", p.f) + (d.fn ? `<p class="ex-fine">${esc(d.fn)}</p>` : "") + kv("Season", d.seas)
        + `<p class="ex-fine">Checked by hand: a 2025 or 2026 source names it (the place's own site, local news or a tourism listing), or an older one does and it holds an active Anchorage food permit. Many Alaska places open only in summer, and food trucks move, so check before you go.</p>`);
    }
    if (d.jbf) {
      const lines = String(d.jbf).split("; ").map((x) => "James Beard: " + x);
      html += section("Honors", `<ul>${lines.map((l) => `<li>${esc(l)}</li>`).join("")}</ul><p class="ex-fine">Honors are facts, not ratings. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation.</p>`);
    }
    html += inspectionSection(p, d);
    if (failed) html += `<p class="ex-fine">This place's details (permits, phone, website, inspection history) didn't load: you may be offline, or the site was just updated. Reload the page to try again.</p>`;
    else if (loaded) {
      const lic = Array.isArray(d.lic) ? d.lic.filter(Array.isArray) : [];
      const anc = p.co != null && COUNTY_NAMES[p.co] === "Anchorage Municipality";
      html += section("Official records", lic.map((l) => kv(String(l[0]) + (l[1] ? ` ${l[1]}` : ""), String(l[2] || "") + (l[3] ? `, expires ${l[3]}` : ""))).join("")
        + (lic.length ? "" : kv("Permit or license", anc ? "— (none matched)" : "— (only Anchorage's are published)"))
        + kv("Serves alcohol", p.liq ? "Yes (Anchorage liquor license)" : "—")
        + `<p class="ex-fine">Only the Municipality of Anchorage publishes its records: the Health Department's food permits (from its inspection file) and the Clerk's list of liquor licenses (published ${esc(fmtDate(META.lic))}), with the license type and expiration year. Outside Anchorage the state's permit and license lists aren't open to apps, so a missing record means unknown, not unlicensed. Dry and damp communities never show "No": only "—". <a href="${esc(ANC_DATA)}" rel="noopener" target="_blank">Anchorage's open data</a></p>`);
    }
    html += section("How we know it's here", kv("Listed as", TIER[p.t])
      + (p.t === 2 ? kv("Official record", "Anchorage food permit or liquor license") : "")
      + (p.ch >= 2 ? kv("Locations in Alaska", p.ch.toLocaleString()) : "") + `<p class="ex-fine">${esc(howWeKnow(p))}</p>`);
    const store_url = safeUrl(window.APP_STORE_URL);   // set in the page footer script once the App Store listing exists
    html += store_url
      ? `<p class="ex-app">Save it on your phone: <a href="${esc(store_url)}" rel="noopener">get the free iPhone app</a></p>`
      : `<p class="ex-app">The iPhone app is coming soon. <a href="${BASE}/#download">Ask for early access</a></p>`;
    panel.innerHTML = html;
    panel.dataset.id = pid;
    panel.dataset.i = String(p.i);
    panel.hidden = false;
    document.body.classList.add("ex-open");
    panelMode();
    $("#ex-close").onclick = () => closePlace();
    if (!noId) $("#ex-save").onclick = (e) => {
      if (saved.has(p.id)) saved.delete(p.id); else saved.add(p.id);
      store.set("saved", [...saved]);
      e.target.textContent = saved.has(p.id) ? "Saved" : "Save";
      e.target.setAttribute("aria-pressed", String(saved.has(p.id)));
      if (st.g === "saved") render();
    };
    const samePlace = wasOpen && panel.dataset.shown === String(p.i);   // a re-render: details or the id just arrived
    if (!samePlace) panel.scrollTop = 0;
    panel.dataset.shown = String(p.i);
    if (!samePlace) $("#ex-close").focus();
    else if (refocus) {
      const same = refocus.startsWith("#") ? panel.querySelector(refocus)
        : [...panel.querySelectorAll("a, button")].find((el) => el.textContent.trim() === refocus);
      (same || $("#ex-close")).focus();
    }
    if (push && !noId) {
      if (panel.dataset.pushed) saveHash();   // one Back step per panel, not per place looked at
      else { listAtPush = listHash(); saveHash(true); panel.dataset.pushed = "1"; }
    }
    if (!loaded) loadDetail(p.co).then(() => { if (panel.dataset.i === String(p.i) && !panel.hidden) openPlace(p, false); });
  }

  // fromHistory: the Back button (or a hash link) already moved the URL, so don't touch history again
  function closePlace(fromHistory = false) {
    st.p = "";
    const panel = $("#ex-panel");
    const wasI = panel.dataset.i;   // the row the panel belonged to: focus goes back there
    panel.hidden = true;
    delete panel.dataset.id;
    delete panel.dataset.i;
    delete panel.dataset.shown;
    delete panel.dataset.pushed;
    document.body.classList.remove("ex-open");
    panelMode();
    if (!fromHistory) {
      // the list hasn't changed since the panel opened: step back over the entry openPlace pushed, so Back isn't a dead click
      if (history.state && history.state.akeats === "place" && listHash() === listAtPush) history.back();
      else saveHash();
    }
    listAtPush = null;
    const row = wasI && document.querySelector(`.ex-row[data-i="${Number(wasI)}"]`);
    if (row) row.focus();
  }

  // ---------------------------------------------------------------- map (canvas: borough outlines + a dot per place)
  // An Albers equal-area projection for Alaska (the parallels of EPSG:3338: 55° and 65° N, centered on 154° W), in degree-sized units so
  // the zoom limits read like the other state sites'. East longitudes (the western Aleutians) first become lon - 360.
  let SHAPES = null, cam = null;
  const RAD = Math.PI / 180, ALB_N = (Math.sin(55 * RAD) + Math.sin(65 * RAD)) / 2;
  const ALB_C = Math.cos(55 * RAD) ** 2 + 2 * ALB_N * Math.sin(55 * RAD), ALB_R0 = Math.sqrt(ALB_C - 2 * ALB_N * Math.sin(50 * RAD)) / ALB_N;
  const unwrap = (lo) => (lo > 0 ? lo - 360 : lo);
  const proj = (lo, la) => {
    const th = ALB_N * (unwrap(lo) + 154) * RAD, r = Math.sqrt(ALB_C - 2 * ALB_N * Math.sin(la * RAD)) / ALB_N;
    return [r * Math.sin(th) / RAD, -(ALB_R0 - r * Math.cos(th)) / RAD];
  };
  // the state's far corners: Attu, Point Barrow, the Yukon border's north end, the Panhandle's south tip, St. Lawrence Island
  const CORNERS = [[172.4, 52.9], [-156.8, 71.4], [-141, 69.7], [-130, 54.7], [-130, 56.1], [-171.8, 63.8], [-168.1, 65.6], [-179.3, 51.2], [-161, 54.4], [-148, 59.3]];

  function fitCam(w, h) {
    const xy = CORNERS.map(([lo, la]) => proj(lo, la));
    const x0 = Math.min(...xy.map((q) => q[0])), x1 = Math.max(...xy.map((q) => q[0]));
    const y0 = Math.min(...xy.map((q) => q[1])), y1 = Math.max(...xy.map((q) => q[1]));
    const k = Math.min(w / (x1 - x0), h / (y1 - y0)) * 0.95;
    return { k, x: (w - (x1 - x0) * k) / 2 - x0 * k, y: (h - (y1 - y0) * k) / 2 - y0 * k };
  }

  // calls f on every ring, however deeply it's nested (the state is [polygon[ring[point]]], each county [ring[point]])
  const eachRing = (g, f) => {
    if (!Array.isArray(g) || !g.length) return;
    if (Array.isArray(g[0]) && typeof g[0][0] === "number") f(g); else g.forEach((x) => eachRing(x, f));
  };

  const classic = (p) => Boolean((p.hc && p.g) || p.jb);   // hand-checked picks and honors get the gold dot
  async function drawMap() {
    const cv = $("#ex-map"), wrap = $("#ex-mapwrap");
    const w = wrap.clientWidth, h = wrap.clientHeight, dpr = window.devicePixelRatio || 1;
    if (!w || !h) return;
    if (cv.width !== Math.round(w * dpr) || cv.height !== Math.round(h * dpr)) { cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr); }
    if (!cam) cam = fitCam(w, h);
    if (!SHAPES) SHAPES = await fetchJSON(`${BASE}/data/ak_shapes.json`).catch(() => ({ state: [], counties: [] }));
    const c = cv.getContext("2d");
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    c.clearRect(0, 0, w, h);
    const X = (lo, la) => { const [x, y] = proj(lo, la); return [x * cam.k + cam.x, y * cam.k + cam.y]; };
    const ring = (r) => { r.forEach(([lo, la], i) => { const [x, y] = X(lo, la); i ? c.lineTo(x, y) : c.moveTo(x, y); }); c.closePath(); };
    c.fillStyle = "#f7f3ea";   // the map stays light in dark mode (its frame is light too), so the navy dots keep their contrast
    c.beginPath(); eachRing(SHAPES.state, ring); c.fill("evenodd");
    c.strokeStyle = "rgba(15,32,75,.22)"; c.lineWidth = 0.8;
    for (const co of SHAPES.counties || []) { c.beginPath(); eachRing(co.c, ring); c.stroke(); }
    const pts = current.filter((p) => p.la != null);
    const r = Math.max(2.2, Math.min(5, 1.6 + cam.k / 120));
    // plain places: small navy dots; hand-checked and honored places: gold dots with a navy ring, on top
    c.fillStyle = "#2a4a8c";
    const sq = pts.length > 3000 ? Math.max(1.6, r - 0.6) : r * 1.6;
    for (const p of pts) {
      if (classic(p)) continue;
      const [x, y] = X(p.lo, p.la);
      if (x < -5 || y < -5 || x > w + 5 || y > h + 5) continue;
      if (pts.length > 3000) c.fillRect(x - sq / 2, y - sq / 2, sq, sq);
      else { c.beginPath(); c.arc(x, y, r, 0, 6.2832); c.fill(); }
    }
    c.fillStyle = "#ffb612"; c.strokeStyle = "#0f204b"; c.lineWidth = 1.5;
    for (const p of pts) {
      if (!classic(p)) continue;
      const [x, y] = X(p.lo, p.la);
      if (x < -5 || y < -5 || x > w + 5 || y > h + 5) continue;
      c.beginPath(); c.arc(x, y, r + 1, 0, 6.2832); c.fill(); c.stroke();
    }
    $("#ex-maphint").textContent = pts.length ? `${pts.length.toLocaleString()} ${pts.length === 1 ? "place" : "places"} · tap a dot` : "No places to show";
  }

  function nearestDot(px, py) {
    let best = null, bd = 14 * 14;
    for (const p of current) {
      if (p.la == null) continue;
      const [x0, y0] = proj(p.lo, p.la), x = x0 * cam.k + cam.x, y = y0 * cam.k + cam.y;
      const d = (x - px) ** 2 + (y - py) ** 2;
      if (d < bd || (d === bd && classic(p))) { bd = d; best = p; }
    }
    return best;
  }

  function zoomAt(f, px, py) {
    const k = Math.min(Math.max(cam.k * f, 4), 60000);   // from the whole state on a phone to a few blocks
    const s = k / cam.k;
    cam = { k, x: px - (px - cam.x) * s, y: py - (py - cam.y) * s };
    drawMap();
  }

  function mapEvents() {
    const cv = $("#ex-map");
    const ptrs = new Map();
    let moved = false, pinch0 = null;
    cv.addEventListener("wheel", (e) => { e.preventDefault(); const b = cv.getBoundingClientRect(); zoomAt(e.deltaY < 0 ? 1.25 : 0.8, e.clientX - b.left, e.clientY - b.top); }, { passive: false });
    cv.addEventListener("pointerdown", (e) => { cv.setPointerCapture(e.pointerId); ptrs.set(e.pointerId, [e.clientX, e.clientY]); moved = false; pinch0 = null; });
    cv.addEventListener("pointermove", (e) => {
      if (!ptrs.has(e.pointerId)) return;
      const prev = ptrs.get(e.pointerId);
      ptrs.set(e.pointerId, [e.clientX, e.clientY]);
      if (ptrs.size === 2) {
        const [a, b] = [...ptrs.values()], d = Math.hypot(a[0] - b[0], a[1] - b[1]);
        const r = cv.getBoundingClientRect();
        if (pinch0) zoomAt(d / pinch0, (a[0] + b[0]) / 2 - r.left, (a[1] + b[1]) / 2 - r.top);
        pinch0 = d; moved = true; return;
      }
      const dx = e.clientX - prev[0], dy = e.clientY - prev[1];
      if (Math.abs(dx) + Math.abs(dy) > 2) moved = true;
      cam.x += dx; cam.y += dy; drawMap();
    });
    const up = (e) => {
      ptrs.delete(e.pointerId);
      if (!moved && ptrs.size === 0) {
        const b = cv.getBoundingClientRect(), p = nearestDot(e.clientX - b.left, e.clientY - b.top);
        if (p) openPlace(p);
      }
      if (ptrs.size < 2) pinch0 = null;
    };
    cv.addEventListener("pointerup", up);
    cv.addEventListener("pointercancel", (e) => ptrs.delete(e.pointerId));
    $("#ex-zin").onclick = () => zoomAt(1.6, cv.clientWidth / 2, cv.clientHeight / 2);
    $("#ex-zout").onclick = () => zoomAt(0.625, cv.clientWidth / 2, cv.clientHeight / 2);
    window.addEventListener("resize", () => { if (view === "map") drawMap(); });
  }

  function centerOn(pt) {
    const cv = $("#ex-map"), w = cv.clientWidth, h = cv.clientHeight;
    const k = 2500, [x, y] = proj(pt.lo, pt.la);
    cam = { k, x: w / 2 - x * k, y: h / 2 - y * k };
  }

  // ---------------------------------------------------------------- data, URL state, controls
  let SOURCES = [], DETAIL_FILES = [], COUNTY_NAMES = [];
  async function fetchJSON(url, opts) { const r = await fetch(url, opts); if (!r.ok) throw new Error(r.status + " " + url); return r.json(); }
  // the build this page's data comes from: the page names it (so a cached core.json from an older build isn't used), core.json confirms it
  const PAGE_VER = ($("#ex-app") && $("#ex-app").dataset.ver) || "";
  let DV = "";
  const vq = (v) => (v ? "?v=" + encodeURIComponent(v) : "");
  // a data file from another build (a cache that outlived a deploy) is fetched once more, then refused: its rows wouldn't line up
  async function fetchCurrent(url, verOf) {
    let d = await fetchJSON(url + vq(DV));
    if (DV && verOf(d) !== DV) d = await fetchJSON(url + vq(DV), { cache: "reload" });
    if (DV && verOf(d) !== DV) throw new Error("another build: " + url);
    return d;
  }
  const DETAIL = new Map(), DETAIL_LOADED = new Set(), DETAIL_FAILED = new Set(), detailPromises = new Map();
  // a county's detail file (phones, websites, notes, licenses) is fetched only once someone reaches for a place there
  function loadDetail(co) {
    // a county with no extras has no file (null in dfiles): nothing to fetch
    if (!Number.isInteger(co) || co < 0 || co >= DETAIL_FILES.length || !DETAIL_FILES[co]) { DETAIL_LOADED.add(co); return Promise.resolve(); }
    if (!detailPromises.has(co)) {
      detailPromises.set(co, fetchCurrent(`${BASE}/data/detail-${encodeURIComponent(DETAIL_FILES[co])}.json`, (d) => d && d._v).then((d) => {
        if (d && typeof d === "object") for (const k of Object.keys(d)) { const i = Number(k); if (Number.isInteger(i) && d[k] && typeof d[k] === "object") DETAIL.set(i, d[k]); }
      }).catch(() => { DETAIL_FAILED.add(co); /* offline or another build: the panel says so, and asks for a reload */ })
        .finally(() => DETAIL_LOADED.add(co)));
    }
    return detailPromises.get(co);
  }

  // ids.json: one stable id per place, in core order (saved places, #p= links and the panel's history entry use them)
  let idsPromise = null, idsReady = false, idsFailed = false;
  function loadIds() {
    idsPromise ||= fetchCurrent(`${BASE}/data/ids.json`, (d) => d && d.v).then((d) => {
      const ids = d && typeof d.ids === "string" ? d.ids.split(",") : [];   // one comma-separated string: smaller than a JSON array
      if (ids.length !== P.length) throw new Error("ids.json doesn't match core.json");
      ids.forEach((x, i) => { P[i].id = x; });
    }).catch(() => { idsFailed = true; /* offline or another build: saving and links wait for a reload, and the page says so */ })
      .finally(() => { idsReady = true; });
    return idsPromise;
  }

  async function load() {
    let d = await fetchJSON(`${BASE}/data/core.json${vq(PAGE_VER)}`);
    // a core.json with no version predates versioning (a cache that ignored ?v=): its rows would meet this build's ids and county
    // files unchecked, so fetch it once more past the cache, then stop with the reload message rather than mix two builds
    if (PAGE_VER && typeof d.ver !== "string") d = await fetchJSON(`${BASE}/data/core.json${vq(PAGE_VER)}`, { cache: "reload" });
    if (PAGE_VER && typeof d.ver !== "string") throw new Error("core.json from before versioning");
    DV = typeof d.ver === "string" ? d.ver : "";
    GENERATED = d.generated; CAL = d.calibration || {}; SOURCES = d.srcs || []; DETAIL_FILES = d.dfiles || [];
    if (Array.isArray(d.results) && d.results.length) RESULTS = d.results;
    META = { through: d.inspections_through || {}, fileMod: d.inspections_file_modified, liq: d.liquor_updated, lic: d.licenses_updated, itypes: d.itypes || [] };
    COUNTY_NAMES = Array.isArray(d.counties) ? d.counties : [];
    const n = d.n, towns = new Map(), C = { ...d.cols };
    for (const [k, pairs] of Object.entries(d.sparse || {})) {   // mostly-empty columns arrive as [[index, value], ...]
      const col = new Array(n).fill(null);
      if (Array.isArray(pairs)) for (const pr of pairs) if (Array.isArray(pr) && Number.isInteger(pr[0]) && pr[0] >= 0 && pr[0] < n) col[pr[0]] = pr[1];
      C[k] = col;
    }
    for (const k of ["n", "c", "co", "cu", "t", "s", "a", "z", "b", "ch", "g", "hc", "ip", "f", "h", "dish", "liq", "dla", "dlo", "jb", "ij", "ib", "isc", "idn"])
      if (!Array.isArray(C[k]) || C[k].length !== n) C[k] = new Array(n).fill(null);
    const day0 = Date.UTC(...String(d.day0 || "2000-01-01").split("-").map((x, k) => Number(x) - (k === 1 ? 1 : 0)));
    const isoDay = (k) => (k == null ? null : new Date(day0 + k * 86400000).toISOString().slice(0, 10));
    P = new Array(n);
    let la = 0, lo = 0;   // coordinates come as steps of 0.0001° from the previous place
    for (let i = 0; i < n; i++) {
      let pla = null, plo = null;
      if (C.dla[i] != null && C.dlo[i] != null) { la += C.dla[i]; lo += C.dlo[i]; pla = la / 10000; plo = lo / 10000; }
      const city = C.c[i] == null ? null : d.cities[C.c[i]], cu = d.cuisines[C.cu[i]], brand = C.b[i] == null ? null : d.brands[C.b[i]];
      const county = C.co[i] == null ? null : d.counties[C.co[i]];
      const p = { i, id: null, n: String(C.n[i] ?? ""), c: city, cu, t: C.t[i], s: C.s[i], a: C.a[i], z: C.z[i], la: pla, lo: plo,
        ch: num(C.ch[i]) || 1, g: C.g[i] || 0, hc: C.hc[i] === 1, ip: C.ip[i], f: num(C.f[i]), h: C.h[i] || 0,
        jb: C.jb[i] === 1, dish: C.dish[i], co: C.co[i], liq: C.liq[i] === 1,
        ij: num(C.ij[i]), ib: num(C.ib[i]), isc: num(C.isc[i]), idt: isoDay(C.idn[i]) };
      p.search = " " + normalize([p.n, city, county, p.z, cu, brand, p.dish].filter(Boolean).join(" ")) + " " + normAddr(p.a || "") + " ";
      p.nameText = " " + normalize([p.n, brand].filter(Boolean).join(" ")) + " ";
      p.key = normalize(p.n);
      P[i] = p;
      if (city) towns.set(city, (towns.get(city) || 0) + 1);
    }
    const byCount = [...towns.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    for (const [name] of byCount) { const k = normAddr(name); if (!own(TOWN_KEYS, k)) TOWN_KEYS[k] = name; }   // biggest town wins a shared spelling
    TOWN_KEYS_BY_LENGTH = Object.keys(TOWN_KEYS).sort((a, b) => b.length - a.length);
    $("#ex-town").innerHTML = '<option value="">All towns</option>' + [...towns.keys()].sort((a, b) => a.localeCompare(b)).map((t) => `<option>${esc(t)}</option>`).join("");
    const cuis = new Map();
    for (const p of P) cuis.set(p.cu, (cuis.get(p.cu) || 0) + 1);
    $("#ex-cuisine").innerHTML = '<option value="">All kinds</option>' + [...cuis.entries()].sort((a, b) => b[1] - a[1]).map(([c, k]) => `<option value="${esc(c)}">${esc(c)} (${esc(k.toLocaleString())})</option>`).join("");
  }

  const guideOk = (g) => own(GUIDES, g);
  function readHash() {
    const h = new URLSearchParams(location.hash.slice(1));
    const last = store.get("guide", FIRST);
    // a returning visitor gets the guide they used last, unless it's an empty Saved list
    st.g = guideOk(h.get("g")) ? h.get("g") : guideOk(last) && !(last === "saved" && !saved.size) ? last : FIRST;
    st.q = h.get("q") || ""; st.town = h.get("town") || ""; st.cuisine = h.get("kind") || ""; st.chains = h.get("chains") === "1";
    st.sort = h.get("sort") || ""; st.p = h.get("p") || "";
  }
  function hashOf(withPlace) {
    const h = new URLSearchParams();
    h.set("g", st.g);
    if (st.q) h.set("q", st.q); if (st.town) h.set("town", st.town); if (st.cuisine) h.set("kind", st.cuisine);
    if (st.chains) h.set("chains", "1"); if (st.sort) h.set("sort", st.sort); if (withPlace && st.p) h.set("p", st.p);
    return "#" + h.toString();
  }
  const listHash = () => hashOf(false);
  // filter changes replace the current history entry; opening a place pushes one, so Back closes the panel
  function saveHash(push = false) {
    const url = hashOf(true);
    if (push) history.pushState({ akeats: "place" }, "", url);
    else history.replaceState(st.p ? { akeats: "place" } : null, "", url);
    store.set("guide", st.g);
  }

  // Alaska's outline about 5 km outside the line (AlaskaEats/Services/LocationService.swift's AlaskaOutline, the same rings), with
  // longitudes past 180° written as lon - 360: a bounding box would count Whitehorse, Prince Rupert and Anadyr
  const AK_RINGS = [
    [[-169.42,52.68],[-169.31,53.04],[-169.08,53.1],[-168.32,53.68],[-167.95,53.73],[-167.6,53.59],[-167.36,53.66],[-167.34,53.94],[-167.09,54.12],[-166.31,54.18],[-166.17,54.33],[-165.66,54.47],[-165.03,54.33],[-165.14,54.63],[-164.84,54.81],[-164.69,55.02],[-163.34,55.3],[-163.39,55.51],[-163.28,55.63],[-163.11,55.64],[-162.94,55.52],[-161.86,56.06],[-160.65,56.19],[-160.28,56.54],[-159.01,57.03],[-158.25,58.41],[-158.75,58.24],[-159.1,58.22],[-159.67,58.67],[-159.79,58.48],[-159.96,58.42],[-160.4,58.43],[-160.62,58.58],[-160.92,58.38],[-161.17,58.39],[-161.29,58.5],[-161.7,58.38],[-162.16,58.46],[-162.4,58.64],[-162.32,58.78],[-162.0,58.85],[-162.29,59.22],[-162.07,59.54],[-162.22,59.69],[-162.66,59.77],[-162.85,59.66],[-164.04,59.52],[-164.49,59.79],[-164.66,60.05],[-165.45,60.36],[-165.31,59.89],[-165.44,59.76],[-166.03,59.58],[-166.69,59.69],[-167.53,59.97],[-167.68,60.19],[-167.57,60.37],[-167.0,60.39],[-166.16,60.63],[-165.63,60.49],[-165.56,60.69],[-165.3,60.79],[-165.76,60.98],[-166.28,61.37],[-166.41,61.61],[-166.19,62.15],[-165.54,62.48],[-164.94,63.17],[-164.13,63.44],[-163.16,63.22],[-162.76,63.4],[-162.92,63.51],[-162.94,63.63],[-162.61,63.81],[-161.96,63.68],[-161.69,63.77],[-161.42,63.64],[-161.03,63.81],[-161.16,63.97],[-161.49,63.99],[-161.53,64.21],[-162.31,64.42],[-162.79,64.16],[-163.66,64.4],[-165.03,64.27],[-166.0,64.39],[-166.3,64.32],[-166.62,64.58],[-166.71,64.82],[-167.16,65.06],[-167.19,65.22],[-168.24,65.45],[-168.34,65.69],[-168.11,65.87],[-165.46,66.59],[-164.44,66.75],[-163.64,66.75],[-163.25,66.89],[-163.96,66.99],[-164.09,67.09],[-164.06,67.28],[-164.24,67.45],[-165.54,67.9],[-166.99,68.19],[-167.08,68.28],[-167.07,68.42],[-166.55,68.57],[-166.47,68.92],[-166.31,69.04],[-164.29,69.1],[-163.83,69.22],[-163.42,69.44],[-163.4,69.68],[-163.2,69.94],[-162.52,70.32],[-161.99,70.49],[-160.93,70.53],[-159.79,70.94],[-159.26,71.04],[-157.95,71.02],[-156.49,71.56],[-153.89,71.06],[-152.99,71.09],[-152.13,70.99],[-151.32,70.59],[-149.72,70.74],[-148.58,70.59],[-147.9,70.66],[-146.69,70.4],[-144.7,70.14],[-143.22,70.32],[-140.94,69.81],[-140.88,69.65],[-140.88,60.41],[-140.58,60.35],[-140.44,60.43],[-140.0,60.31],[-139.71,60.45],[-139.03,60.46],[-138.95,60.32],[-139.04,60.13],[-138.65,60.01],[-138.56,59.87],[-137.54,59.34],[-137.4,59.07],[-136.64,59.28],[-136.58,59.52],[-136.41,59.71],[-135.44,59.91],[-134.94,59.65],[-134.87,59.39],[-134.43,59.24],[-134.19,58.97],[-133.78,58.83],[-133.3,58.52],[-133.27,58.37],[-132.28,57.43],[-132.13,57.18],[-131.96,57.13],[-131.96,56.95],[-131.78,56.88],[-131.74,56.72],[-130.74,56.48],[-130.34,56.25],[-130.06,56.23],[-129.88,56.02],[-130.0,55.6],[-129.87,55.23],[-130.6,54.54],[-133.68,54.52],[-133.9,54.92],[-133.8,55.15],[-134.02,55.39],[-134.01,55.67],[-134.2,55.57],[-134.69,55.74],[-134.77,55.87],[-134.69,56.01],[-135.95,56.91],[-136.53,57.73],[-136.75,57.83],[-136.8,58.06],[-137.77,58.46],[-138.31,58.89],[-140.45,59.54],[-142.31,59.89],[-143.62,59.87],[-144.7,59.61],[-144.9,59.77],[-144.75,60.0],[-145.97,60.19],[-147.07,59.97],[-147.28,59.73],[-147.67,59.62],[-148.44,59.77],[-149.23,59.73],[-149.59,59.41],[-151.74,58.96],[-151.81,58.78],[-152.12,58.72],[-151.94,58.52],[-151.63,58.46],[-151.57,58.21],[-151.72,58.03],[-152.11,57.97],[-151.91,57.63],[-152.11,57.26],[-152.44,57.23],[-152.78,56.99],[-153.65,56.67],[-153.66,56.49],[-153.87,56.35],[-154.5,56.33],[-154.72,56.24],[-154.93,56.28],[-154.98,56.53],[-154.5,56.78],[-154.71,56.91],[-154.73,57.09],[-155.03,57.21],[-155.01,57.42],[-154.64,57.72],[-153.62,58.11],[-152.58,58.86],[-152.98,58.88],[-153.11,58.63],[-153.74,58.38],[-154.08,57.99],[-154.87,57.85],[-155.25,57.53],[-156.09,57.25],[-156.23,56.68],[-156.7,56.39],[-156.43,56.1],[-156.59,55.86],[-156.89,55.87],[-157.02,56.15],[-157.97,55.52],[-159.39,55.52],[-159.44,55.45],[-159.13,55.17],[-158.99,54.9],[-159.13,54.74],[-159.46,54.6],[-159.87,54.63],[-160.02,54.76],[-160.28,54.69],[-160.46,54.91],[-161.2,55.01],[-161.45,54.83],[-161.55,54.64],[-162.18,54.51],[-162.16,54.26],[-162.53,54.13],[-163.07,54.25],[-163.09,54.49],[-164.1,54.44],[-164.56,54.23],[-164.86,53.92],[-165.74,53.9],[-165.91,53.67],[-166.69,53.28],[-167.08,53.25],[-167.57,53.06],[-168.06,53.11],[-168.31,52.84],[-169.21,52.6]],
    [[-179.35,51.29],[-179.22,51.45],[-179.24,51.68],[-178.87,52.01],[-178.63,51.95],[-178.32,51.66],[-178.43,51.9],[-178.26,52.07],[-177.74,52.01],[-177.46,52.1],[-176.95,52.06],[-176.61,52.18],[-176.4,52.11],[-176.15,52.29],[-175.73,52.15],[-175.58,52.35],[-175.33,52.29],[-175.11,52.4],[-174.81,52.28],[-174.2,52.59],[-173.87,52.49],[-173.77,52.31],[-172.84,52.27],[-172.7,52.49],[-172.42,52.56],[-172.19,52.5],[-172.09,52.35],[-172.19,52.18],[-172.7,52.09],[-172.79,51.96],[-173.13,51.83],[-174.07,51.93],[-174.48,51.83],[-175.33,51.83],[-176.9,51.42],[-177.41,51.53],[-178.07,51.46],[-178.27,51.3],[-178.63,51.4],[-179.07,51.06],[-179.28,51.11]],
    [[-172.07,63.55],[-171.95,63.85],[-171.8,63.96],[-170.96,63.75],[-170.29,63.88],[-169.77,63.61],[-168.58,63.45],[-168.46,63.29],[-168.71,62.92],[-169.23,63.0],[-169.38,62.84],[-169.64,62.76],[-170.63,63.19],[-171.04,63.25],[-171.44,63.13],[-171.81,63.2],[-172.03,63.35]],
    [[-183.01,51.89],[-182.8,52.22],[-182.65,52.29],[-182.26,52.28],[-182.11,52.09],[-181.89,52.23],[-181.46,52.16],[-181.23,52.04],[-181.27,51.82],[-180.43,51.53],[-180.31,51.32],[-180.45,51.19],[-180.8,51.18],[-182.15,51.78],[-182.71,51.64],[-182.94,51.75]],
    [[-187.77,52.93],[-187.69,53.06],[-187.41,53.17],[-186.85,53.16],[-186.31,52.88],[-186.13,52.95],[-185.76,52.89],[-185.64,52.69],[-185.78,52.55],[-186.03,52.56],[-186.12,52.25],[-186.37,52.17],[-186.81,52.3],[-186.84,52.45],[-186.72,52.58],[-187.32,52.62],[-187.71,52.79]],
    [[-171.51,52.43],[-171.47,52.62],[-171.22,52.75],[-170.98,52.72],[-170.66,52.87],[-170.39,52.77],[-170.28,53.01],[-170.0,53.09],[-169.85,53.24],[-169.64,53.22],[-169.47,53.07],[-169.48,52.76],[-169.65,52.6],[-170.18,52.54],[-170.36,52.62],[-170.54,52.44],[-170.8,52.37],[-170.98,52.43],[-171.22,52.27],[-171.41,52.31]],
    [[-173.34,60.71],[-173.2,60.84],[-172.97,60.85],[-172.64,60.59],[-172.06,60.43],[-172.0,60.26],[-172.16,60.13],[-172.49,60.15],[-172.87,60.03],[-173.03,60.3],[-173.27,60.41]],
    [[-170.64,57.17],[-170.49,57.36],[-170.11,57.43],[-169.81,57.33],[-169.73,57.19],[-169.84,57.04],[-170.4,56.88],[-170.58,56.93]],
    [[-180.73,51.94],[-180.64,52.12],[-180.35,52.2],[-180.08,52.09],[-180.02,51.97],[-180.1,51.8],[-180.37,51.7],[-180.61,51.76]],
    [[-170.0,56.62],[-169.87,56.78],[-169.51,56.79],[-169.32,56.73],[-169.26,56.59],[-169.59,56.36],[-169.89,56.46]],
    [[-146.63,59.38],[-146.52,59.63],[-146.37,59.71],[-146.18,59.66],[-146.03,59.44],[-146.09,59.31],[-146.35,59.22],[-146.55,59.26]],
    [[-155.96,55.8],[-155.63,56.05],[-155.42,56.02],[-155.33,55.9],[-155.37,55.68],[-155.51,55.59],[-155.85,55.62]],
    [[-168.71,65.45],[-169.08,65.64],[-169.09,65.82],[-168.97,65.94],[-168.74,65.9],[-168.51,65.64],[-168.56,65.51]],
    [[-184.35,52.42],[-184.26,52.53],[-184.07,52.55],[-183.88,52.48],[-183.82,52.34],[-183.92,52.2],[-184.12,52.16],[-184.3,52.27]],
    [[-168.29,64.86],[-168.28,65.1],[-168.07,65.16],[-167.88,65.12],[-167.79,64.96],[-167.89,64.83],[-168.09,64.79]],
    [[-168.26,53.94],[-168.18,54.08],[-168.02,54.11],[-167.88,54.06],[-167.83,53.92],[-168.04,53.75]]];
  function inAlaska(la, lo) {
    const x = unwrap(lo);
    let inside = false;
    for (const R of AK_RINGS) {
      for (let i = 0, j = R.length - 1; i < R.length; j = i++) {
        const [xi, yi] = R[i], [xj, yj] = R[j];
        if ((yi > la) !== (yj > la) && x < (xj - xi) * (la - yi) / (yj - yi) + xi) inside = !inside;
      }
    }
    return inside;
  }

  function locate() {
    if (!navigator.geolocation) { $("#ex-locmsg").textContent = "This browser can't share its location."; return; }
    $("#ex-locmsg").textContent = "Finding you…";
    navigator.geolocation.getCurrentPosition((pos) => {
      here = { la: pos.coords.latitude, lo: pos.coords.longitude };
      const inAK = inAlaska(here.la, here.lo);
      $("#ex-locmsg").textContent = inAK ? "Sorted by distance from you. Your location stays in this browser." : "You're outside Alaska: distances are from where you are. Your location stays in this browser.";
      st.sort = GUIDES[st.g].sorts.includes("nearest") ? "nearest" : st.sort;
      if (view === "map" && inAK) centerOn(here);
      shown = 100; render();
    }, (err) => {
      $("#ex-locmsg").textContent = err && err.code === 1 ? "Location is off for this site. Allow it in your browser settings to sort by distance."
        : "Couldn't get a location fix just now. Tap Near me to try again.";
    },
    { enableHighAccuracy: false, timeout: 10000, maximumAge: 0 });   // a fresh fix on every tap, never one from minutes ago
  }

  function setView(v) {
    view = v;
    document.querySelectorAll(".ex-view button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.v === v)));
    $("#ex-listwrap").hidden = v !== "list";
    $("#ex-mapwrap").hidden = v !== "map";
    render();
    // the map often starts below the fold (on phones, and on laptop-height screens): bring it into view
    if (v === "map" && $("#ex-mapwrap").getBoundingClientRect().top > innerHeight * 0.5) $("#ex-mapwrap").scrollIntoView({ block: "nearest" });
  }

  // the URL moved under us: Back/Forward (popstate) or a link to another #hash (hashchange). Both can fire for one step.
  function fromURL() {
    const before = listHash();
    readHash();
    if (listHash() !== before) { syncInputs(); shown = 100; render(); }
    if (st.p && !idsReady) { loadIds().then(fromURL); return; }
    const p = st.p && P.find((x) => x.id === st.p);
    const panel = $("#ex-panel");
    if (p) {
      if (panel.hidden || panel.dataset.id !== p.id) {
        openPlace(p, false);
        // Forward to a place opened earlier: its entry was pushed after the list's, so closing it steps back, as after a tap
        if (history.state && history.state.akeats === "place") { listAtPush = listHash(); panel.dataset.pushed = "1"; }
      }
    }
    else { if (!panel.hidden) closePlace(true); linkMissing(); }
  }

  // a #p= link whose place isn't here: ids.json didn't load, or the place has left the list since the link was made
  function linkMissing() {
    if (!st.p) return;
    $("#ex-locmsg").textContent = idsFailed ? "The place in this link couldn't load: you may be offline, or the site was just updated. Reload the page to try again."
      : "The place in this link isn't on the list anymore (it may have closed or moved).";
  }

  function controls() {
    document.querySelectorAll(".ex-guides button").forEach((b) => b.onclick = () => { if (guideOk(b.dataset.g)) st.g = b.dataset.g; st.sort = ""; shown = 100; render(); });
    let t = null;
    $("#ex-q").addEventListener("input", (e) => { clearTimeout(t); t = setTimeout(() => { st.q = e.target.value; shown = 100; render(); }, 120); });
    $("#ex-sort").onchange = (e) => { st.sort = e.target.value; if (st.sort === "nearest" && !here) locate(); shown = 100; render(); };
    $("#ex-town").onchange = (e) => { st.town = e.target.value; shown = 100; render(); };
    $("#ex-cuisine").onchange = (e) => { st.cuisine = e.target.value; shown = 100; render(); };
    $("#ex-chains").onchange = (e) => { st.chains = e.target.checked; shown = 100; render(); };
    $("#ex-clear").onclick = () => { st.town = st.cuisine = ""; st.chains = false; syncInputs(); shown = 100; render(); };
    $("#ex-locate").onclick = locate;
    $("#ex-more").onclick = () => { shown += 200; renderList(order()); };
    document.querySelectorAll(".ex-view button").forEach((b) => b.onclick = () => setView(b.dataset.v));
    $("#ex-list").addEventListener("click", (e) => { const b = e.target.closest(".ex-row"); if (b && P[+b.dataset.i]) openPlace(P[+b.dataset.i]); });
    // warm the region file of the row under the pointer (or keyboard focus), so the panel opens with its details
    for (const ev of ["pointerover", "focusin"]) $("#ex-list").addEventListener(ev, (e) => { const b = e.target.closest && e.target.closest(".ex-row"); if (b && P[+b.dataset.i]) { loadIds(); loadDetail(P[+b.dataset.i].co); } });
    // the ids (a few hundred KB) wait for the first sign of use, so a visit that only looks doesn't download them
    const WARM = ["pointerdown", "keydown", "wheel", "scroll", "touchstart"];
    const warmIds = () => { WARM.forEach((ev) => removeEventListener(ev, warmIds, true)); loadIds(); };
    WARM.forEach((ev) => addEventListener(ev, warmIds, { capture: true, passive: true }));
    document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !$("#ex-panel").hidden) closePlace(); });
    window.addEventListener("popstate", fromURL);
    window.addEventListener("hashchange", fromURL);
    $("#ex-backdrop").addEventListener("click", () => { if (st.p || !$("#ex-panel").hidden) closePlace(); });
    mapEvents();
  }
  function syncInputs() {
    $("#ex-q").value = st.q; $("#ex-town").value = st.town; $("#ex-cuisine").value = st.cuisine; $("#ex-chains").checked = st.chains;
  }

  (async () => {
    $("#ex-loading").hidden = false;   // hidden in the HTML, so a browser without JavaScript shows only the <noscript> note
    readHash();
    try { await load(); } catch (e) { $("#ex-loading").textContent = "The restaurant list couldn't load. Refresh to try again."; return; }
    syncInputs(); controls();
    $("#ex-app").hidden = false;
    $("#ex-loading").hidden = true;
    render();
    if (st.p) {
      await loadIds();
      const open = P.find((p) => p.id === st.p);
      if (open) { await loadDetail(open.co); openPlace(open, false); }
      else linkMissing();
    }
  })();
})();
