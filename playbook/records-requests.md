# Requests and downloads for Nick (drafts; nothing has been sent)

Nick's calls 2026-10-26 (`playbook/05-naming.md`): draft the DEC request and the Anchorage note for Nick to send from his own account,
and give exact steps for the two state lists he downloads by hand. Every DEC, DCCED and AMCO page below sits behind a bot check for our
scripts, so the addresses and form names come from search results and were **not** opened by us: check them before sending.

## 1. DEC: statewide retail food inspections and permits (Public Records Act, AS 40.25.110–.220)

Where: the Alaska Department of Environmental Conservation, Division of Environmental Health, Food Safety and Sanitation Program.
DEC's site has a public-records request page; the program's food safety help desk can also route it. Alaska law asks agencies to answer
within 10 working days, and a request that takes more than 5 hours of staff time can carry a fee, so the draft asks for an estimate first.

> Under the Alaska Public Records Act (AS 40.25.110–.220), I request electronic copies (CSV or Excel) of two existing records of the
> Food Safety and Sanitation Program:
> 1. The current list of active retail food establishment permits (the list published at dec.alaska.gov/eh/fss/active-permits-retail),
>    with permit number, establishment name, establishment type, street address, city, zip and permit status.
> 2. An export from the program's inspection database of retail food establishment inspections from January 1, 2024 to the present,
>    with, where they exist: permit number, establishment name, address, inspection date, inspection type (routine, follow-up,
>    complaint, pre-opening), any score or result the inspection records, and the risk-factor and other items marked out of
>    compliance, corrected on site (COS) or repeat (R).
>
> I don't need owner, operator or inspector names, or any other personal information. The records will be used in a free,
> non-commercial consumer app and website (no advertising, no purchases, no resale) that shows each establishment's results as DEC
> records them, labeled with DEC as the source and the date. If there is a fee, please send an estimate before starting work; a standard
> report or an existing export is fine. Please contact me at nick@eatsranked.com with any questions.

When the files arrive, save them in `data/raw/hand/` and tell the ak-eats session: `pipeline/official.py` gets a loader. If DEC's reports
carry no score, any summary of ours is labeled "our grade, not an official grade" everywhere; the permit list becomes the statewide
existence check (calibration outside Anchorage).

## 2. Municipality of Anchorage: restart the inspection export

The Health Department's open-data file (opendata.muni.org/LIVES/LIVES-flat.csv) and its ArcGIS layer (Restaurants_Inspected_Hosted) both
stop at May 18, 2026, while the department's Envision Connect site shows inspections after that (907 Alehouse & Grill, June 3, 2026).
To: AHDEnvironmentalHealth@anchorageak.gov (the address printed on the department's Envision Connect pages; phone 907-343-4200).

> Subject: Restaurant inspection open data stopped updating in May
>
> Hello, the restaurant inspection file on the Municipality's Open Data page (opendata.muni.org/LIVES/LIVES-flat.csv, "2026 Restaurant
> Health Inspection Data") hasn't changed since May 19, 2026: its newest inspection is May 18, while the Envision Connect inspection
> site shows visits from June 2026 on. The child-care file next to it still updates daily, so it looks like only the restaurant export
> stopped. Could you or the Office of Information Technology restart it? I build a free app that shows Anchorage's official inspection
> scores with their dates, and I'd like them to stay current. Thank you. Nick Soderstrom, nick@eatsranked.com

When the file updates, re-run the pipeline (`pipeline/official.py` reads it; "records through" follows the file).

## 3. Two state lists to download by hand (save into `ak-eats/data/raw/hand/`)

a. **DCCED Active Business Licenses (statewide):** on the State of Alaska Open Data Geoportal (gis.data.alaska.gov), search "Business
   License" and open the Division of Corporations, Business and Professional Licensing dataset whose download is the "Active Business
   License CSV" (hosted on commerce.alaska.gov). Download the CSV and save it as `data/raw/hand/business_licenses.csv`. If the
   geoportal only offers the map layer, the same CSV is linked from commerce.alaska.gov's business license search page ("Download
   Active Business License Data"). We use only the business name, the physical address and the line of business/NAICS; owners and legal
   entity names are never shown.
b. **AMCO liquor licenses (statewide):** open accis.elicense365.com/Apps/LicenceSimpleSearch/, set Type = License, type `AK` in State (the
   form needs one field), click Search, then "Export to Excel" above the results. Save it as `data/raw/hand/amco_licenses.xlsx`. If the
   export caps the rows, repeat with City = Anchorage, Fairbanks, Juneau and the rest, and save each file there. The licensee name is
   never shown.
