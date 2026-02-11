# Plan: Step Validation & Navigation Blocking

## Summary

Add proper validation handling across the 9-step IPS Form wizard to:
1. **Block navigation** when prerequisites aren't met (hard blocks)
2. **Show inline warnings** when recommended data is missing (soft warnings)
3. Use existing yellow/amber banner pattern - **no toasts**

---

## Validation Philosophy

### Hard Blocks (Disable Next Button)
Only block when data is **technically required** for next step to function:

| Transition | Condition | Message |
|------------|-----------|---------|
| Step 1→2 | Need `familyName` OR `primaryName` | "Enter a family name or primary person's name" |
| Step 2→3 | Need `members.length > 0` | "Add at least one family member" |
| Step 8→9 | Need members + (assets OR income) + risk profile complete | "Complete required sections: [list missing]" |

### Soft Warnings (Allow but Warn)
Guide users without blocking:

| Step | Condition | Warning |
|------|-----------|---------|
| 3+ | No family members | "Add family members" (existing) |
| 4 | No assets | "Consider adding assets for portfolio analysis" |
| 5 | No income/expenses | "Add income sources for accurate projections" |
| 6 | No goals | "Define goals to guide your investment strategy" |
| 7 | No assets | "Add assets to set per-class growth assumptions" |
| 8 | Incomplete risk profile | "Complete risk profiling for personalized recommendations" |

---

## Implementation

### Phase 1: Create Validation Module

**New file: `src/lib/form-validation.ts`**

```typescript
export interface StepValidation {
  canProceed: boolean      // false = block Next button
  message: string | null   // banner message
  severity: 'error' | 'warning' | 'info' | null
  missingItems?: string[]  // for Step 8→9 listing
}

export function validateStepTransition(
  fromStep: number,
  data: IPSFormData
): StepValidation
```

---

### Phase 2: Enhance Banner System in IPSForm.tsx

**Current**: Single amber warning banner

**Enhanced**: Support severity variants with different colors:

| Severity | Background | Border | Text | Icon |
|----------|------------|--------|------|------|
| Error | `bg-red-50` | `border-red-200` | `text-red-800` | `XCircle` |
| Warning | `bg-amber-50` | `border-amber-200` | `text-amber-700` | `AlertTriangle` |
| Info | `bg-blue-50` | `border-blue-200` | `text-blue-700` | `Info` |

---

### Phase 3: Disable Next Button

In `IPSForm.tsx`:

```typescript
const validation = validateStepTransition(currentStep, formData)

// Next button
<Button
  onClick={nextStep}
  disabled={!validation.canProceed}
  className="gap-2"
>
```

Add Tooltip wrapper for disabled state showing the validation message.

---

### Phase 4: Enhance FinalizeStep (Step 8)

When hard block conditions fail for Step 8→9:

1. Show **red error card** at top of validation checklist
2. List exactly what's missing with "Go to Step X" buttons
3. Make validation items clickable to jump to relevant step

Example message:
```
Complete the following to view results:
• Add at least one family member → Go to Step 2
• Complete risk profiling (7/10 answered) → Go to Step 7
```

---

### Phase 5: Add onNavigateToStep to ResultsDashboardStep

Pass the `onNavigateToStep` callback to Results so empty sections can have CTAs:
- "No assets to display - Add Assets in Step 3 →"

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/lib/form-validation.ts` | **NEW** - Validation logic module |
| `src/components/ips-form/IPSForm.tsx` | Replace `getStepWarning()`, add validation, disable Next button, enhance banners |
| `src/components/ips-form/steps/FinalizeStep.tsx` | Add error card when blocked, improve validation item CTAs |
| `src/components/ips-form/steps/ResultsDashboardStep.tsx` | Add `onNavigateToStep` prop, empty state CTAs |

---

## Edge Cases

1. **Backward navigation**: Always allow - no validation on Previous
2. **ArrowStepper clicks**: Allow, but show warning banner if prerequisites missing
3. **Data deletion**: If user deletes data making step invalid, show banner immediately
4. **Autosave restore**: Validate current step on restore, show warning if needed

---

## Test Cases

1. Empty Step 1 → Next disabled, tooltip shows message
2. Empty Step 2 → Next disabled until member added
3. Skip to Step 8 with empty form → See red error card listing missing items
4. Step 8 with incomplete data → Next (to Results) disabled
5. Complete all requirements → Next enabled, green "Ready to save" card

---

## What This Does NOT Do

- No toasts (per user request)
- No blocking ArrowStepper clicks (respect user intent to jump around)
- No real-time validation as user types (only on Next click)
- No blocking backward navigation
