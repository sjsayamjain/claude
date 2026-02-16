# IPS Wizard Refactoring Plan

> Goal: Keep ALL features and behavior identical. Improve how the code is written.

## Execution Phases

### Phase 1: Independent Leaf Fixes (parallel, no cross-deps)

| Step | File                              | Change                                                                                                               | Risk |
| ---- | --------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ---- |
| 1a   | `src/config/env.ts`               | Merge duplicate URL validation into single `validateUrl()` function                                                  | Low  |
| 1b   | `src/lib/api-client.ts`           | Gate `ngrok-skip-browser-warning` header behind `import.meta.env.DEV`                                                | Low  |
| 1c   | `src/lib/parsing/cashflow.ts:70`  | Remove dead ternary (both branches identical)                                                                        | None |
| 1d   | `src/lib/parsing/goal.ts:235-242` | Remove broken span-based date removal (regex cleanup at lines 243-256 already handles it)                            | Low  |
| 1e   | `src/lib/ips-calculations.ts:82`  | Remove unused `_totalMonthlyExpenses` param from `getGoalAmount`, update 1 call site at line 274                     | None |
| 1f   | `src/lib/ips-calculations.ts`     | Extract constants: `DEFAULT_PORTFOLIO_GROWTH_RATE = 8` (line 194), `GOAL_SURPLUS_THRESHOLD_PERCENT = 120` (line 286) | None |

### Phase 2: api-mappers.ts Fixes (before Phase 3)

| Step | File                          | Change                                                                                                                                                                                                                                                                                                                    | Risk   |
| ---- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 2a   | `src/lib/api-mappers.ts`      | `assetClassToBackendId` and `assetClassIdToFrontend` return `undefined` on miss (not silent `1`/`'equity'`). Update 6 call sites: `toApiAsset`, `toApiUpdateAsset`, `toApiAssumption` throw on miss; `fromApiAsset`, `fromApiAssumption` default to `'equity'` at hydration level; `syncAssumptions` delete skips on miss | Medium |
| 2b   | `src/lib/api-mappers.ts`      | Extract `parseDurationYears()` helper for `toApiCashflow`/`toApiUpdateCashflow` — handles `""`, `"0"`, `"abc"`, `undefined` safely (all default to 30yr)                                                                                                                                                                  | Low    |
| 2c   | `src/lib/api-mappers.ts`      | Add doc comment on `fromApiCashflowToIncome` explaining `incomeType: 'salary'` data loss limitation                                                                                                                                                                                                                       | None   |
| 2d   | `src/hooks/useBackendSync.ts` | Add doc comment on `syncAssumptions` create-then-update fallback explaining backend lacks upsert                                                                                                                                                                                                                          | None   |

### Phase 3: Extract `syncEntities` Generic (~300 lines deduped)

**File**: `src/hooks/useBackendSync.ts`

Extract a generic `syncEntities<T extends { id: string }>()` function with this interface:

```ts
interface SyncEntityOptions<T extends { id: string }> {
  current: T[];
  serverMap: Map<string, string>;
  sigFn: (item: T) => string;
  entityName: string;
  idEntity: string;
  create: (item: T) => Promise<{ id: number }>;
  update: (item: T) => Promise<void>;
  deleteItem: (backendId: number) => Promise<void>;
  canSync?: (item: T) => boolean;
  onError: (msg: string) => void;
}
```

Refactor 5 sync functions to use it:

- `syncMembers` → `syncEntities<FamilyMember>({...})`
- `syncAssets` → `syncEntities<Asset>({...})`
- `syncCashflows` → Two calls: `syncEntities<Income>({...})` then `syncEntities<Expense>({...})`
- `syncGoals` → `syncEntities<Goal>({...})`

**Keep as-is**: `syncAssumptions` (keyed by class name, optimistic writes, create-then-update) and `syncRiskAssessment` (signature-based, not per-item).

Risk: **High** — touches all sync paths. Requires careful testing.

### Phase 4: IPSForm.tsx Cleanup

| Step | File                                       | Change                                                                                                                                                                                            | Risk     |
| ---- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 4a   | `src/hooks/useSyncEffect.ts` **(NEW)**     | Custom hook encapsulating the two-tier change detection pattern (referential identity check → JSON signature comparison → sync call). Returns `{ setSignature }` for hydration/reset.             | Medium   |
| 4b   | `src/components/ips-form/IPSForm.tsx`      | Replace 5 duplicate sync effects (lines 171-235) + 10 refs (lines 92-102) with 5 `useSyncEffect()` calls. Update `handleRestore`/`handleDiscardSaved`/`handleStartFresh` to use `setSignature()`. | **High** |
| 4c   | `src/components/ips-form/IPSForm.tsx`      | Wrap `validation` (line 519) and `completedSteps` (line 531) in `useMemo`                                                                                                                         | Low      |
| 4d   | `src/components/ips-form/IPSForm.tsx`      | Extract `createFreshFormData()` helper (used at lines 41, 308, 409)                                                                                                                               | None     |
| 4e   | `src/components/ips-form/IPSForm.tsx`      | Add comment explaining `setTimeout(() => resetBaseline(), 0)` — keep behavior as-is                                                                                                               | None     |
| 4f   | `src/hooks/useAutosave.ts` + `IPSForm.tsx` | Expose `saveNow()` from `useAutosave` (uses formData ref to avoid stale closure). Replace direct `localStorage.setItem` in `handleSave` with `saveNow()`                                          | Low      |

### Phase 5: GoalCard Auto-Save Fix

**File**: `src/components/ips-form/goal/GoalCard.tsx`

- Wrap `buildGoalFromState` in `useCallback([formState, goal?.id])`
- Add proper deps to auto-save effect: `[formState, isNew, goal, onSave, buildGoalFromState]`
- Remove `eslint-disable-next-line` comment

Risk: Medium — changes effect firing behavior but all deps are stable for a given GoalCard instance.

---

## Files Modified (10) + 1 New

| File                                        | Lines Changed (est.) | Phase |
| ------------------------------------------- | -------------------- | ----- |
| `src/config/env.ts`                         | ~10                  | 1     |
| `src/lib/api-client.ts`                     | ~2                   | 1     |
| `src/lib/parsing/cashflow.ts`               | ~1                   | 1     |
| `src/lib/parsing/goal.ts`                   | ~8                   | 1     |
| `src/lib/ips-calculations.ts`               | ~10                  | 1     |
| `src/lib/api-mappers.ts`                    | ~40                  | 2     |
| `src/hooks/useBackendSync.ts`               | ~250 (net -160)      | 2, 3  |
| `src/hooks/useSyncEffect.ts`                | ~40 (NEW)            | 4     |
| `src/hooks/useAutosave.ts`                  | ~15                  | 4     |
| `src/components/ips-form/IPSForm.tsx`       | ~80 (net -40)        | 4     |
| `src/components/ips-form/goal/GoalCard.tsx` | ~10                  | 5     |

**Net reduction**: ~200 lines removed across the codebase.

---

## Verification

After all changes:

1. **Build**: `npm run build` — zero errors
2. **Lint**: `npm run lint` — no new violations
3. **Smoke test each wizard step**:
   - Step 1→2: Session created on backend
   - Steps 2-4: Add/edit/delete members, assets, cashflows — real-time sync works
   - Steps 5-6: Goals and assumptions sync on step navigation
   - Step 7: Risk questions sync on step leave
   - Steps 8-9: Summary cards and dashboard render correctly
4. **Hydration**: Refresh mid-wizard → restore banner → data restores correctly
5. **Offline**: Remove `VITE_API_BASE_URL` → wizard works with localStorage only
6. **Error handling**: Stop backend → make changes → sync error banner appears and auto-clears after 10s
7. **Start Fresh**: Click start fresh → form resets, no stale sync to backend
