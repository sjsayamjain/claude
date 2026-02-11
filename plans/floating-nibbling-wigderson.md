# Production Architecture + Backend API Integration Plan

## Context

The IPS Form Builder is transitioning from MVP (client-only, localStorage) to production architecture with real backend API integration. The SmartRich Backend (`localhost:8080/api`) provides CRUD endpoints for families, members, assets, cashflows, assumptions, goals, and risk questions — but with significant data model mismatches from the frontend.

**User decisions**:
- Tailored hybrid architecture (keep `lib/`, `ui/`, `types/` — add infrastructure)
- React Router (login + wizard routes only)
- TanStack Query for server state
- Zod for runtime validation
- Auth: NOT built on backend yet — keep hardcoded creds, plan for JWT
- Backend integer IDs are source of truth — map at API boundary
- Integrate: family, members, assets, cashflows, assumptions, ips-records, goals (basic CRUD)
- Client-only for now: risk profiling answers (no save endpoint), goal risk customization, general assumptions (inflationRate, salaryGrowth — backend only has per-asset-class)

---

## Backend API Summary (SmartRich v1.0)

| Resource | Endpoints | Backend Model |
|----------|-----------|---------------|
| **Family** | `GET/POST /v1/family` | `{ id: int, name: string }` |
| **Family Member** | `GET/POST/PUT/DELETE /v1/family/{family_id}/member` | `{ id: int, name, dob: ISO string, relation: lowercase, related_to: int, family_id, has_relation }` |
| **IPS Record** | `GET/POST/PUT /v1/ips-record` | `{ id: int, code: "IPS0001", family_id, created_by, creation_date, status: draft/archived/active }` |
| **IPS Asset** | `GET/POST/PUT/DELETE /v1/ips-asset` | `{ id: int, name, amount, asset_class_id: int, currency, investor_id: int, ips_id }` |
| **IPS Asset Class** | `GET /v1/ips-assetclass` | `{ id: int, name, description }` — reference data |
| **IPS Cashflow** | `GET/POST/PUT/DELETE /v1/ips-cashflow` | `{ id: int, name, amount, currency, frequency, member_id, ips_id, description, start_date, end_date, flow_direction: income/expense }` |
| **IPS Assumption** | `GET/POST/PUT/DELETE /v1/ips-assumption` | `{ asset_class_id: int, ips_id, yearly_growth_rate }` — per-asset-class only |
| **IPS Goal** | `GET/POST/PUT/DELETE /v1/ips-goal` | `{ id: int, name, amount, currency, description, member_id, ips_id, target_date }` — flat model, no goalType/priority/risk |
| **IPS Question** | `GET /v1/ips-question` | `{ id: int, question, options: string[], question_type }` — read-only |

### Key Data Mismatches

| Frontend | Backend | Mapper Strategy |
|----------|---------|-----------------|
| `FamilyMember.age: number` | `dob: ISO date string` | age → estimated DOB (today - age years); DOB → computed age |
| `FamilyMember.id: string` | `id: integer` | IdMapRegistry: bidirectional string ↔ int maps |
| `FamilyMember.relation: "Spouse"` | `relation: "spouse"` | `.toLowerCase()` / capitalize at boundary |
| `FamilyMember.gender: Gender` | Not in API | Client-only field, preserved in local state |
| `Asset.assetClass: AssetClassName` | `asset_class_id: integer` | Fetch `/v1/ips-assetclass`, build name→id map |
| `Asset.ownerId: string` | `investor_id: integer` | IdMapRegistry lookup |
| `Income/Expense` (separate arrays) | Single `cashflow` with `flow_direction` | Split on GET, merge on POST/PUT |
| `Income.incomeType` | Not in API | Store in `description` field or client-only |
| `Income.duration: string` | `start_date + end_date` | Parse/generate at boundary |
| `Goal` (discriminated union, 7 types) | Flat `{ name, amount, target_date }` | Save basic fields; goalType/priority/risk stay client-only |
| General assumptions (inflation, salary growth) | Not in API (only per-asset-class) | Client-only, localStorage |
| `FamilyDetails.primaryName/primaryAge/surname` | Not in API | Client-only convenience fields |

---

## Target Folder Structure

New files only. Everything existing stays untouched.

```
src/
├── main.tsx                              [MODIFY] — wrap in providers
├── App.tsx                               [MODIFY] — RouterProvider wrapper
│
├── types/
│   └── api.ts                            [NEW] Backend API response/request types
│
├── schemas/                              [NEW]
│   ├── index.ts                          barrel export
│   ├── api.schema.ts                     API response envelope validation
│   ├── family.schema.ts                  Family + FamilyMember API shapes
│   ├── asset.schema.ts                   Asset + AssetClass API shapes
│   ├── cashflow.schema.ts                Cashflow API shapes
│   ├── assumption.schema.ts              Assumption API shapes
│   ├── goal.schema.ts                    Goal API shapes
│   └── ips-record.schema.ts              IPS Record API shapes
│
├── config/
│   └── env.ts                            [NEW] Environment config + offline mode flag
│
├── lib/
│   ├── api-client.ts                     [NEW] Axios instance with interceptors
│   └── api-mappers.ts                    [NEW] Frontend ↔ Backend data converters + IdMapRegistry
│
├── services/                             [NEW]
│   ├── auth.service.ts                   login/logout (mock for now)
│   ├── family.service.ts                 Family CRUD
│   ├── member.service.ts                 FamilyMember CRUD
│   ├── ips-record.service.ts             IPS Record CRUD
│   ├── asset.service.ts                  Asset CRUD
│   ├── asset-class.service.ts            AssetClass reference data
│   ├── cashflow.service.ts               Cashflow CRUD (income + expense)
│   ├── assumption.service.ts             Per-asset-class assumption CRUD
│   └── goal.service.ts                   Goal basic CRUD
│
├── hooks/                                [NEW query hooks]
│   ├── useAuth.ts                        Auth context consumer
│   ├── useFamilies.ts                    Family queries/mutations
│   ├── useMembers.ts                     Member queries/mutations
│   ├── useIPSRecord.ts                   IPS Record queries/mutations
│   ├── useAssets.ts                      Asset queries/mutations
│   ├── useAssetClasses.ts                AssetClass reference query (staleTime: Infinity)
│   ├── useCashflows.ts                   Cashflow queries/mutations (income + expense)
│   ├── useAssumptions.ts                 Assumption queries/mutations
│   └── useGoals.ts                       Goal queries/mutations
│
├── providers/                            [NEW]
│   ├── AuthProvider.tsx                  AuthContext + session management
│   └── QueryProvider.tsx                 TanStack QueryClient config
│
├── layouts/                              [NEW]
│   ├── AuthLayout.tsx                    Centered card layout for login
│   └── AppLayout.tsx                     Authenticated shell (pass-through for now)
│
├── pages/                                [NEW]
│   ├── LoginPage.tsx                     AuthLayout + LoginForm + redirect
│   └── IPSWizardPage.tsx                 IPSForm + useAuth().logout
│
├── routes/                               [NEW]
│   ├── index.tsx                         Route definitions
│   └── ProtectedRoute.tsx                Auth guard with Outlet
│
├── components/
│   └── LoginForm.tsx                     [RENAME from LoginPage.tsx]
```

**Summary**: ~30 new files across 6 new directories. 3 modified files (main.tsx, App.tsx, LoginPage→LoginForm). Zero step components touched initially.

---

## Implementation Phases (app works after each phase)

### Phase 0: Foundation (no behavior change)

**0.1 Install dependencies**
```bash
npm install react-router @tanstack/react-query @tanstack/react-query-devtools axios zod
```

**0.2 Create `src/config/env.ts`**
```typescript
export const ENV = {
  API_BASE_URL: import.meta.env.VITE_API_BASE_URL as string | undefined,
  IS_OFFLINE: !import.meta.env.VITE_API_BASE_URL,
}
```
When `VITE_API_BASE_URL` is absent → fully offline mode → current behavior preserved.

**0.3 Create `src/types/api.ts`** — Backend API types (mirrors Swagger models exactly)

Key types:
- `ApiFamily` → `{ id: number, name: string }`
- `ApiFamilyMember` → `{ id: number, name: string, dob: string, relation: string, related_to: number, family_id: number, has_relation: boolean }`
- `ApiIpsRecord` → `{ id: number, code: string, family_id: number, created_by: number, creation_date: string, status: string }`
- `ApiIpsAsset` → `{ id: number, name: string, amount: number, asset_class_id: number, currency: string, investor_id: number, ips_id: number }`
- `ApiIpsAssetClass` → `{ id: number, name: string, description: string }`
- `ApiIpsCashflow` → `{ id: number, name: string, amount: number, currency: string, frequency: string, member_id: number, ips_id: number, description: string, start_date: string, end_date: string }`
- `ApiIpsAssumption` → `{ asset_class_id: number, ips_id: number, yearly_growth_rate: number }`
- `ApiIpsGoal` → `{ id: number, name: string, amount: number, currency: string, description: string, member_id: number, ips_id: number, target_date: string }`
- `ApiListResponse<T>` → `{ count: number, [key]: T[] }`
- `ApiError` → `{ message: string, status: number }`

**0.4 Create `src/schemas/`** — Zod schemas for API response validation

One schema file per resource, validating backend response shapes. Used in services to validate API responses before mapping. Barrel export via `index.ts`.

**0.5 Create `src/lib/api-client.ts`** — Axios instance

```typescript
// Creates axios instance with:
// - baseURL from ENV.API_BASE_URL
// - Request interceptor: inject Authorization header (when JWT exists)
// - Response interceptor: 401 → dispatch 'auth:unauthorized' event
// - Typed get/post/put/delete helpers
// - ApiError normalization
```

**0.6 Create `src/lib/api-mappers.ts`** — Data transformation layer

This is the critical file bridging frontend ↔ backend models.

**IdMapRegistry** (singleton):
```typescript
class IdMapRegistry {
  // Per-entity bidirectional maps: string ↔ number
  private maps: Map<string, { toBackend: Map<string, number>, toFrontend: Map<number, string> }>

  register(entity: string, frontendId: string, backendId: number): void
  toBackendId(entity: string, frontendId: string): number | undefined
  toFrontendId(entity: string, backendId: number): string
  generateTempId(): string  // For new records not yet saved
}
```

**AssetClassMapper**:
- Fetches `/v1/ips-assetclass` once, builds `name→id` and `id→AssetClassName` maps
- Maps backend `asset_class_id: 1` ↔ frontend `assetClass: "equity"`

**Entity mappers** (pure functions):
- `toApiFamilyMember(member: FamilyMember): CreateFamilyMemberInput` — age→DOB, capitalize→lowercase relation
- `fromApiFamilyMember(api: ApiFamilyMember): FamilyMember` — DOB→age, lowercase→capitalize relation, register ID
- `toApiAsset(asset: Asset, ipsId: number): CreateIpsAssetInput` — assetClass→asset_class_id, ownerId→investor_id
- `fromApiAsset(api: ApiIpsAsset): Asset` — reverse mappings
- `toApiCashflow(item: Income|Expense, ipsId: number, direction: 'income'|'expense'): CreateIpsCashflowInput` — duration→dates, memberId→int
- `fromApiCashflow(api: ApiIpsCashflow, direction: 'income'|'expense'): Income|Expense` — split by direction
- `toApiGoal(goal: Goal, ipsId: number): CreateIpsGoalInput` — flatten discriminated union to flat model
- `fromApiGoal(api: ApiIpsGoal): Partial<Goal>` — only basic fields, goalType/priority/risk from client store
- `toApiAssumption(assumption: AssetClassAssumption, ipsId: number): ApiIpsAssumption`
- `fromApiAssumption(api: ApiIpsAssumption): AssetClassAssumption`

**0.7 Create `src/providers/QueryProvider.tsx`**
```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 5 * 60 * 1000, retry: 1, refetchOnWindowFocus: false },
  },
})
```

---

### Phase 1: Auth + Routing (replaces manual auth gate)

**1.1 Create `src/services/auth.service.ts`**
- Mock mode (no API): validates hardcoded creds + sessionStorage (replicating `LoginPage.tsx:37-43`)
- Real mode: placeholder for `POST /api/auth/login` (when backend adds it)

**1.2 Create `src/providers/AuthProvider.tsx`**
- `AuthContext` with `{ isAuthenticated, isLoading, login, logout }`
- On mount: checks `sessionStorage('ips_authenticated')`
- `login()`: delegates to `auth.service`, sets session
- `logout()`: clears session, navigates to `/login`
- `isLoading` prevents login page flash on refresh

**1.3 Create `src/hooks/useAuth.ts`**
- Context consumer with helpful error if used outside provider

**1.4 Create `src/layouts/AuthLayout.tsx`**
- Extract outer wrapper from `LoginPage.tsx:48` (`min-h-screen flex items-center justify-center bg-muted/40`)

**1.5 Create `src/layouts/AppLayout.tsx`**
- Pass-through `<Outlet />` — placeholder for future sidebar/nav

**1.6 Rename `src/components/LoginPage.tsx` → `src/components/LoginForm.tsx`**
- Remove outer layout div (moves to AuthLayout)
- Replace `onLogin` prop with `useAuth().login()` + `useNavigate()`
- Remove direct `sessionStorage.setItem` (auth service handles it)
- Keep all form UI, validation, show/hide password exactly as-is

**1.7 Create `src/pages/LoginPage.tsx`** (page)
- Wraps LoginForm in AuthLayout
- Redirects to `/` if already authenticated

**1.8 Create `src/pages/IPSWizardPage.tsx`** (page)
- Renders `<IPSForm onLogout={logout} />` where `logout` from `useAuth()`

**1.9 Create `src/routes/ProtectedRoute.tsx`**
- `useAuth()` → loading spinner / Navigate to /login / `<Outlet />`

**1.10 Create `src/routes/index.tsx`**
```
/login  → LoginPage (public)
/       → ProtectedRoute → AppLayout → IPSWizardPage
*       → Navigate to /login
```

**1.11 Update `src/App.tsx`**
- Replace auth gate with `<RouterProvider router={router} />`

**1.12 Update `src/main.tsx`**
```tsx
<StrictMode>
  <QueryProvider>
    <AuthProvider>
      <App />
    </AuthProvider>
  </QueryProvider>
</StrictMode>
```

**Verify**: Login/logout flow works identically. URL routing works. Session persists on refresh.

---

### Phase 2: Service Layer (no UI changes yet)

Create all service files. Each service has the pattern:
```typescript
export const familyService = {
  list: async (): Promise<ApiFamily[]> => { ... },
  create: async (input: CreateFamilyInput): Promise<FamilyCreateResult> => { ... },
  // etc.
}
```

In offline mode, services return empty arrays / throw "offline" errors (existing localStorage behavior handles data).

**2.1** `src/services/family.service.ts` — `GET/POST /v1/family`
**2.2** `src/services/member.service.ts` — `GET/POST/PUT/DELETE /v1/family/{id}/member`
**2.3** `src/services/ips-record.service.ts` — `GET/POST/PUT /v1/ips-record`
**2.4** `src/services/asset-class.service.ts` — `GET /v1/ips-assetclass` (reference data)
**2.5** `src/services/asset.service.ts` — `GET/POST/PUT/DELETE /v1/ips-asset`
**2.6** `src/services/cashflow.service.ts` — `GET/POST/PUT/DELETE /v1/ips-cashflow/{flow_dir}`
**2.7** `src/services/assumption.service.ts` — `GET/POST/PUT/DELETE /v1/ips-assumption`
**2.8** `src/services/goal.service.ts` — `GET/POST/PUT/DELETE /v1/ips-goal`

---

### Phase 3: TanStack Query Hooks (no UI changes yet)

Create query hooks wrapping services with proper cache keys, optimistic updates, and invalidation.

**3.1** `src/hooks/useAssetClasses.ts` — `staleTime: Infinity` (reference data fetched once)
**3.2** `src/hooks/useFamilies.ts` — list + create mutation
**3.3** `src/hooks/useMembers.ts` — list by familyId + CRUD mutations
**3.4** `src/hooks/useIPSRecord.ts` — list + create + update mutations
**3.5** `src/hooks/useAssets.ts` — list by ipsId + CRUD mutations with optimistic updates
**3.6** `src/hooks/useCashflows.ts` — list by ipsId+direction + CRUD mutations
**3.7** `src/hooks/useAssumptions.ts` — list by ipsId + upsert mutation
**3.8** `src/hooks/useGoals.ts` — list by ipsId + CRUD mutations

**Query key convention**: `['entity', parentId?]` e.g. `['members', familyId]`, `['assets', ipsId]`

**Verify**: Hooks exist, compile, but nothing calls them yet. `npm run build` passes.

---

### Phase 4: Integration — Connect Steps to Backend

This is where the actual data flow changes. Each sub-step modifies step components to use query hooks alongside existing local state.

**Strategy**: "Hydrate on mount, sync on change". When online:
1. Fetch server data on mount → map to frontend types → set as local state
2. On user changes → update local state (instant UI) → fire mutation (async)
3. On mutation success → invalidate query cache
4. On mutation error → show toast, optionally revert

When offline: skip fetching, use localStorage (existing useAutosave behavior).

**4.1 Add `familyId` + `ipsId` state to IPSForm.tsx**

Add two new state variables alongside existing `formData`:
```typescript
const [familyId, setFamilyId] = useState<number | null>(null)
const [ipsId, setIpsId] = useState<number | null>(null)
```

On Step 1 completion (going forward from step 1):
- If online AND familyId is null → create family via mutation → store returned `family_id`
- Then create IPS record → store returned `id` as `ipsId`

**4.2 Step 2 (Family Members) — Wire to `useMembers`**

After auto-creating primary member (IPSForm.tsx:86-100):
- If online → fire `createMember` mutation with mapped data
- On member add/edit/delete in FamilyMembersStep → fire corresponding mutation
- Register returned backend IDs in IdMapRegistry

**4.3 Step 3 (Assets) — Wire to `useAssets` + `useAssetClasses`**

- Fetch asset classes on app boot (useAssetClasses in QueryProvider or root)
- On asset add → `createAsset` mutation (needs `ipsId`, `asset_class_id` from mapper, `investor_id` from IdMapRegistry)
- On asset edit → `updateAsset` mutation
- On asset delete → `deleteAsset` mutation

**4.4 Step 4 (Cash Flow) — Wire to `useCashflows`**

- Income entries → `POST /v1/ips-cashflow/income/` with mapped data
- Expense entries → `POST /v1/ips-cashflow/expense/` with mapped data
- Frontend `incomeType` stored in `description` field (backend has no incomeType)
- Frontend `duration` → `start_date` (today) + `end_date` (today + parsed duration)

**4.5 Step 5 (Goals) — Wire to `useGoals`** (basic CRUD only)

- Save flat goal data (name, amount, currency, target_date, member_id) to backend
- GoalType, priority, manualRiskAnswers stay client-only (localStorage via autosave)
- On load: merge server goals (basic) with client-stored enrichments

**4.6 Step 6 (Assumptions) — Wire to `useAssumptions`** (per-asset-class only)

- Per-asset-class growth rates → sync with backend
- General assumptions (inflationRate, exchangeRateDepreciation, salaryGrowthRate) → client-only

**4.7 Step 7 (Risk Profiling) — Client-only**

No backend endpoint for saving risk answers. Continue using localStorage autosave.

**4.8 Update IPSForm.tsx save handler**

Replace `localStorage.setItem` with mutation calls when online. Keep localStorage as fallback/offline cache.

---

### Phase 5: Polish + Error Handling

**5.1** Add error toasts/banners for failed mutations
**5.2** Add loading states for initial data fetches
**5.3** Add retry logic on network failures
**5.4** Add ReactQueryDevtools in development mode
**5.5** Update `useAutosave` to skip when online (server is source of truth)
**5.6** Test offline ↔ online transitions

---

## Files Modified (exact locations)

| File | Change |
|------|--------|
| `src/main.tsx` (L1-10) | Wrap App in QueryProvider + AuthProvider |
| `src/App.tsx` (L1-20) | Replace auth gate with RouterProvider |
| `src/components/LoginPage.tsx` | Rename → LoginForm.tsx, remove layout div (L48), use useAuth() |
| `src/components/ips-form/IPSForm.tsx` (L26-41) | Add familyId/ipsId state, wire mutations on step transitions |
| `src/components/ips-form/IPSForm.tsx` (L86-100) | After auto-create member, fire createMember mutation |
| `src/components/ips-form/IPSForm.tsx` (L114-122) | Replace localStorage save with mutation calls |

Step components (`FamilyMembersStep`, `CurrentAssetsStep`, `IncomeCashFlowStep`, `GoalsAssumptionsStep`, `AssumptionsStep`) may need optional callback props for mutation triggers, OR mutations are handled entirely in IPSForm.tsx via onChange callbacks (preferred — keeps steps pure).

---

## Key Design Decisions

1. **`types/ips.ts` stays untouched** — new `types/api.ts` has backend shapes, mappers bridge them
2. **Offline mode via env var** — `VITE_API_BASE_URL` absent = full offline = current behavior preserved
3. **IdMapRegistry singleton** — bidirectional string↔int ID maps per entity, populated on fetch
4. **Step components stay pure** — mutations handled in IPSForm.tsx via onChange callbacks, steps don't know about API
5. **Hybrid state** — server-synced data (family, members, assets, cashflows) + client-only data (goals enrichments, risk, general assumptions) merged in IPSForm local state
6. **Asset class mapping** — fetch reference data once from `/v1/ips-assetclass`, cache forever, build name↔id maps
7. **Cashflow direction** — frontend Income/Expense arrays merged into single API with `flow_direction` discriminator
8. **Goals partially synced** — basic fields (name, amount, date) to server; goalType, priority, risk customization client-only until backend supports them
9. **Auth mock mode** — exact same hardcoded credential check + sessionStorage pattern, ready for JWT swap

---

## Verification

After each phase:

**Phase 0**: `npm run build` — zero errors, no behavior change
**Phase 1**: Login → redirect to `/`. Logout → redirect to `/login`. Refresh preserves session. Direct URL guard works.
**Phase 2-3**: `npm run build` — services and hooks compile, nothing calls them yet
**Phase 4**: Set `VITE_API_BASE_URL=http://localhost:8080/api` in `.env.local`:
1. Login → create family → create IPS record → IDs stored
2. Add members → appear in backend (`GET /v1/family/{id}/member`)
3. Add assets → appear in backend (`GET /v1/ips-asset/{ips_id}`)
4. Add income/expenses → appear in backend (`GET /v1/ips-cashflow/{dir}/{ips_id}`)
5. Set assumptions → appear in backend (`GET /v1/ips-assumption/{ips_id}`)
6. Remove `.env.local` → app works fully offline with localStorage

**Phase 5**: Error toasts on network failure, loading spinners, devtools in dev mode
