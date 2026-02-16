# Plan: Goals Step Enhancements (Validation, Member Chips, Persistence)

## Overview

Implement 3 enhancements to Step 5 (Goals):

1. **Block Next button** if any goal has incomplete risk questions
2. **Add member suggestion chips** to SmartGoalInput (like SmartAssetInput lines 148-167)
3. **Fix goal risk answer persistence** across page refresh/restore

## Context

- Goal risk questions are **dynamic from API** (not hardcoded to 7) via `useGoalRiskQuestions()`
- Questions cached in localStorage under `STORAGE_KEYS.CACHED_GOAL_RISK_QUESTIONS`
- CompactGoalRow already shows "X/Y risk Q's" badge dynamically
- Currently NO validation at Step 5→6 transition
- `preserveClientOnlyFields` in IPSForm.tsx doesn't restore `manualRiskAnswers`
- Member chips pattern exists in SmartAssetInput (lines 148-167) but NOT in SmartGoalInput

---

## Task 1: Block Next Button for Incomplete Goal Risk Questions

### Files to Modify

**`src/lib/form-validation.ts`**

Add new validation function:

```typescript
export function validateGoalRiskQuestions(
  goals: Goal[],
  totalQuestions: number
): { isValid: boolean; message?: string } {
  if (goals.length === 0) {
    return { isValid: true }; // No goals = no validation needed
  }

  const incompleteGoals = goals.filter((goal) => {
    const answeredCount = goal.manualRiskAnswers
      ? Object.keys(goal.manualRiskAnswers).filter(
          (key) => goal.manualRiskAnswers![key as keyof typeof goal.manualRiskAnswers] !== undefined
        ).length
      : 0;
    return answeredCount < totalQuestions;
  });

  if (incompleteGoals.length > 0) {
    const goalNames = incompleteGoals.map((g) => g.name).join(", ");
    return {
      isValid: false,
      message: `Complete risk questions for: ${goalNames}`,
    };
  }

  return { isValid: true };
}
```

Update `validateStepTransition` case for step 5→6:

```typescript
case 5: {
  // Existing goals validation...

  // NEW: Goal risk questions validation
  const { isValid, message } = validateGoalRiskQuestions(
    formData.goalsAndAssumptions.goals,
    totalGoalRiskQuestions // Pass from IPSForm
  );
  if (!isValid) {
    return { allowed: false, message: message || "Complete all goal risk questions" };
  }

  return { allowed: true };
}
```

**`src/components/ips-form/IPSForm.tsx`**

Pass `totalGoalRiskQuestions` to validation:

```typescript
// In IPSForm component, after useGoalRiskQuestions hook:
const { data: goalRiskQuestions = [] } = useGoalRiskQuestions();
const totalGoalRiskQuestions = goalRiskQuestions.length;

// In goToStep function:
const validation = validateStepTransition(
  currentStep,
  formData,
  totalGoalRiskQuestions // NEW parameter
);
```

Update `validateStepTransition` signature in form-validation.ts:

```typescript
export function validateStepTransition(
  fromStep: number,
  formData: IPSFormData,
  totalGoalRiskQuestions: number = 0 // NEW parameter with default
): ValidationResult
```

**`src/components/ips-form/steps/FinalizeStep.tsx`**

Update ValidationChecklist to show goal risk completion:

```typescript
// Add after existing goal validation item:
{
  id: 'goal-risk',
  label: 'All goal risk questions answered',
  completed: formData.goalsAndAssumptions.goals.length > 0 &&
    formData.goalsAndAssumptions.goals.every((goal) => {
      const answeredCount = goal.manualRiskAnswers
        ? Object.keys(goal.manualRiskAnswers).filter(
            (key) => goal.manualRiskAnswers![key as keyof typeof goal.manualRiskAnswers] !== undefined
          ).length
        : 0;
      return answeredCount === totalGoalRiskQuestions;
    }),
  action: () => onNavigate(5),
}
```

---

## Task 2: Add Member Suggestion Chips to SmartGoalInput

### Pattern Reference

From `SmartAssetInput.tsx:148-167`:

```typescript
{members.length > 0 && (
  <div className="flex flex-wrap gap-2">
    <span className="text-xs text-muted-foreground">Suggestions:</span>
    {members.map((member) => (
      <button
        key={member.id}
        type="button"
        onClick={() => handleMemberChipClick(member.name)}
        className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-md bg-muted hover:bg-muted/80 transition-colors"
      >
        <User className="h-3 w-3" />
        {member.name}
      </button>
    ))}
  </div>
)}
```

### File to Modify

**`src/components/ips-form/goal/SmartGoalInput.tsx`**

Add member chips section after the GhostTextInput:

```typescript
// Add import at top:
import { User } from "lucide-react";

// Add handler function:
const handleMemberChipClick = (memberName: string) => {
  // Append member name to current input with space
  const newValue = inputValue.trim()
    ? `${inputValue.trim()} by ${memberName}`
    : `by ${memberName}`;
  setInputValue(newValue);
  // Trigger parsing
  handleInputChange({ target: { value: newValue } } as React.ChangeEvent<HTMLInputElement>);
};

// Add chips UI before the "Structured Entry" button:
{members.length > 0 && (
  <div className="flex flex-wrap gap-2 px-1">
    <span className="text-xs text-muted-foreground">Suggestions:</span>
    {members.map((member) => (
      <button
        key={member.id}
        type="button"
        onClick={() => handleMemberChipClick(member.name)}
        className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-md bg-muted hover:bg-muted/80 transition-colors"
      >
        <User className="h-3 w-3" />
        {member.name}
      </button>
    ))}
  </div>
)}
```

---

## Task 3: Fix Goal Risk Answer Persistence

### Root Cause

`preserveClientOnlyFields` in `IPSForm.tsx` (lines 241-280) merges server data with localStorage but does NOT restore `manualRiskAnswers` from localStorage goals.

### File to Modify

**`src/components/ips-form/IPSForm.tsx`**

Update `preserveClientOnlyFields` function around line 260:

```typescript
// In the goals merge section:
const mergedGoals = backendGoals.map((backendGoal) => {
  const localGoal = localGoals.find(
    (lg) => lg.name === backendGoal.name && lg.beneficiaryId === backendGoal.beneficiaryId
  );

  return {
    ...backendGoal,
    // Existing fields...
    goalType: localGoal?.goalType ?? inferGoalTypeFromName(backendGoal.name),
    priority: localGoal?.priority ?? inferPriorityFromName(backendGoal.name),

    // NEW: Restore goal risk answers from localStorage
    manualRiskAnswers: localGoal?.manualRiskAnswers ?? undefined,
  };
});
```

### Additional Fix: Ensure localStorage is Updated

Verify `useAutosave` hook saves goals with `manualRiskAnswers`:

**`src/hooks/useAutosave.ts`**

Check that the autosave includes full goal objects (no filtering of `manualRiskAnswers`). Current implementation should already handle this since it serializes entire `formData`, but verify no explicit field exclusions exist.

---

## Execution Order

1. **Task 3 first** (persistence) — ensures existing goal risk answers are preserved
2. **Task 2** (member chips) — UX improvement for quick entry
3. **Task 1** (validation) — enforces completion before Next

Reason: Fix data loss before adding validation that depends on that data existing.

---

## Testing Checklist

After implementation:

1. **Task 3 (Persistence)**:
   - Open Step 5, expand goal, answer 2 of 4 risk questions
   - Refresh page → restore from server
   - Verify: Goal risk answers are still selected (not lost)

2. **Task 2 (Member Chips)**:
   - On Step 5, type in SmartGoalInput
   - Verify: Member name chips appear below input
   - Click "Sayam Jain" chip
   - Verify: Input updates to include "by Sayam Jain"
   - Verify: Goal parses and shows beneficiary in preview

3. **Task 1 (Validation)**:
   - On Step 5, add 2 goals
   - Expand Goal 1, answer 3 of 4 questions (leave 1 incomplete)
   - Expand Goal 2, answer all 4 questions
   - Click Next
   - Verify: Navigation BLOCKED with message "Complete risk questions for: [Goal 1 name]"
   - Complete Goal 1 questions
   - Click Next
   - Verify: Navigation ALLOWED to Step 6
   - Go to Step 8 (Finalize)
   - Verify: ValidationChecklist shows "All goal risk questions answered" as completed

4. **Build Check**:
   - `npm run build` — zero errors

---

## Files Summary

| File | Tasks | Changes |
|------|-------|---------|
| `src/lib/form-validation.ts` | 1 | Add validateGoalRiskQuestions, update validateStepTransition signature, add case 5 validation |
| `src/components/ips-form/IPSForm.tsx` | 1, 3 | Pass totalGoalRiskQuestions to validation, restore manualRiskAnswers in preserveClientOnlyFields |
| `src/components/ips-form/goal/SmartGoalInput.tsx` | 2 | Add member chips UI + handleMemberChipClick handler |
| `src/components/ips-form/steps/FinalizeStep.tsx` | 1 | Add goal-risk item to ValidationChecklist |
| `src/hooks/useAutosave.ts` | 3 | Verify (read-only check, no changes expected) |

---

## Edge Cases

1. **Zero goals**: Validation passes (no goals = no questions to validate)
2. **Zero questions from API**: Validation passes (totalQuestions = 0)
3. **Partial hydration failure**: If server goals don't match localStorage, manualRiskAnswers still restored where names match
4. **Member chip click on empty input**: Should prepend "by [Name]" (not append)
5. **Member chip click on existing text**: Should append " by [Name]" with space

---

## Notes

- Dynamic question count means we can't hardcode "4 questions" in validation messages
- Member chips use same pattern as SmartAssetInput for consistency
- Goal risk answers stored in `manualRiskAnswers?: GoalManualRiskAnswers` on each Goal
- GoalManualRiskAnswers structure: `{ fundingFlexibility?, timeFlexibility?, alternativeSources?, declineResponse? }`
- Question IDs map to these keys, but validation counts ALL answered fields
