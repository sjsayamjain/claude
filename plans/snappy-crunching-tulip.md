# Plan: Bidirectional Family↔Member Sync + Consistent Restore/Discard Prompt

## Feature 1: Bidirectional Sync Between Step 1 (FamilyDetails) and Step 2 (Members)

### Problem
- Changing name/age in Step 1 does NOT update the "Self" member in Step 2
- Editing the "Self" member's name/age in Step 2 does NOT update `familyDetails.primaryName/primaryAge`
- The Self member is a one-time snapshot created in `goToStep()` (line 218-234 of IPSForm.tsx) only when `members.length === 0`

### Solution: Two `useEffect` hooks in IPSForm.tsx with a shared guard ref

**File: `src/components/ips-form/IPSForm.tsx`**

1. **Add `isSyncingRef`** (near line 52) — prevents infinite loops between the two effects
2. **Effect A: FamilyDetails → Self member** — watches `primaryName` and `primaryAge`, finds the Self member, updates it if different
3. **Effect B: Self member → FamilyDetails** — watches `formData.members`, finds Self member, updates `primaryName`/`primaryAge` if different
4. Both effects use `queueMicrotask(() => { isSyncingRef.current = false })` to reset the guard after React batches the reciprocal update

No changes needed to `FamilyDetailsStep.tsx` or `FamilyMembersStep.tsx` — the sync lives entirely in the state owner (IPSForm).

---

## Feature 2: Always Show Restore/Discard Prompt on Refresh

### Problem
- When server data exists, `hydrateFromServer()` auto-merges it and sets `showRestore(false)` — user never gets asked
- The prompt only shows when server has no data AND localStorage has data
- `isHydrating` is a non-reactive ref (`.current`), so the loading banner can be unreliable

### Solution: Deferred hydration with user consent

**File: `src/hooks/useBackendSync.ts`**

1. **Add `deferCompletion` option to `hydrateFromServer()`** — when true, skips calling `setHydrationComplete(true)` at end. This prevents sync effects from firing before user consents.
2. **Expose `markHydrationComplete()`** — lets IPSForm manually unlock sync effects after user clicks Restore or Discard
3. **Update `BackendSyncState` interface** to include new `markHydrationComplete` and updated `hydrateFromServer` signature

**File: `src/components/ips-form/IPSForm.tsx`**

4. **Add `pendingRestoreDataRef`** — holds server or localStorage data pending user consent
5. **Add `isLoadingRestore` state** — reactive boolean for the loading spinner (replaces unreliable `isHydrating` ref for this flow)
6. **Rewrite mount hydration effect** (lines 126-159):
   - Call `hydrateFromServer({ deferCompletion: true })`
   - If server data returned → store in `pendingRestoreDataRef`, set `showRestore(true)` (DON'T merge)
   - If no server data → check localStorage → set `showRestore` accordingly
7. **Rewrite `handleRestore`** (lines 161-188):
   - If pending data source is `'server'` → merge stored server data, set sig baselines, call `markHydrationComplete()`
   - If pending data source is `'localStorage'` → call `loadSaved()`, call `markHydrationComplete()`
8. **Rewrite `handleDiscardSaved`** (lines 190-197):
   - Clear localStorage + sessionStorage, reset form to defaults, call `markHydrationComplete()`

**File: `src/components/ips-form/form/FormBanners.tsx`**

9. **Add optional `restoreSource` prop** — differentiates banner text:
   - Server: "Previous session found. Restore your data?"
   - localStorage: "Unsaved local progress found. Restore your previous session?"

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/components/ips-form/IPSForm.tsx` | `isSyncingRef`, 2 bidirectional sync effects, `pendingRestoreDataRef`, `isLoadingRestore`, rewrite mount effect + handlers |
| `src/hooks/useBackendSync.ts` | `deferCompletion` param on `hydrateFromServer`, expose `markHydrationComplete`, update interface |
| `src/components/ips-form/form/FormBanners.tsx` | Add `restoreSource` prop for context-aware banner text |

## Verification

1. `npm run build` — ensure no type errors
2. `npm run dev` — manual testing:
   - **Bidirectional sync**: Fill Step 1 name/age → go to Step 2 → Self member matches. Edit Self member name → go back to Step 1 → primaryName updated. Edit age on either step → reflected on the other.
   - **Restore prompt (server data)**: Fill some data → refresh page → banner shows "Previous session found" → click Restore → data loads → click Discard on a second try → form resets
   - **Restore prompt (localStorage)**: Go offline or clear backend → fill data → refresh → banner shows "Unsaved local progress" → Restore/Discard both work
   - **No data**: Fresh session, no localStorage → no banner, form starts clean
   - **No infinite loops**: Open React DevTools profiler, verify no continuous re-renders after sync effects settle
