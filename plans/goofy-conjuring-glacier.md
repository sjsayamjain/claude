# Plan: Dashboard Refinement — Fix Bugs, Remove Calculations, Add Date Filters

## Overview

Fix currentNav bug, remove all client-side calculations from chart components, wire up corporate actions filters, and add date filter consistency across all pages. Raw data only — no derived values.

---

## Bug 1: CurrentNav Changes With Date Range (MF Page)

**Root cause**: `MutualFundsPage.tsx:78` derives `currentNav` from `navData[navData.length - 1].nav`. Since `navData` comes from the history endpoint (filtered by date range, ordered DESC, limited to 365), the "last" item is the oldest entry — which changes as date range changes.

**Same bug exists in StocksPage.tsx:57**: `latestEOD = eodData[eodData.length - 1]` — also wrong for the same reason.

**Fix**: Use the dedicated latest-value endpoints that already exist:
- `GET /api/v1/mf/nav/{scheme_code}` → always returns latest NAV from `mv_latest_nav`
- `GET /api/v1/stocks/{symbol}/eod?exchange=` → always returns latest EOD from `mv_latest_eod`

### Changes

**A. `client.ts` — Add 2 new fetch functions**
```
fetchMFLatestNAV(schemeCode) → GET /api/v1/mf/nav/{schemeCode}
fetchStockLatestEOD(symbol, exchange) → GET /api/v1/stocks/{symbol}/eod?exchange=
```

**B. `types.ts` — Add response type for latest NAV**
```
MFLatestNAVResponse { scheme_code, scheme_name, nav, nav_date }
StockLatestEODResponse { symbol, company_name, exchange, series, trade_date, open, high, low, close, prev_close, volume, turnover }
```

**C. `queries.ts` — Add 2 new hooks**
```
useMFLatestNAV(schemeCode) → calls fetchMFLatestNAV
useStockLatestEOD(symbol, exchange) → calls fetchStockLatestEOD
```

**D. `MutualFundsPage.tsx` — Use separate latest NAV call**
- Add `useMFLatestNAV(selectedScheme)` hook call
- KPI "Current NAV" → use `latestNAV.nav` (not from history)
- KPI "Latest Date" → use `latestNAV.nav_date` (not from history)
- Remove `currentNav` derivation from history array

**E. `StocksPage.tsx` — Use separate latest EOD call**
- Add `useStockLatestEOD(symbol, exchange)` hook call
- KPI cards (Current Price, Previous Close, High, Low, Volume) → use latest EOD response
- Remove `latestEOD` derivation from history array

---

## Bug 2: Remove All Calculations

### NAVChart.tsx (lines 109-126) — Remove `metrics` computation

The `metrics` useMemo computes: `change`, `changePercent`, `high`, `low` from data. This is calculations.

**Fix**: Remove the entire metrics block and its display (lines 157-183). Keep only the date range selector and the chart itself. The "Current NAV" is already shown in the page's KPI cards (now fixed via Bug 1).

### StockChart.tsx (lines 85-103) — Remove `metrics` computation

Same pattern: computes `change`, `changePercent`, `high`, `low`, `avgVolume`.

**Fix**: Remove the entire metrics block and its display (lines 148-177). The latest OHLCV is already shown in the page's KPI cards (now fixed via Bug 1). Keep the exchange badge.

---

## Feature: Wire Corporate Actions Filters

Currently `CorporateActionsPage.tsx` has filter UI (`FilterPanel`) but filters are never applied to API calls.

### Changes

**`CorporateActionsPage.tsx`**
- Change `const [filters] = useState({})` to `const [filters, setFilters] = useState({})`
- Wire `FilterPanel` `onApply` → read FilterContext values → update filters state
- Filters state flows into `useCorporateActions({ ...filters, limit: 5000 })` which already passes all keys via `buildURL`

Need to check how FilterPanel + FilterContext interact to wire correctly.

---

## Feature: Date Filters Across Pages

### Current State
- **MF Page**: Date range presets via NAVChart's built-in buttons (1M–ALL). Works but uses duplicate `getDateRangeFromPreset()`.
- **Stocks Page**: Uses `DateRangeSelector` component with presets. Works.
- **Corporate Actions Page**: No date filter at all.

### Changes

**A. Corporate Actions Page — Add date range filter**
- Add `DateRangePicker` component (already exists as molecule) to the filter sidebar
- Add `from`/`to` state, wire into `useCorporateActions` filters
- The backend already supports `from` and `to` query params

**B. MF Page — Use shared `calculateDateRange()` utility**
- Replace local `getDateRangeFromPreset()` (lines 23-55) with existing `calculateDateRange()` from `lib/utils/date.ts`
- This eliminates code duplication

---

## Files Modified

| # | File | Changes |
|---|------|---------|
| 1 | `market-data-dashboard/src/lib/api/types.ts` | Add `MFLatestNAVResponse`, `StockLatestEODResponse` types |
| 2 | `market-data-dashboard/src/lib/api/client.ts` | Add `fetchMFLatestNAV()`, `fetchStockLatestEOD()` |
| 3 | `market-data-dashboard/src/lib/api/queries.ts` | Add `useMFLatestNAV()`, `useStockLatestEOD()` hooks |
| 4 | `market-data-dashboard/src/lib/api/index.ts` | Export new hooks and types |
| 5 | `market-data-dashboard/src/components/pages/MutualFundsPage.tsx` | Use `useMFLatestNAV` for KPIs, replace `getDateRangeFromPreset` with `calculateDateRange` |
| 6 | `market-data-dashboard/src/components/pages/StocksPage.tsx` | Use `useStockLatestEOD` for KPIs |
| 7 | `market-data-dashboard/src/components/organisms/NAVChart.tsx` | Remove `metrics` computation + display |
| 8 | `market-data-dashboard/src/components/organisms/StockChart.tsx` | Remove `metrics` computation + display |
| 9 | `market-data-dashboard/src/components/pages/CorporateActionsPage.tsx` | Wire filters, add date range picker |

No backend changes needed — all required endpoints already exist.

## Verification

1. `cd market-data-dashboard && npx tsc --noEmit` — zero TypeScript errors
2. `npm run build` — clean production build
3. Test MF page: select scheme, change date range presets → "Current NAV" KPI stays constant
4. Test Stocks page: select stock, change date range → KPI cards stay constant (latest day OHLCV)
5. Test Corporate Actions: apply type/exchange/date filters → data updates
6. Verify no `Math.max`, `Math.min`, `changePercent`, `change`, `avgVolume` computations remain in chart components
