# Wayback Machine AMFI Snapshot Backfill — Implementation Plan

## Goal

Fetch ~80 historical AMFI NAVAll.txt snapshots from the Internet Archive Wayback Machine (Oct 2016 → Nov 2025), compare consecutive pairs, and detect **real** MF corporate actions (NFOs, closures, name changes, recategorizations, AMC changes). Replaces the NAV-inference approach (`BackfillMFCorpActionsFromNAVs`) with actual snapshot-diffing.

## Context (Validated via CDX API)

- **77 unique snapshot dates** across two archived URLs (1 overlap on 2017-12-22):
  - `amfiindia.com/spages/NAVAll.txt` — 33 snapshots (Oct 2016 – Sep 2025)
  - `portal.amfiindia.com/spages/NAVAll.txt` — 45 snapshots (Dec 2017 – Nov 2025)
- All snapshots are identical AMFI format → existing `ParseAMFINAVAll()` works directly (verified: Oct 2016 snapshot parses correctly)
- **Dense coverage during SEBI recategorization**: 2018 has 18 snapshots, 2019 has 24 snapshots
- **Coverage by year**: 2016(4), 2017(9), 2018(18), 2019(24), 2020(3), 2021(2), 2022(1), 2023(0), 2024(7), 2025(9)
- **Notable gaps**: 2022-03 to 2024-01 (675 days), 2020-03 to 2020-09 (204 days). Actions during gaps get attributed to next available snapshot's comparison date.
- Existing infrastructure reused as-is: `CompareSnapshotsAndDetectActions()`, `BulkUpsertMFCorporateActions()`, `StoreSchemeSnapshot()`

## Files to Modify (2 files, ~180 lines total)

### 1. `internal/pipeline/fetcher.go` — Add 2 methods + 1 type (~60 lines)

**New type:**
```go
type WaybackSnapshot struct {
    Timestamp   string    // "20161025144325" format (14 digits)
    OriginalURL string    // e.g. "http://www.amfiindia.com:80/spages/NAVAll.txt"
    Date        time.Time // parsed from Timestamp[:8] → 2016-10-25
}
```

**`FetchWaybackCDX(ctx, originalURL string) ([]WaybackSnapshot, error)`**
- Calls: `https://web.archive.org/cdx/search/cdx?url={url}&output=json&filter=statuscode:200&collapse=timestamp:8`
- `collapse=timestamp:8` deduplicates to one snapshot per day
- CDX returns JSON array of arrays: `[["urlkey","timestamp","original",...], [row1], [row2], ...]`
- Parse column 1 (timestamp) and column 2 (original URL) from each row (skip header row)
- Parse date from `timestamp[:8]` using `time.Parse("20060102", ...)`
- Returns `[]WaybackSnapshot` sorted by timestamp ascending

**`FetchWaybackSnapshot(ctx, timestamp, originalURL string) (*FetchResult, error)`**
- Fetches: `https://web.archive.org/web/{timestamp}id_/{originalURL}`
- The `id_` suffix returns raw content (no Wayback toolbar HTML injection)
- Uses existing `fetchWithRetry()` with source `"wayback"`
- Rate-limited by caller (1.5s delay between fetches in sync loop)

### 2. `internal/pipeline/sync.go` — Add 1 method, replace 1 block (~120 lines)

**`syncMFCorpActionsWaybackBackfill(ctx) (*MFCorpActionSyncResult, error)`**

Algorithm:
1. Fetch CDX listings for both AMFI URLs (2 API calls):
   - `amfiindia.com/spages/NAVAll.txt` → 33 results
   - `portal.amfiindia.com/spages/NAVAll.txt` → 45 results
2. Merge into one list. Deduplicate by calendar date (`Timestamp[:8]`): if same date appears from both URLs, keep the first one. Result: ~77 unique snapshots.
3. Sort chronologically by date
4. Log sync start, snapshot count
5. Loop through snapshots sequentially:
   - Fetch snapshot via `FetchWaybackSnapshot(ctx, snap.Timestamp, snap.OriginalURL)`
   - Parse with `ParseAMFINAVAll(fetchResult.Data)` → `[]MFScheme`
   - If first snapshot: just store via `StoreSchemeSnapshot()`, set as `previousSchemes`
   - Otherwise: compare via `CompareSnapshotsAndDetectActions(currentSchemes, previousSchemes, snap.Date)`
   - Store snapshot, accumulate actions, advance `previousSchemes = currentSchemes`
   - 1.5s delay between fetches (respect Wayback Machine rate limits)
   - Log progress every 10 snapshots (snapshot N/77, actions so far, duration)
   - On fetch/parse error: log warning, skip that snapshot, continue with next
6. Bulk upsert all accumulated actions via `BulkUpsertMFCorporateActions()`
7. Log sync complete with totals

**Replace existing NAV-based block** at `sync.go:250-274` (the `BackfillMFCorpActionsFromNAVs` call) with:
```go
if s.config.EnableMFCorpActions {
    mfCorpResult, err := s.syncMFCorpActionsWaybackBackfill(ctx)
    result.MFCorpActionResult = mfCorpResult
    if err != nil {
        result.Errors = append(result.Errors, fmt.Sprintf("MF corp actions Wayback backfill: %v", err))
        s.logger.Error("MF corp actions Wayback backfill failed", "error", err)
    }
}
```

**No new CLI flags needed** — existing `--mf-corp-actions` + `--mode backfill` triggers this.

## What Gets Reused (0 new files)

| Component | File:Lines | Usage |
|-----------|-----------|-------|
| `ParseAMFINAVAll()` | `parser_mf.go:52-117` | Parse each Wayback snapshot |
| `CompareSnapshotsAndDetectActions()` | `parser_mfcorpactions.go:50-171` | Compare consecutive snapshots |
| `StoreSchemeSnapshot()` | `store.go:966-1048` | Store each historical snapshot |
| `BulkUpsertMFCorporateActions()` | `store.go:1098-1240` | Upsert detected actions |
| `fetchWithRetry()` | `fetcher.go:350-381` | HTTP fetch with retry/backoff |
| `MFScheme`, `MFCorporateAction` types | Various | All existing types reused |

## Execution Flow

```
Step 1: CDX API → discover 77 snapshots (2 HTTP calls, ~1s each)
Step 2: Merge both URL lists, deduplicate by calendar date, sort chronologically
Step 3: Fetch snapshot #1 (Oct 2016) → parse → store snapshot (no comparison yet)
Step 4: Fetch snapshot #2 (Nov 2016) → parse → compare with #1 → detect actions → store
  ...repeat for all 77 snapshots...
Step 78: Fetch last snapshot (Nov 2025) → parse → compare with #76 → detect actions → store

Total: 77 HTTP fetches × 1.5s delay ≈ 2 minutes network + ~30s parsing
Each snapshot: ~260KB download, ~14K schemes parsed
Expected output: 1000-5000+ real corporate actions (especially rich 2018-2019)
```

## Expected Results

| Action Type | Expected Count | How Detected |
|-------------|---------------|--------------|
| NFO | 1000-3000 | Scheme in snapshot N+1, absent in N |
| WINDING_UP | 500-1500 | Scheme in snapshot N, absent in N+1 |
| NAME_CHANGE | 200-500 | Same scheme_code, different scheme_name |
| RECATEGORIZATION | 500-2000 | Same scheme_code, different fund_category (SEBI 2017-18) |
| AMC_CHANGE | 10-50 | Same scheme_code, different amc_name |

## Handling Existing NAV-Inferred Data

The 59,459 NAV-inferred actions (source=`nav_analysis`) already in the DB use different effective dates than Wayback-detected actions (source=`amfi_snapshot`). Since the UNIQUE constraint is on `(scheme_code, action_type, effective_date)`, they won't conflict — both sources coexist. After verifying Wayback results are correct, we can optionally clean up via:
```sql
DELETE FROM mf_corporate_actions WHERE source = 'nav_analysis';
```

## Verification

```bash
# 1. Run backfill
./marketdata-sync --db "postgres://marketdata:changeme@localhost:5433/marketdata?sslmode=disable" \
  --mode backfill --mf-corp-actions -v

# 2. Check action counts by type
docker exec marketdata-db psql -U marketdata -d marketdata -c \
  "SELECT action_type, COUNT(*), MIN(effective_date), MAX(effective_date)
   FROM mf_corporate_actions WHERE source='amfi_snapshot'
   GROUP BY action_type ORDER BY count DESC;"

# 3. Verify SEBI 2017-2018 recategorization captured
docker exec marketdata-db psql -U marketdata -d marketdata -c \
  "SELECT COUNT(*) FROM mf_corporate_actions
   WHERE action_type='RECATEGORIZATION'
   AND effective_date BETWEEN '2017-01-01' AND '2019-01-01';"

# 4. Verify snapshots stored
docker exec marketdata-db psql -U marketdata -d marketdata -c \
  "SELECT snapshot_date, COUNT(*) as schemes
   FROM mf_scheme_snapshots GROUP BY snapshot_date ORDER BY snapshot_date;"

# 5. Check a specific name change
docker exec marketdata-db psql -U marketdata -d marketdata -c \
  "SELECT scheme_code, old_name, new_name, effective_date
   FROM mf_corporate_actions WHERE action_type='NAME_CHANGE' LIMIT 10;"

# 6. Daily pipeline still works (daily mode unchanged)
./marketdata-sync --db "..." --mf-corp-actions --date 2026-02-13 -v

# 7. Compile and run existing tests
go build ./cmd/marketdata-sync && go test ./internal/pipeline/...
```

## Implementation Order

1. Add `WaybackSnapshot` type + `FetchWaybackCDX()` + `FetchWaybackSnapshot()` to `fetcher.go`
2. Add `syncMFCorpActionsWaybackBackfill()` to `sync.go`
3. Replace the NAV-based backfill block in `Run()` with Wayback backfill call
4. Build and verify compilation
5. Run backfill, verify results
