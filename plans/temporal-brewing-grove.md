# Plan: Complete Data Coverage — Corporate Actions, Symbols, Holidays, Index Data

## Goal

Make the pipeline capture **every piece of freely available Indian market data** — fix all filtering gaps, add corporate actions, symbol masters, market holidays, and index data.

## Current State

- 33.6M MF NAVs (36,804 schemes, 2006-2026) ✅
- 4.17M NSE EODs (4,024 symbols, 1996-2026) ✅
- 8.13M BSE EODs (20,226 symbols, 2016-2026) ✅
- Re-backfill is safe: MF NAVs update conditionally, stock EODs overwrite unconditionally

## Problems Found (from 4-agent deep analysis)

1. **NSE series filter too aggressive** — only EQ/BE/BZ/SM/ST kept, ETFs/InvITs/REITs/Gold Bonds excluded
2. **No corporate actions** — splits, bonuses, dividends, rights, name changes missing entirely
3. **No symbol master sync** — symbols only come from bhavcopy, sector/industry never populated
4. **No market holiday calendar** — discovers holidays via 404 errors, `is_trading_day()` SQL exists but unused
5. **UDiFF deliverable data not parsed** — `DLVRYQTY`/`DLVRYPCT` columns ignored
6. **No index data** — Nifty 50, Sensex, sector indices missing
7. **Dead code** — `stringToUpper()` in fetcher.go unused
8. **`mv_latest_eod` only shows EQ series** — even if we add ETFs, the view won't show them

---

## Phase A: Quick Wins (fix existing gaps)

### A1. Expand NSE series filter

**File**: `internal/pipeline/parser_stocks.go` (line 105)

Replace inline `if` with map-based lookup. Add series:

| Series | What | Action |
|--------|------|--------|
| EQ, BE, BZ, SM, ST | Equity types | Already included |
| **E1** | ETFs | **ADD** |
| **IV** | InvITs | **ADD** |
| **RR** | REITs | **ADD** |
| **GB** | Sovereign Gold Bonds | **ADD** |
| **GS** | Govt Securities (retail) | **ADD** |
| **MF** | Exchange-traded MF units | **ADD** |

```go
var nseAllowedSeries = map[string]bool{
    "EQ": true, "BE": true, "BZ": true, "SM": true, "ST": true,
    "E1": true, "IV": true, "RR": true, "GB": true, "GS": true, "MF": true,
}
// Replace line 105: if nseAllowedSeries[stock.Series] {
```

### A2. Parse deliverable qty/pct from UDiFF format

**File**: `internal/pipeline/parser_stocks.go` (lines 262-268)

Add UDiFF column name aliases to the existing `getValue()` calls:

```go
// Change from: getValue("DELIV_QTY")
// Change to:   getValue("DELIV_QTY", "DLVRYQTY", "DLVRBLQTY")
// Same for:    getValue("DELIV_PER", "DLVRYPCT", "PCTDLVRYTOTTRDGVOL")
```

### A3. Conditional stock EOD update (avoid unnecessary writes on re-backfill)

**File**: `internal/pipeline/store.go` (lines 380-391)

Add WHERE clause to stock EOD ON CONFLICT (like MF NAVs already have):

```sql
ON CONFLICT ... DO UPDATE SET ...
WHERE stock_eod.close_price != EXCLUDED.close_price
   OR stock_eod.volume != EXCLUDED.volume
   OR COALESCE(stock_eod.deliverable_qty, 0) != COALESCE(EXCLUDED.deliverable_qty, 0)
```

### A4. Remove dead code

**File**: `internal/pipeline/fetcher.go` (lines 330-341)

Delete `stringToUpper()` — never called, `strings.ToUpper()` used everywhere instead.

### A5. Market holidays table

**New file**: `migrations/002_market_holidays.sql`

```sql
CREATE TABLE IF NOT EXISTS market_holidays (
    holiday_date DATE NOT NULL,
    exchange     VARCHAR(10) NOT NULL DEFAULT 'BOTH',
    name         TEXT NOT NULL,
    PRIMARY KEY (holiday_date, exchange)
);
```

Seed with 2016-2027 NSE/BSE holidays (both exchanges share holidays for equities). Rewrite `is_trading_day()` to query this table.

**File**: `internal/pipeline/store.go` — add `IsTradingDay(ctx, date, exchange)` method.

**File**: `internal/pipeline/sync.go` (line 714-717) — use `IsTradingDay()` instead of just weekend check in backfill loop. Silently skip holidays instead of getting 404s.

### A6. Fix mv_latest_eod to include all allowed series

**File**: `migrations/002_market_holidays.sql` (same migration)

Drop and recreate `mv_latest_eod` to remove the `WHERE e.series = 'EQ'` filter, or change it to include all allowed series.

---

## Phase B: Corporate Actions

### B1. Schema

**New file**: `migrations/003_corporate_actions.sql`

```sql
CREATE TABLE IF NOT EXISTS corporate_actions (
    id              BIGSERIAL PRIMARY KEY,
    symbol          VARCHAR(20) NOT NULL,
    exchange        VARCHAR(10) NOT NULL DEFAULT 'NSE',
    action_type     VARCHAR(30) NOT NULL,   -- SPLIT, BONUS, DIVIDEND, RIGHTS, NAME_CHANGE, MERGER, BUYBACK
    ex_date         DATE NOT NULL,
    record_date     DATE,
    ratio_from      INTEGER,                -- old face value (split) or held shares (bonus)
    ratio_to        INTEGER,                -- new face value (split) or free shares (bonus)
    dividend_amount DECIMAL(15,4),
    dividend_pct    DECIMAL(8,4),
    dividend_type   VARCHAR(20),            -- INTERIM, FINAL, SPECIAL
    rights_price    DECIMAL(15,2),
    old_symbol      VARCHAR(20),
    new_symbol      VARCHAR(20),
    description     TEXT,                   -- raw subject text from exchange
    source          VARCHAR(20) NOT NULL,
    raw_data        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (symbol, exchange, action_type, ex_date)
);
```

### B2. Fetcher — NSE corporate actions

**File**: `internal/pipeline/fetcher.go`

NSE API requires session cookies. Two-step approach:
1. `getNSESessionCookies(ctx)` — GET `https://www.nseindia.com/` to obtain cookies
2. `FetchNSECorporateActions(ctx, from, to)` — GET `https://www.nseindia.com/api/corporates-corporateActions?index=equities&from_date=DD-MM-YYYY&to_date=DD-MM-YYYY` with cookies

If NSE blocks the API (anti-bot), fallback: NSE archives publish corporate action reports as CSV.

### B3. Fetcher — BSE corporate actions

**File**: `internal/pipeline/fetcher.go`

BSE API is open (no session cookies):
`FetchBSECorporateActions(ctx, from, to)` — GET `https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w?from_date=YYYYMMDD&to_date=YYYYMMDD&segment=Equity`

### B4. Parser

**New file**: `internal/pipeline/parser_corpactions.go`

Types: `CorporateAction`, `CorporateActionParseResult`

Two parse functions: `ParseNSECorporateActions(data)`, `ParseBSECorporateActions(data)`

Key challenge: parsing the NSE `subject` field into structured data:
- `"Bonus issue 1:1"` → action_type=BONUS, ratio_from=1, ratio_to=1
- `"Face Value Split From Rs. 10/- to Rs. 2/-"` → action_type=SPLIT, ratio_from=10, ratio_to=2
- `"Dividend - Rs 10/- Per Share"` → action_type=DIVIDEND, dividend_amount=10
- `"Interim Dividend Rs.22.50"` → dividend_type=INTERIM, dividend_amount=22.50

Use regex patterns for each action type. Store raw `subject` in `description` for anything unparseable.

### B5. Store + Sync

**File**: `internal/pipeline/store.go` — `BulkUpsertCorporateActions()` (COPY + upsert pattern)

**File**: `internal/pipeline/sync.go` — `syncCorporateActions(ctx, from, to)`:
- Daily mode: fetch last 30 days (catches newly announced actions)
- Backfill mode: fetch from `--from` to `--to`

### B6. CLI + API

**File**: `cmd/marketdata-sync/main.go` — add `--corp-actions` flag. Included in `full` mode by default.

**File**: `internal/api/handlers_market.go` — add `GET /api/v1/stocks/{symbol}/corporate-actions?exchange=&type=&from=&to=`

---

## Phase C: Symbol Master Sync

### C1. Fetchers

**File**: `internal/pipeline/fetcher.go`

- `FetchNSEEquityList(ctx)` — GET `https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv` (direct, no auth)
  - Fields: SYMBOL, NAME OF COMPANY, SERIES, DATE OF LISTING, PAID UP VALUE, MARKET LOT, ISIN NUMBER, FACE VALUE
- `FetchBSEScripMaster(ctx)` — GET `https://api.bseindia.com/BseIndiaAPI/api/ListOfScripData/w?segment=Equity&status=Active`
  - Fields: SCRIP_CD, SCRIP_NAME, STATUS, GROUP, FACE_VALUE, ISIN_NUMBER, INDUSTRY, SECTOR_NAME

### C2. Parser

**New file**: `internal/pipeline/parser_symbols.go`

Types: `SymbolMasterEntry` (symbol, company_name, series, isin, exchange, sector, industry, face_value, listing_date, is_active)

- `ParseNSEEquityList(data)` — CSV parse
- `ParseBSEScripMaster(data)` — JSON parse

### C3. Schema enhancement

**New file**: `migrations/004_symbol_master.sql`

```sql
ALTER TABLE stock_symbols ADD COLUMN IF NOT EXISTS face_value DECIMAL(10,2);
ALTER TABLE stock_symbols ADD COLUMN IF NOT EXISTS listing_date DATE;
ALTER TABLE stock_symbols ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE stock_symbols ADD COLUMN IF NOT EXISTS delisted_date DATE;
```

### C4. Store + Sync

**File**: `internal/pipeline/store.go` — `BulkUpsertSymbolMaster()` — updates sector, industry, face_value, listing_date (existing columns + new ones). Uses COALESCE to not clobber existing data with empty values.

**File**: `internal/pipeline/sync.go` — `syncSymbolMaster(ctx)` — fetch + parse + store for both exchanges. Run once per day in `full` mode.

### C5. CLI

**File**: `cmd/marketdata-sync/main.go` — add `--symbol-master` flag. Included in `full` mode.

---

## Phase D: Index Data

### D1. Schema

**New file**: `migrations/005_index_data.sql`

Tables:
- `market_indices` — index master (code, exchange, display_name, base_date, base_value)
- `index_eod` — daily OHLCV per index (partitioned by year like stock_eod)
- `index_constituents` — which symbols are in which index + weight

### D2. Fetchers

**File**: `internal/pipeline/fetcher.go`

- `FetchNSEIndexBhavcopy(ctx, date)` — GET `https://nsearchives.nseindia.com/content/indices/ind_close_all_DDMMYYYY.csv`
  - Contains OHLCV for ALL ~100 NSE indices in one CSV. No auth needed.
- `FetchNSEIndexConstituents(ctx, indexSlug)` — GET `https://www.niftyindices.com/IndexConstituent/ind_{slug}list.csv`
  - e.g., `ind_nifty50list.csv`, `ind_niftybanklist.csv`

### D3. Parser

**New file**: `internal/pipeline/parser_index.go`

Types: `IndexEOD`, `IndexConstituent`

- `ParseNSEIndexBhavcopy(data, date)` — CSV with columns: Index Name, Index Date, Open, High, Low, Close, Points Change, Change%, Volume, Turnover, P/E, P/B, Div Yield
- `ParseNSEIndexConstituents(data, indexCode, asOfDate)` — CSV with: Company Name, Industry, Symbol, Series, ISIN

### D4. Store + Sync

**File**: `internal/pipeline/store.go` — `BulkUpsertIndexEOD()`, `BulkUpsertIndexConstituents()`

**File**: `internal/pipeline/sync.go` — `syncIndexData(ctx, date)`:
- Fetch NSE index bhavcopy for the target date
- Parse all indices
- Store
- Fetch constituents weekly (not daily — composition changes rarely)

### D5. CLI + API + Materialized View

**File**: `cmd/marketdata-sync/main.go` — add `--index-only`, `--no-index` flags

**File**: `internal/api/handlers_market.go` — add endpoints:
- `GET /api/v1/indices/{code}/eod` — latest
- `GET /api/v1/indices/{code}/history` — historical
- `GET /api/v1/indices/{code}/constituents`
- `GET /api/v1/indices/search?q=nifty`

Add `mv_latest_index` materialized view.

---

## Files Summary

### New Files (7)

| File | Phase | Purpose |
|------|-------|---------|
| `migrations/002_market_holidays.sql` | A | Holiday table + seed + fix is_trading_day() + fix mv_latest_eod |
| `migrations/003_corporate_actions.sql` | B | Corporate actions table |
| `migrations/004_symbol_master.sql` | C | Add face_value, listing_date, is_active, delisted_date to stock_symbols |
| `migrations/005_index_data.sql` | D | market_indices, index_eod, index_constituents tables |
| `internal/pipeline/parser_corpactions.go` | B | Corporate actions parser (NSE + BSE) |
| `internal/pipeline/parser_symbols.go` | C | Symbol master parser (NSE EQUITY_L.csv + BSE scrip JSON) |
| `internal/pipeline/parser_index.go` | D | Index bhavcopy + constituents parser |

### Modified Files (6)

| File | Phases | Changes |
|------|--------|---------|
| `internal/pipeline/parser_stocks.go` | A | Series filter → map, UDiFF deliverable columns |
| `internal/pipeline/store.go` | A,B,C,D | Conditional EOD update, IsTradingDay(), BulkUpsertCorporateActions(), BulkUpsertSymbolMaster(), BulkUpsertIndexEOD(), BulkUpsertIndexConstituents() |
| `internal/pipeline/fetcher.go` | A,B,C,D | Remove stringToUpper(), getNSESessionCookies(), FetchNSE/BSECorporateActions(), FetchNSEEquityList(), FetchBSEScripMaster(), FetchNSEIndexBhavcopy(), FetchNSEIndexConstituents() |
| `internal/pipeline/sync.go` | A,B,C,D | Holiday-aware backfill, syncCorporateActions(), syncSymbolMaster(), syncIndexData() |
| `cmd/marketdata-sync/main.go` | B,C,D | New flags: --corp-actions, --symbol-master, --index-only, --no-index, --no-corp-actions |
| `internal/api/handlers_market.go` | B,D | Corporate actions endpoint, index endpoints |

---

## Verification Plan

### Phase A
1. `go build ./cmd/marketdata-sync` — compiles
2. Run daily sync for recent date → ETF symbols (NIFTYBEES, GOLDBEES) now appear
3. `SELECT COUNT(*) FROM stock_eod WHERE deliverable_qty > 0 AND trade_date = '2026-02-10'` — nonzero
4. Re-run same date → `RowsAffected = 0` (conditional update working)
5. `SELECT is_trading_day('2026-01-26', 'NSE')` → false (Republic Day)
6. Run backfill for week with holiday → no 404 for that date

### Phase B
1. `--corp-actions --date 2026-02-10 -v` — fetches and stores corporate actions
2. `SELECT action_type, COUNT(*) FROM corporate_actions GROUP BY action_type` — shows DIVIDEND, SPLIT, BONUS
3. Backfill: `--mode backfill --corp-actions --from 2024-01-01 -v`
4. Cross-check: find known RELIANCE 1:1 bonus (2017) or TCS dividend

### Phase C
1. `--symbol-master -v` — fetches NSE EQUITY_L.csv + BSE scrip master
2. `SELECT COUNT(*) FROM stock_symbols WHERE sector IS NOT NULL` — thousands (was 0)
3. `SELECT symbol, sector, industry, listing_date FROM stock_symbols WHERE sector IS NOT NULL LIMIT 10`

### Phase D
1. `--index-only --date 2026-02-10 -v` — fetches ~100 NSE indices
2. `SELECT * FROM index_eod WHERE index_code = 'Nifty 50' ORDER BY trade_date DESC LIMIT 5`
3. Backfill: `--mode backfill --index-only --from 2024-01-01 -v`
4. `SELECT * FROM index_constituents WHERE index_code = 'Nifty 50'`
5. API: `GET /api/v1/indices/Nifty%2050/history`

### Final
- Full sync: `--mode full -v` — runs everything (MF + NSE + BSE + corp actions + symbol master + indices)
- `--mode backfill --from 2016-01-04 -v` — full historical backfill with holiday skipping
- Update README.md and CLAUDE.md with new features, tables, flags
