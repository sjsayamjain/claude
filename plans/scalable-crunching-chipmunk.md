# IPS Wizard -- Strategic Refactor Plan

Production app for Indian financial advisors. 9-step wizard, NLP parsing, real-time backend sync, offline support.

**Scope**: 6 phases, 24 items, independently shippable. Ordered by risk: data corruption > correctness > performance > security > architecture > polish.

---

## Phase 1: Data Safety (Critical -- Silent Corruption Bugs)

### 1.1 Add Per-Entity Sync Mutex

**File**: `src/hooks/useBackendSync.ts` (lines 184-489)

**Problem**: No locking. User adds a member and clicks "Next" before POST completes -- both the real-time effect (`IPSForm.tsx:124`) and `syncStep` (`useBackendSync.ts:671`) fire `syncMembers()` concurrently. Both see `server.has(id) === false`, both POST, creating duplicates.

**Fix**: Add `useRef(false)` per sync function. Check/lock at entry, unlock in `finally`.

```typescript
// Add near line 140:
const syncingMembers = useRef(false)
// ... one per entity type

// Wrap each sync function:
const syncMembers = useCallback(async () => {
  if (syncingMembers.current) return
  syncingMembers.current = true
  try { /* existing body */ }
  finally { syncingMembers.current = false }
}, [formDataRef])
```

Apply to: `syncMembers`, `syncAssets`, `syncCashflows`, `syncGoals`, `syncAssumptions`.

**Risk**: Safe (additive guard). **Verify**: Add member, immediately click Next. Network tab shows 1 POST, not 2.

---

### 1.2 Fix Hydration Error Recovery

**File**: `src/hooks/useBackendSync.ts` (lines 659-667)

**Problem**: If any request in `Promise.all` (line 593-606) fails, the catch block still sets `hydrationComplete = true`. Sync effects then fire against empty server maps, creating duplicates.

**Fix**: Do NOT set `hydrationComplete` in catch. Return null. Let `IPSForm.tsx` (line 184-208) decide -- fall back to localStorage or show error banner. Sync effects must not fire on partial data.

```typescript
catch (err) {
  console.warn('Failed to hydrate from server:', err)
  isHydratingRef.current = false
  // DO NOT set hydrationComplete -- sync effects must not fire
  return null
}
```

**Risk**: Moderate (changes hydration flow). **Verify**: Kill backend mid-hydration. App should show localStorage restore, not empty form with sync running.

---

### 1.3 Fix Server Map Delete Ordering

**File**: `src/hooks/useBackendSync.ts` (6 locations)

**Problem**: `server.delete(id)` at line 230 runs even if `memberService.delete()` throws. Next sync thinks item is gone, but backend still has it.

**Fix**: Move `server.delete(id)` inside `try`, after successful API call:

```typescript
try {
  await memberService.delete(familyId, backendId)
  server.delete(id)  // Only after success
} catch (err) {
  console.warn(`Failed to delete member:`, err)
  // Leave in map for retry
}
```

Apply to: members (line 230), assets (line 285), incomes (line 335), expenses (line 377), goals (line 428), assumptions (line 487).

**Risk**: Safe. **Verify**: Delete a member while backend is down. Bring backend up. Next sync retries the delete.

---

### 1.4 Split `toFrontendId` Into Read-Only and Generate Variants

**File**: `src/lib/api-mappers.ts` (lines 38-45)

**Problem**: `toFrontendId()` auto-generates a new ID as a side effect. If hydration runs twice, same backend ID gets two frontend IDs -- duplicates in UI.

**Fix**: Rename current method to `getOrCreateFrontendId` (used only in `fromApi*` mappers during hydration). Add a new `toFrontendId` that returns `string | undefined` (read-only).

```typescript
toFrontendId(entity: string, backendId: number): string | undefined {
  return this.maps.get(entity)?.toFrontend.get(backendId)
}

getOrCreateFrontendId(entity: string, backendId: number): string {
  const existing = this.toFrontendId(entity, backendId)
  if (existing) return existing
  const newId = generateId()
  this.register(entity, newId, backendId)
  return newId
}
```

Update all 6 `fromApi*` functions (lines 226, 269-270, 325-326, 340-341, 423-424) to use `getOrCreateFrontendId`.

**Risk**: Safe. **Verify**: Hydrate twice rapidly. Each backend ID maps to exactly one frontend ID.

---

## Phase 2: React Correctness

### 2.1 Eliminate Bidirectional primaryName/Self Sync

**File**: `src/components/ips-form/IPSForm.tsx` (lines 56, 79-121)

**Problem**: `primaryName` and Self member name are same data in two places. Two effects keep them in sync using `isSyncingRef` mutex + `queueMicrotask()`. Timing-dependent, `eslint-disable`, double renders per keystroke.

**Fix**: Remove both effects (lines 79-121) and `isSyncingRef` (line 56). Make the `onChange` callbacks in `renderStep()` handle both updates atomically:

- `FamilyDetailsStep onChange`: Also update Self member if exists.
- `FamilyMembersStep onChange`: Also update `familyDetails.primaryName/Age` if Self member changed.

Both use the updater function `setFormData(prev => ...)` for a single state update.

**Risk**: Moderate (touches core state flow). **Verify**: Edit name in Step 1, go to Step 2 -- Self member updated. Edit Self in Step 2, go to Step 1 -- primaryName updated. React DevTools: no infinite loops.

---

### 2.2 Replace useEffect with useMemo in useQuickEntry

**File**: `src/hooks/useQuickEntry.ts` (lines 17-47)

**Problem**: `parsed` and `ghostText` are synchronous derivations of `text`. Using `useEffect + setState` causes double render on every keystroke.

**Fix**: Replace both effects with `useMemo`. Remove `setParsed`/`setGhostText` from state. Update `reset()` to only clear `text`.

```typescript
const parsed = useMemo<T | null>(() => {
  if (!text.trim()) return null
  try { return parseFn(text, familyMembers) } catch { return null }
}, [text, familyMembers, parseFn])

const ghostText = useMemo(() => {
  if (!text) return ''
  try { return getGhostText(text, familyMembers, extraGhostCandidates) } catch { return '' }
}, [text, familyMembers, extraGhostCandidates])
```

**Risk**: Safe. **Verify**: Type in NLP input. Ghost text appears. Parsed preview updates. React DevTools: no double renders.

---

### 2.3 Add Debounce to GoalCard Auto-Save

**File**: `src/components/ips-form/goal/GoalCard.tsx` (lines 137-151)

**Problem**: `onSave()` fires on every keystroke. No debounce.

**Fix**: Wrap in `setTimeout(500ms)` with cleanup return:

```typescript
useEffect(() => {
  if (isInitialMount.current) { isInitialMount.current = false; return }
  if (!isNew && goal && onSave) {
    const timer = setTimeout(() => {
      const updatedGoal = buildGoalFromState()
      if (updatedGoal) onSave(updatedGoal)
    }, 500)
    return () => clearTimeout(timer)
  }
}, [formState]) // eslint-disable-line react-hooks/exhaustive-deps
```

**Risk**: Safe. **Verify**: Edit goal name character by character. `onSave` fires once, 500ms after last keystroke.

---

### 2.4 Add ErrorBoundary to App Root

**File**: `src/main.tsx` (lines 8-16)

**Problem**: `ErrorBoundary` exists (wraps `renderStep()` in `IPSForm.tsx:504`) but NOT the full app tree. Errors in `FormHeader`, `ArrowStepper`, `StepNavigationFooter` crash to white screen.

**Fix**: Wrap entire app in `main.tsx`:

```tsx
<StrictMode>
  <ErrorBoundary>
    <QueryProvider>
      <AuthProvider>
        <App />
      </AuthProvider>
    </QueryProvider>
  </ErrorBoundary>
</StrictMode>
```

Keep existing step-level boundary as granular catch.

**Risk**: Safe. **Verify**: Throw in `FormHeader`. Error boundary UI shows, not white screen.

---

## Phase 3: Performance

### 3.1 Stabilize Callbacks with useCallback

**File**: `src/components/ips-form/IPSForm.tsx` (lines 374-439)

**Problem**: 9 inline `onChange` callbacks recreated every render. Defeats `React.memo`. Closes over stale `formData`.

**Fix**: `useCallback` with updater function pattern:

```typescript
const handleMembersChange = useCallback((members: FamilyMember[]) => {
  setFormData(prev => ({ ...prev, members }))
}, [])
```

Note: After 2.1, the `familyDetails` and `members` callbacks incorporate atomic Self-member sync.

**Depends on**: Phase 2.1. **Risk**: Safe. **Verify**: React DevTools profiler -- step components don't re-render when other steps' data changes.

---

### 3.2 Optimize JSON.stringify Change Detection

**File**: `src/components/ips-form/IPSForm.tsx` (lines 124-177)

**Problem**: `JSON.stringify` on entire arrays runs in every sync effect, every render. Expensive + fragile.

**Fix**: Add referential identity short-circuit before stringify:

```typescript
const prevMembersRef = useRef(formData.members)

useEffect(() => {
  if (!hydrationComplete) return
  if (formData.members === prevMembersRef.current) return  // Fast path
  prevMembersRef.current = formData.members
  const sig = JSON.stringify(formData.members)
  if (sig === prevMembersSig.current) return
  prevMembersSig.current = sig
  if (isOnline() && formData.members.length > 0) syncMembers()
}, [formData.members, hydrationComplete])
```

Apply to all 5 sync effects.

**Risk**: Safe. **Verify**: Stringify not called on every render (add temporary console.log to confirm).

---

### 3.3 Replace O(n^2) Savings Loop with Annuity Formula

**File**: `src/lib/ips-calculations.ts` (lines 221-226)

**Problem**: Inner loop `for k = 0 to year-1` makes projection O(n^2) for 30 years (465 iterations).

**Fix**: Closed-form future value of annuity:

```typescript
const r = weightedRate / 100
const totalSavingsGrown = r > 0
  ? annualNetSavings * (Math.pow(1 + r, year) - 1) / r
  : annualNetSavings * year
```

**Risk**: Safe (same math, different computation). **Verify**: Compare old vs new output for years 1, 10, 30 with known inputs. Must match to 2 decimal places.

---

### 3.4 Memoize FinalizeStep Validation

**File**: `src/components/ips-form/steps/FinalizeStep.tsx` (lines 25-33)

**Fix**: Wrap `validationItems` and `criticalMissing` in `useMemo([data, riskComplete, totalRiskQuestions])`.

**Risk**: Safe. **Verify**: Functional correctness.

---

### 3.5 Pre-Build Ghost Text Static Candidates

**File**: `src/lib/smart-parse.ts` (lines 1137-1183)

**Problem**: 300+ candidate array rebuilt on every keystroke.

**Fix**: Extract static candidates to module-level constant (built once at import). Only add dynamic candidates (member names, extra) per call.

```typescript
const STATIC_GHOST_CANDIDATES: string[] = (() => {
  const c: string[] = []
  ASSET_CLASSES.forEach(ac => c.push(ac.label))
  // ... all static keyword candidates
  return c
})()
```

**Risk**: Safe. **Verify**: Ghost text works for all categories.

---

## Phase 4: Security Hardening

### 4.1 Move CSRF Token to Memory

**File**: `src/lib/api-client.ts` (lines 6, 22-28, 87-93)

**Problem**: CSRF in sessionStorage is readable by XSS.

**Fix**: Module-level variable instead:

```typescript
let csrfToken: string | null = null
export function setCsrfToken(token: string) { csrfToken = token }
export function clearCsrfToken() { csrfToken = null }
```

**Trade-off**: Token lost on refresh. Hydration must handle 403 gracefully (re-auth).

**Risk**: Moderate. **Verify**: Login works. Refresh triggers re-auth flow (not crash). sessionStorage has no CSRF key.

---

### 4.2 Replace Event-Based 401 with Callback

**Files**: `src/lib/api-client.ts` (line 38), `src/providers/AuthProvider.tsx` (lines 12-19)

**Fix**: Callback setter on api-client module. AuthProvider sets it on mount, clears on unmount.

```typescript
// api-client.ts
let onUnauthorized: (() => void) | null = null
export function setUnauthorizedHandler(handler: () => void) { onUnauthorized = handler }

// AuthProvider.tsx
useEffect(() => {
  setUnauthorizedHandler(() => { authService.logout(); setIsAuthenticated(false) })
  return () => setUnauthorizedHandler(() => {})
}, [])
```

**Risk**: Safe. **Verify**: Expire session, make API call. Redirect to login.

---

### 4.3 Gate ReactQueryDevtools Behind DEV

**File**: `src/providers/QueryProvider.tsx` (line 2, 18)

**Fix**: `{import.meta.env.DEV && <ReactQueryDevtools />}`

**Risk**: Safe. **Verify**: `npm run build` -- bundle shrinks ~100KB. Dev: devtools appear. Prod preview: devtools absent.

---

### 4.4 Validate Session on Mount

**Files**: `src/services/auth.service.ts`, `src/providers/AuthProvider.tsx`

**Fix**: On mount, if `isAuthenticated && isOnline()`, ping `/v1/ips-record/` to validate session cookie.

**Depends on**: 4.1 (CSRF must be resolved first). **Risk**: Moderate. **Verify**: Set `ips_authenticated` manually without login. Refresh -- redirect to login.

---

## Phase 5: Architecture & Maintainability

### 5.1 Standardize URL Trailing Slashes

**Files**: `member.service.ts`, `family.service.ts`, `asset.service.ts`, `ips-record.service.ts`, `asset-class.service.ts`, `question.service.ts`

**Problem**: Some URLs have trailing slashes, some don't. Backend requires them (per CLAUDE.md).

**Fix**: Add trailing `/` to all URLs missing them. Alternatively, add Axios interceptor:

```typescript
if (config.url && !config.url.endsWith('/')) config.url += '/'
```

**Risk**: Safe (fixes real 301 redirect issues). **Verify**: Test every API endpoint. No 301s in network tab.

---

### 5.2 Centralize sessionStorage Keys

**Create**: `src/config/storage-keys.ts`
**Update**: `auth.service.ts`, `api-client.ts`, `useBackendSync.ts`, `IPSForm.tsx`

```typescript
export const STORAGE_KEYS = {
  AUTH_SESSION: 'ips_authenticated',
  CSRF_TOKEN: 'ips_csrf_token',
  IPS_SESSION: 'ips_session',
  AUTOSAVE: 'ips_autosave',
} as const
```

**Risk**: Safe. **Verify**: All storage operations still work.

---

### 5.3 Add Environment Validation

**File**: `src/config/env.ts`

**Fix**: Validate `VITE_API_BASE_URL` with Zod (`z.string().url().optional()`). Log error on invalid URL instead of silent fail.

**Risk**: Safe. **Verify**: Set invalid URL in .env. Console shows error. App falls back to offline.

---

### 5.4 Fix Hardcoded Year in Date Parsing

**File**: `src/lib/smart-parse.ts` (lines 844, 856)

**Fix**: Replace `year >= 2024` with `year >= new Date().getFullYear()`.

**Risk**: Safe. **Verify**: Parse "by 2026" -- works. Parse "by 2020" -- rejected (past year).

---

### 5.5 Decompose smart-parse.ts (Large Scope -- Defer to End)

**File**: `src/lib/smart-parse.ts` (1213 lines)

**Fix**: Create `lib/parsing/` with 7 focused modules + barrel `index.ts`:
- `keywords.ts` (lines 11-325)
- `amount.ts` (lines 316-375)
- `member.ts` (lines 377-502)
- `cashflow.ts` (lines 504-645)
- `entry-parsers.ts` (lines 648-790)
- `goal.ts` (lines 792-968)
- `ghost-text.ts` (lines 1051-1205)

Barrel re-export maintains backward compatibility.

**Risk**: Safe (structural only). **Verify**: All existing imports work. `npm run build` passes.

---

## Phase 6: DX & Polish

### 6.1 Surface Sync Errors in UI

**Files**: `src/hooks/useBackendSync.ts`, `src/components/ips-form/form/FormBanners.tsx`

**Fix**: Add `syncErrors: string[]` state to hook. In each catch block, push error message. Auto-clear after 10s. Display as dismissible warning banner.

**Depends on**: Phase 1 (mutex should be in place). **Risk**: Safe.

---

### 6.2 Add Request Cancellation via AbortSignal

**Files**: All 11 service files, `src/lib/api-client.ts`

**Fix**: Accept optional `signal?: AbortSignal` in service methods. Pass through to Axios config. Create AbortController in `useBackendSync`, cancel on unmount.

**Risk**: Safe. **Verify**: Navigate away during API call. No "state update on unmounted component" warnings.

---

## DO NOT TOUCH

These work correctly. Refactoring them adds risk without value:

- `lib/goal-risk-scoring.ts` -- 10-dimension framework, complete and correct
- `lib/risk-scoring.ts` -- Simple average scoring, works as designed
- `types/ips.ts` -- Well-designed discriminated unions
- `types/api.ts` -- Mirrors Swagger schema
- `components/ui/` -- 17 shadcn primitives
- `components/ips-form/dashboard/` -- Chart components
- `components/ips-form/summary/` -- Summary cards
- `hooks/useAutosave.ts` -- Debounced, clean, correct
- `hooks/useBeforeUnload.ts` -- Minimal, correct
- `lib/form-validation.ts` -- Clean validation logic
- `schemas/` -- Thin Zod schemas
- `ArrowStepper.tsx`, `StepHeader.tsx`, `StepNavigationFooter.tsx` -- UI, works fine
- All 9 step components (internal logic) -- Only touch for bugs listed above

---

## Execution Order (Within Each Phase)

| Phase | Order | Rationale |
|-------|-------|-----------|
| **1** | 1.3 > 1.4 > 1.1 > 1.2 | Simplest first, hydration last (most complex) |
| **2** | 2.4 > 2.3 > 2.2 > 2.1 | Trivial first, bidirectional sync last (highest risk) |
| **3** | 3.4 > 3.3 > 3.5 > 3.2 > 3.1 | 3.1 depends on 2.1 |
| **4** | 4.3 > 4.2 > 4.1 > 4.4 | 4.4 depends on 4.1 |
| **5** | 5.1 > 5.4 > 5.2 > 5.3 > 5.5 | Trailing slashes first (fixes real bugs), decompose last (large scope) |
| **6** | 6.1 > 6.2 | Error surface before cancellation |

---

## Verification Strategy

**Per-change**: Each item has a specific verification step listed above.

**Per-phase**: After completing a phase:
1. `npm run build` -- must pass (TypeScript + Vite)
2. `npm run lint` -- no new warnings
3. Manual test: Complete full wizard flow Steps 1-9 (online mode)
4. Manual test: Complete full wizard flow Steps 1-9 (offline mode)
5. Check network tab: No duplicate API calls, no 301 redirects, no orphaned requests

**Regression signals**:
- Phase 1: Duplicate records in UI or backend
- Phase 2: Self member not syncing with primary name, or infinite render loops
- Phase 3: Incorrect financial projections (compare before/after)
- Phase 4: Can't login, refresh requires re-login unexpectedly
- Phase 5: API calls fail (wrong URLs), imports broken
- Phase 6: Error banners not appearing/disappearing correctly

---

## Summary

| Phase | Items | Risk | Key Files |
|-------|-------|------|-----------|
| 1. Data Safety | 4 | Moderate | `useBackendSync.ts`, `api-mappers.ts` |
| 2. React Correctness | 4 | Moderate | `IPSForm.tsx`, `useQuickEntry.ts`, `GoalCard.tsx`, `main.tsx` |
| 3. Performance | 5 | Safe | `IPSForm.tsx`, `ips-calculations.ts`, `smart-parse.ts`, `FinalizeStep.tsx` |
| 4. Security | 4 | Moderate | `api-client.ts`, `AuthProvider.tsx`, `QueryProvider.tsx`, `auth.service.ts` |
| 5. Architecture | 5 | Safe | `services/*.ts`, `smart-parse.ts`, `config/env.ts`, `storage-keys.ts` |
| 6. DX & Polish | 2 | Safe | `useBackendSync.ts`, `services/*.ts`, `FormBanners.tsx` |
| **Total** | **24** | | |
