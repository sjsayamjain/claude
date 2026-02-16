# Plan: Stocks Page Redesign

Mirror the MutualFundsPage redesign: fix broken chart, add missing chart types, wire exports, redesign layout from cramped sidebar to full-width.

## Problems Identified (from screenshots + code review)

1. **Candlestick & Area chart types not implemented** — `StockChart.tsx:209-219` only renders `<Line>` when `chartType === 'line'`. Selecting Candle or Area → blank chart.
2. **Cramped sidebar layout** — Stock Details + Chart Options + Corporate Actions + Data Coverage crammed into 1/4 width sidebar (same issue as MF page had).
3. **Export buttons non-functional** — `StockChart.tsx:252-276` has Export PNG & CSV buttons with no `onClick` handlers.
4. **Stock name not prominent** — Only visible in search suggestions. After selection, only symbol shown.
5. **`symbol` prop unused** — Destructured in StockChart but never rendered.
6. **Lint error** — `useEffect` calling `setState` on mount (same as MF had), `_query` unused param.
7. **No single-date price lookup** — User can't pick a specific date to see the EOD price.
8. **Chart type selector buried in sidebar** — Should be near the chart, not in a separate card.

## Files to Modify

| File | Changes |
|------|---------|
| `src/components/organisms/StockChart.tsx` | Add area chart type, remove PNG export, wire CSV export, accept `stockName` prop, remove exchange badge (moved to page), accept `chartType` controls |
| `src/components/pages/StocksPage.tsx` | Full layout redesign mirroring MF page pattern |

## New Layout (StocksPage)

```
[Page Header: "Stocks" + subtitle]
[Search Bar + Exchange Toggle (NSE/BSE/Both)]

--- When stock selected: ---

[Stock Header Bar — Card]
  Left: Company name (h3) + symbol + exchange badge
  Right: Current Price (large) + day's high/low/volume

[Date Range Controls — single row]
  Preset buttons: 1M 3M 6M 1Y 3Y 5Y 10Y ALL CUSTOM

[Chart Type Toggle + Full-width Chart Card]
  Chart type: Line | Area  (above chart, right-aligned)
  Chart: Full-width StockChart
  Volume sub-chart below
  Export CSV button below chart

[Raw Data Summary — row of 3 small cards]
  Data Points | First Trade Date | Last Trade Date

[Two-column grid below:]
  Left: Date Price Lookup (pick date → show OHLCV for that date)
  Right: Corporate Actions (with more room than sidebar)
```

## Detailed Changes

### 1. StockChart.tsx

**Add Area chart type** (currently only Line renders):
- Import `Area` and `defs`/`linearGradient` from recharts
- When `chartType === 'area'`: render `<Area>` with fill gradient on close price
- When `chartType === 'line'`: keep existing `<Line>`
- Remove `chartType === 'candlestick'` option entirely (Recharts has no native candlestick — would need custom shapes, complex to maintain, low value vs line/area)

**Wire CSV export**:
- Import `exportToCSV` from `../../lib/utils/export`
- `handleExportCSV()`: export date, open, high, low, close, volume columns
- Remove Export PNG button (html2canvas not installed)

**Accept `stockName` prop**:
- Add optional `stockName?: string` to props
- Use in Legend line name instead of "Close Price"

**Remove exchange badge from chart** — moved to page-level Stock Header Bar

**Remove `symbol` from destructuring** (unused, will get it from stockName prop context)

**Move chart type toggle INTO the chart component** (optional, or keep at page level — keep at page level for consistency with MF pattern where page controls the data flow)

### 2. StocksPage.tsx — Full Rewrite

**Remove**:
- The 3/4 + 1/4 grid layout (sidebar too cramped)
- The 5 KPI cards at top (redundant — move key info to Stock Header Bar)
- The "Date Range:" label wrapper
- The sidebar cards (Stock Details, Chart Options, Corporate Actions, Data Coverage)
- The `useEffect` for initial state reset (just use `useState('ALL')` directly)
- The `_query` unused param in `handleSearch`

**New sections (mirroring MF page)**:

#### A. Stock Header Bar
Card with:
- Company name (h3, from search result `suggestion.label`, stored in state)
- Symbol as text + Exchange as Badge
- Current Price (large) + High / Low / Volume as secondary stats

#### B. Date Range Controls
Keep existing `DateRangeSelector` directly (no wrapper div/label).

#### C. Chart Type Toggle + Full-Width Chart
- Chart type buttons (Line / Area) directly above chart, right-aligned
- Full-width `StockChart` with `showVolume`
- Pass `stockName` for tooltip/legend

#### D. Raw Data Summary
Row of 3 compact cards:
- **Data Points**: `eodData.length`
- **First Trade Date**: oldest date in dataset
- **Last Trade Date**: newest date in dataset

#### E. Date Price Lookup + Corporate Actions (two-column)
- **Left**: Date input → find exact OHLCV match in `eodData`, display Open/High/Low/Close/Volume
- **Right**: Corporate Actions — reuse existing `CorporateActionItem` component with "View All" link

**State additions**:
- `stockName: string` — stored when user selects from search results
- `lookupDate: string` — for the date price lookup feature

**State removals**:
- Remove `chartType === 'candlestick'` from union type (only `'line' | 'area'`)

## Existing Utilities to Reuse

| Utility | File | Usage |
|---------|------|-------|
| `formatCurrency()` | `lib/utils/format.ts` | Price display |
| `formatDate()` | `lib/utils/date.ts` | Date formatting |
| `formatCompactNumber()` | `lib/utils/format.ts` | Volume display |
| `exportToCSV()` | `lib/utils/export.ts` | CSV download |
| `transformDataForChart()` | `lib/utils/chart.ts` | EOD→chart data |
| `DateRangeSelector` | `molecules/DateRangeSelector.tsx` | Date controls |
| `Card`, `Badge`, `Button` | `atoms/` | Layout primitives |
| `CorporateActionItem` | Already in StocksPage | Reuse inline component |

## Verification

1. `npm run build` — no TypeScript errors
2. `npx eslint src/components/pages/StocksPage.tsx src/components/organisms/StockChart.tsx` — zero errors
3. Manual testing:
   - Navigate to `/stocks`
   - Search for "Latent View" → select stock
   - Verify: company name prominent, exchange badge, current price displayed
   - Verify: Line chart renders correctly (was already working)
   - Verify: Area chart renders correctly (new)
   - Try all date range presets (1M through ALL + CUSTOM)
   - Verify: Export CSV downloads correct OHLCV data
   - Verify: Date Price Lookup returns OHLCV for picked date
   - Verify: Corporate actions display correctly with more room
   - Verify: Responsive on mobile (stacks vertically)
