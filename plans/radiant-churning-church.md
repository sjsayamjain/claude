# Fix: Session Restore Creating Duplicates

## Problem

When a user fills the IPS form, refreshes the page, and clicks "Restore", duplicate families/members/assets are created in the database. Root causes:

1. **`hydrateFromServer()` picks `families[0]` blindly** — no guarantee it's the right family
2. **`initSession()` always creates NEW family + IPS record** — the `initStartedRef` guard resets on refresh
3. **Server tracking maps are empty on fresh mount** — real-time sync effects treat all hydrated data as NEW entities
4. **`xxxSyncedOnce` refs skip only the first render** — hydration's `setFormData()` triggers a second render where syncs fire with empty maps

## Solution: 4-Part Fix

### Part A: Persist IPS session in sessionStorage

Store `{ ipsId, familyId }` in `sessionStorage` when a session is created. This survives page refresh (same as auth session) but clears on tab close.

### Part B: Targeted hydration using stored IPS ID

`hydrateFromServer()` reads IPS ID from sessionStorage instead of blindly listing all families. Falls back to most-recent IPS record if no stored session.

### Part C: Make `initSession` idempotent

Before creating a new family/IPS, check sessionStorage. If a session exists, just set the refs and skip creation.

### Part D: Gate sync effects on hydration completion

Replace `xxxSyncedOnce` refs with a `hydrationComplete` state flag + signature-based deduplication. Sync effects don't fire until server tracking maps are populated.

---

## Files to Modify

### 1. `src/hooks/useBackendSync.ts` (core changes)

**Add session persistence helpers** (after imports):
- `IPS_SESSION_KEY = 'ips_session'`
- `saveSession({ ipsId, familyId })` — writes to sessionStorage
- `loadSession()` — reads from sessionStorage, returns `StoredSession | null`
- `clearSession()` — removes from sessionStorage

**Add `hydrationComplete` state** (replaces ref approach for reactivity):
- `const [hydrationComplete, setHydrationComplete] = useState(false)`

**Modify `initSession`**:
- First check `loadSession()` — if found, set `familyIdRef`/`ipsIdRef`/`initStartedRef` and return (skip creation)
- Existing creation logic unchanged, but add `saveSession()` after successful creation

**Rewrite `hydrateFromServer`**:
- Check `loadSession()` first for `ipsId`/`familyId` — if found, immediately set refs + `initStartedRef`
- If no stored session, fetch `ipsRecordService.list()`, validate stored ID exists, fall back to most-recent
- Fetch all child entities using the specific `ipsId` and `familyId`
- **Clear** all server tracking maps before populating (prevent stale data)
- Call `setHydrationComplete(true)` before returning
- On early returns (no data, offline), also set `hydrationComplete = true`

**Update `BackendSyncState` interface**:
- Add `hydrationComplete: boolean`
- Add `clearSession: () => void`

### 2. `src/components/ips-form/IPSForm.tsx` (consumer changes)

**Update `useBackendSync` destructuring**:
- Add `hydrationComplete`, `clearSession`

**Replace 5 `xxxSyncedOnce` ref patterns with**:
- 5 `prevXxxRef` refs (signature strings)
- Each sync `useEffect`: guard on `!hydrationComplete`, compare signature to skip unchanged data

**Update mount hydration effect**:
- On successful hydration, inside `setFormData` updater: set all `prevXxxRef` baselines to hydrated data signatures (prevents sync effects from re-syncing hydrated data)

**Update `handleRestore`**:
- Same `prevXxxRef` baseline pattern inside `setFormData`

**Update `handleDiscardSaved`**:
- Add `clearSession()` call

**Update `handleLogout`**:
- Add `clearSession()` call

---

## Verification Plan

### Manual Test: Fresh Start
1. Clear all sessionStorage and localStorage
2. Login, fill Step 1, click Next
3. Verify: one family and one IPS record in DB
4. Fill Steps 2-5 with test data
5. Check DB: no duplicates

### Manual Test: Refresh & Auto-Restore
1. After filling form through Step 5, refresh the page
2. App should auto-load server data (no restore banner needed if auto-hydration succeeds)
3. Navigate through all steps — verify data is intact
4. Check DB: still only one family, same member/asset/goal counts

### Manual Test: Refresh & Restore Button
1. If auto-hydration shows restore banner, click "Restore"
2. All data should load from server
3. Navigate through steps, edit some data
4. Check DB: original records updated, no new families created

### Manual Test: Discard & Start Fresh
1. After filling form, refresh
2. Click "Discard"
3. Form should be empty
4. Fill new data, navigate past Step 1
5. Verify: NEW family/IPS created (old one still exists in DB, but session points to new one)

### Manual Test: Logout & Re-login
1. Fill form, logout
2. Login again
3. Should either auto-hydrate or show restore option
4. No duplicate creation

### DB Verification
After each test, run:
```sql
SELECT * FROM family;
SELECT * FROM ips;
SELECT * FROM familymember;
```
Confirm no unexpected duplicates.
