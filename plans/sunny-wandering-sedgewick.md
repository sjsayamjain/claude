# Plan: Add Multiselect & Number Question Types to Risk Profiling

## Problem
The backend API returns risk questions with `question_type` of `"select"`, `"multiselect"`, or `"number"`, but the UI only renders radio-button options (the `"select"` pattern). NUMBER questions show no input, MULTISELECT questions show radio buttons instead of checkboxes.

## Files to Modify (5 files)

### 1. `src/types/api.ts` — Type narrowing
Change `question_type: string` → `question_type: 'select' | 'multiselect' | 'number'`

### 2. `src/schemas/question.schema.ts` — Schema validation
Change `question_type: z.string()` → `z.enum(['select', 'multiselect', 'number'])`

### 3. `src/components/ips-form/steps/RiskProfilingStep.tsx` — Main UI (biggest change)
- Add `handleMultiselectToggle()` handler: toggles checkbox selection, stores in `selectedOptionIds`, score = average of selected options' index-based scores
- Add `handleNumberInput()` handler: stores `numericValue`, sets `score = 0` (excluded from composite)
- Conditional rendering by `question.question_type`:
  - `"select"`: Keep existing radio button cards (unchanged)
  - `"multiselect"`: Square checkbox indicator with checkmark SVG, multiple selections allowed
  - `"number"`: `<Input type="number" />` field with optional hint text from options array
- Import `Input` from `@/components/ui/input`

### 4. `src/lib/risk-scoring.ts` — Scoring logic
In `calculateCompositeScore()`: filter out answers with `score === 0` before averaging. This excludes number questions from the composite while still counting them as "answered" for progress tracking.

### 5. `src/components/ips-form/summary/RiskProfileCard.tsx` — Per-question display
In the "Score by Question" section: for `number` type questions, show the raw numeric value instead of a gauge bar. For `multiselect`, the existing gauge works (averaged score displays correctly).

## Scoring Strategy
- **Select**: score = optionIndex + 1 (unchanged)
- **Multiselect**: score = average of all selected options' scores
- **Number**: score = 0 (excluded from composite — backend provides no scoring ranges)

## What stays unchanged
- `src/types/ips.ts` — `RiskAnswer` already has `selectedOptionIds?` and `numericValue?` fields
- `src/lib/form-validation.ts` — `answers.length === expectedRiskCount` check works for all types
- Progress bar logic — answers are added/removed atomically, so count-based tracking is correct

## Verification
1. `npm run build` — TypeScript compiles without errors
2. `npm run dev` → navigate to Risk step → verify:
   - SELECT questions: radio buttons, single select (unchanged)
   - MULTISELECT questions: square checkboxes, multiple selections
   - NUMBER questions: number input field
3. Answer all questions → risk profile result card appears with correct composite score
4. Navigate to Step 8 (Finalize) → RiskProfileCard shows per-question breakdown correctly
5. Number questions show value (not gauge), multiselect shows averaged score gauge
