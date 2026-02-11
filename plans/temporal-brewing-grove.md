# Plan: Historical Data Backfill — Phase 1 (MF via MFapi.in)

## Goal

Implement `--mode backfill` for mutual funds using MFapi.in's full history endpoint (`/mf/{code}` — returns ALL NAVs from inception). This gives complete NAV history (2006+) for all 37,402 schemes.

## Why MF First

- One HTTP call per scheme = full history (no day-by-day looping)
- 10-worker concurrency pool already exists in `syncMutualFundsFallback`
- Fetcher (`FetchMFAPI`) already exists but is never called
- DB schema + upsert logic already handles ON CONFLICT (scheme_code, nav_date)
- Stock backfill is Phase 2 (needs two URL formats, day iteration, holiday handling)

## Volume Estimate

- 37,402 schemes × ~2,500 avg NAVs each = **~93M NAV rows**
- Each NAV row: ~30 bytes → **~2.8 GB** raw data + indexes ~5 GB
- Local Docker: fits comfortably

---

## Changes Required

### 1. New type: `NAVRecord` (`internal/pipeline/parser_mf.go`)

Add alongside existing `MFScheme`:

```go
type NAVRecord struct {
    Date time.Time
    NAV  float64
}
```

Add a `NAVHistory []NAVRecord` field to `MFScheme`. The existing `NAV`/`NAVDate` fields stay for backwards compat with the daily sync path.

### 2. New parser: `ParseMFAPIFullHistory()` (`internal/pipeline/parser_mfapi.go`)

New function that parses the `/mf/{code}` response (same JSON shape as `/latest`, but `Data[]` has thousands of entries):

```go
func ParseMFAPIFullHistory(data []byte) (*MFScheme, error)
```

- Parses `resp.Data` array → populates `scheme.NAVHistory` (all entries)
- Also sets `scheme.NAV`/`scheme.NAVDate` to `Data[0]` (latest) for scheme upsert compat
- Skips entries with unparseable NAV/date (log + continue)

### 3. New store method: `BulkInsertMFNAVHistory()` (`internal/pipeline/store.go`)

The existing `BulkInsertMFNAVs` reads one NAV per scheme. New method reads from `NAVHistory`:

```go
func (s *Store) BulkInsertMFNAVHistory(ctx context.Context, schemes []MFScheme) (inserted int, err error)
```

- Same COPY-to-temp-table pattern as existing `BulkInsertMFNAVs`
- Iterates `scheme.NAVHistory` to build rows (not single `scheme.NAV`)
- Same ON CONFLICT upsert logic
- Handles large batches (a single scheme can have 5,000+ NAVs)

### 4. New sync method: `syncMFBackfill()` (`internal/pipeline/sync.go`)

New orchestrator for backfill mode (similar to `syncMutualFundsFallback` but uses full history):

```go
func (s *Syncer) syncMFBackfill(ctx context.Context) (*MFSyncResult, error)
```

**Flow:**
1. Fetch scheme list via `FetchMFAPISchemeList()`
2. 10 concurrent workers fetch `FetchMFAPI(code)` (full history, NOT `/latest`)
3. Parse via `ParseMFAPIFullHistory()`
4. Batch store via `BulkUpsertMFSchemes` + `BulkInsertMFNAVHistory` every 100 schemes
5. Progress logging every 500 schemes
6. Graceful cancellation via context

**Rate limiting:** Add 100ms delay between requests per worker to stay gentle (~100 req/sec total across 10 workers). MFapi.in has no documented rate limit but courtesy matters.

### 5. Wire backfill mode in `Run()` (`internal/pipeline/sync.go`)

In the `Run()` method, add a check:

```go
if s.config.Mode == SyncModeBackfill && s.config.EnableMF {
    mfResult, err := s.syncMFBackfill(ctx)
    // ...
}
```

Backfill mode skips stocks for now (Phase 2). Daily sync path unchanged.

### 6. CLI: Add `--from` flag (`cmd/marketdata-sync/main.go`)

Not strictly needed for MF backfill (MFapi gives everything), but useful for stock backfill later. For now, `--mode backfill` is the only trigger needed. The `--date` flag is ignored in MF backfill since MFapi returns inception-to-date automatically.

Add a note in the `--mode backfill` path that stocks are not yet supported.

### 7. Batch size tuning

The existing fallback uses batch=500 schemes. For backfill, each scheme carries ~2,500 NAVs, so 500 schemes = 1.25M NAV rows per batch insert. That's too large for a single COPY + upsert transaction.

**Adjusted batch sizes:**
- Store every **50 schemes** (≈125K NAV rows per batch — manageable)
- Log progress every 500 schemes

---

## Files Modified

| File | Change |
|------|--------|
| `internal/pipeline/parser_mf.go` | Add `NAVRecord` type, `NAVHistory` field to `MFScheme` |
| `internal/pipeline/parser_mfapi.go` | Add `ParseMFAPIFullHistory()` function |
| `internal/pipeline/store.go` | Add `BulkInsertMFNAVHistory()` method |
| `internal/pipeline/sync.go` | Add `syncMFBackfill()`, wire into `Run()` for backfill mode |
| `cmd/marketdata-sync/main.go` | Log that backfill skips stocks, no new flags needed yet |

## Files NOT Modified

- `fetcher.go` — `FetchMFAPI(code)` already exists and works (tested earlier)
- `store.go` `BulkUpsertMFSchemes` — already works with `MFScheme`, will use existing `NAV`/`NAVDate` fields
- Daily sync path — completely untouched, backfill is a separate code path

---

## Verification Plan

1. **Build**: `go build ./cmd/marketdata-sync` — must compile clean
2. **Reset DB**: `docker compose -f deploy/docker-compose.yml down -v && up -d db`
3. **Quick test** (5 schemes): Write a temporary test in `cmd/test-backfill/main.go` that fetches 5 schemes with full history, parses them, stores to DB, and verifies NAV counts
4. **Full backfill**: `./marketdata-sync --db "..." --mode backfill --mf-only -v`
   - Expect: ~37K schemes processed, ~93M NAV rows inserted
   - Monitor progress via logs (every 500 schemes)
   - Duration estimate: 37K schemes / 100 req/sec ≈ 6-7 minutes for fetching + storage time
5. **Verify DB**:
   ```sql
   SELECT COUNT(*) FROM mf_navs;  -- Should be ~93M
   SELECT COUNT(DISTINCT scheme_code) FROM mf_navs;  -- Should be ~37K
   SELECT MIN(nav_date), MAX(nav_date) FROM mf_navs;  -- 2006-ish to 2026-02-09
   SELECT scheme_code, COUNT(*) FROM mf_navs GROUP BY scheme_code ORDER BY count DESC LIMIT 5;
   ```
6. **Daily sync still works**: Run `./marketdata-sync --db "..." --mode full --mf-only -v` and verify it doesn't break
7. **Update CLAUDE.md**: Document backfill mode, MFapi full history, volume numbers
