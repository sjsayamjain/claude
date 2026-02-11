# Plan: Goal-Level Risk Ability Scoring

**Status**: NLP parsing for goals is already implemented. This plan covers the next feature: automatic goal-level risk ability scoring.

**User Request**: Incorporate a 10-question Goal-Level Risk Ability Questionnaire into goals **without** asking users to manually answer all questions.

---

## Problem Statement

Financial planning best practice suggests assessing risk ability at the **goal level**, not just portfolio level. A 10-question framework exists (G1-G10) covering dimensions like time horizon, criticality, flexibility, and funding status.

**Challenge**: The user said "i dont want to ask or give inputs for all of these things" — we need to derive answers automatically from existing goal data.

---

## Design Approach: Auto-Derived Risk Scoring

**Key Insight**: Most questionnaire answers can be inferred from existing goal fields.

### Existing Goal Fields
- `goalType`: education, retirement, home_purchase, emergency_fund, wealth_accumulation, other
- `priority`: essential, important, aspirational
- `targetAmount`: number
- `targetDate` / `retirementDate`: ISO date string
- `beneficiaryId`: family member ID
- `monthsOfExpenses`: for emergency_fund
- `monthlyExpenseBudget`: for retirement

### Auto-Derivation Matrix

| Question | Field | Auto-Derive Logic | Score |
|----------|-------|-------------------|-------|
| G1: Time Horizon | targetDate | years = targetDate - today | <3y: 1, 3-5y: 2, 5-10y: 3, 10-20y: 4, >20y: 5 |
| G2: Goal Criticality | priority | Direct mapping | essential: 1, important: 3, aspirational: 5 |
| G3: Funding Flexibility | goalType | Type-based defaults | education: 2, retirement: 3, home: 4, emergency: 1, wealth: 5 |
| G4: Time Flexibility | goalType | Type-based defaults | education: 1, retirement: 3, home: 4, emergency: 5, wealth: 5 |
| G5: Current Funding % | calculated | beneficiary's assets / targetAmount | 0-20%: 1, 20-40%: 2, 40-60%: 3, 60-80%: 4, >80%: 5 |
| G6: Alt Funding Sources | goalType | Type-based defaults | education: 3, retirement: 2, home: 4, emergency: 1, wealth: 3 |
| G7: Income Stability | family income | Check if any salary income exists | no income: 1, irregular: 2, stable: 4, multiple: 5 |
| G8: Insurance Coverage | goalType | Type-based (retirement/education often insured) | retirement: 3, education: 3, others: 2 |
| G9: Relative Priority | priority + count | priority / total goals ratio | based on rank |
| G10: Emotional Weight | goalType | Type-based defaults | education: 2, retirement: 3, home: 3, emergency: 1, wealth: 4 |

### Composite Score Calculation

```typescript
// Weighted average (higher weight = more impact on ability to take risk)
const WEIGHTS = {
  timeHorizon: 0.20,      // G1 - most important
  criticality: 0.15,      // G2 - higher criticality = lower risk ability
  fundingFlex: 0.10,      // G3
  timeFlex: 0.10,         // G4
  fundedPct: 0.15,        // G5 - more funded = more risk ability
  altSources: 0.05,       // G6
  incomeStability: 0.10,  // G7
  insurance: 0.05,        // G8
  relativePriority: 0.05, // G9
  emotionalWeight: 0.05,  // G10
}

// Score range: 1.0 - 5.0
// 1.0-2.0: Conservative (goal requires low-risk allocation)
// 2.0-3.0: Moderately Conservative
// 3.0-3.5: Moderate
// 3.5-4.0: Moderately Aggressive
// 4.0-5.0: Aggressive (goal can tolerate higher risk)
```

---

## Phase 1: Core Scoring Module

### New File: `src/lib/goal-risk-scoring.ts`

```typescript
import type { Goal, Asset, Income, FamilyMember } from '@/types/ips'

export interface GoalRiskDimension {
  id: string
  label: string
  score: number       // 1-5
  weight: number      // 0-1
  derivedFrom: string // field name or "calculated"
}

export interface GoalRiskProfile {
  goalId: string
  compositeScore: number  // 1.0 - 5.0
  riskCategory: 'conservative' | 'moderately_conservative' | 'moderate' | 'moderately_aggressive' | 'aggressive'
  suggestedEquityRange: string  // e.g., "20-40%"
  dimensions: GoalRiskDimension[]
}

// Main scoring function
export function computeGoalRisk(
  goal: Goal,
  assets: Asset[],
  incomes: Income[],
  allGoals: Goal[],
  members: FamilyMember[]
): GoalRiskProfile

// Helper: Get time horizon in years
export function getGoalTimeHorizon(goal: Goal): number | null

// Helper: Calculate funding percentage
export function getGoalFundingPct(goal: Goal, assets: Asset[]): number

// Helper: Map score to category
export function getGoalRiskCategory(score: number): GoalRiskProfile['riskCategory']
```

---

## Phase 2: Types Extension

### Update `src/types/ips.ts`

Add optional `riskProfile` field to Goal base:

```typescript
interface BaseGoal {
  id: string
  name: string
  goalType: GoalType
  priority: GoalPriority
  beneficiaryId: string
  currency: string
  // NEW: Computed risk profile (not stored, calculated on-the-fly)
  // Note: We don't store this - it's computed from other data
}

// New type for display
export interface GoalRiskSummary {
  score: number
  category: 'conservative' | 'moderately_conservative' | 'moderate' | 'moderately_aggressive' | 'aggressive'
  suggestedEquity: string
}
```

---

## Phase 3: UI Integration

### Goals Table Enhancement

Add a "Risk" column to the goals table showing the computed risk category:

```typescript
// In GoalsAssumptionsStep.tsx EditableTable columns:
{
  key: 'riskScore',
  header: 'Risk Ability',
  type: 'text',
  width: '110px',
  editable: false, // Read-only, auto-computed
  format: (_, row) => {
    const risk = computeGoalRisk(row, assets, incomes, goals, members)
    return risk.riskCategory.replace('_', ' ')
  }
}
```

### Visual Display

Show risk as colored badge:
- Conservative: `bg-blue-100 text-blue-800`
- Moderately Conservative: `bg-cyan-100 text-cyan-800`
- Moderate: `bg-green-100 text-green-800`
- Moderately Aggressive: `bg-amber-100 text-amber-800`
- Aggressive: `bg-red-100 text-red-800`

### Tooltip on Hover

Show dimension breakdown in tooltip:
```
Time Horizon: 3.5 (8 years)
Criticality: 3.0 (Important)
Funding: 2.0 (15% funded)
...
Composite: 2.8 (Moderate)
Suggested Equity: 40-60%
```

---

## Phase 4: Results Dashboard Integration

### Update ResultsDashboardStep.tsx

Add goal risk profile to the Goal Funding Analysis section:

1. Show risk badge next to each goal name
2. Add "Suggested Allocation" column showing equity range
3. Visual indicator if current allocation doesn't match suggested

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/lib/goal-risk-scoring.ts` | NEW - Core scoring logic |
| `src/types/ips.ts` | Add GoalRiskSummary type |
| `src/components/ips-form/steps/GoalsAssumptionsStep.tsx` | Add risk column to table, pass assets/incomes as props |
| `src/components/ips-form/steps/ResultsDashboardStep.tsx` | Show goal risk in funding analysis |
| `src/components/ips-form/IPSForm.tsx` | Pass assets/incomes to GoalsAssumptionsStep |

---

## Props Changes

### GoalsAssumptionsStep needs additional props:

```typescript
interface GoalsAssumptionsStepProps {
  data: GoalsAndAssumptions
  familyMembers: FamilyMember[]
  assets: Asset[]           // NEW - for funding calculation
  incomes: Income[]         // NEW - for income stability
  onChange: (data: GoalsAndAssumptions) => void
}
```

---

## Validation / Testing

1. `npm run build` passes
2. Create goal with various types → verify risk score appears
3. Change priority → verify score updates
4. Change target date → verify time horizon impact
5. Add assets for beneficiary → verify funding % impact
6. Verify tooltip shows breakdown
7. Check Results dashboard shows risk badges

---

## Future Enhancement (Not In Scope)

Optional "Advanced" button to manually override individual dimension scores for edge cases. Not implementing now since:
1. Auto-derivation covers 90%+ of cases
2. User explicitly said no manual inputs
3. Can add later if feedback suggests need
