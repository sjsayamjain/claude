# Fix: Assets & CashFlow Card Height Alignment on Finalize Page

## Problem
On the Finalize page (Step 8), the Assets card (left) and CashFlow card (right) sit side-by-side in a `lg:grid-cols-2` grid. The CashFlow card has more content (income/expense bars + details grid), so it's taller. The Assets card doesn't stretch to match — leaving visible empty space below it.

The root cause: CSS Grid stretches the grid cell `<div>` to match row height, but `SummaryCard`'s root div doesn't have `h-full`, so it only takes its content height.

## Fix

**File: `src/components/ips-form/summary/SummaryCard.tsx` (line 31)**

Add `h-full` to the SummaryCard root div so it always fills its parent container:

```diff
- 'relative overflow-hidden rounded-xl border bg-card text-card-foreground shadow-sm',
+ 'relative overflow-hidden rounded-xl border bg-card text-card-foreground shadow-sm h-full',
```

This is the cleanest fix because:
- It's a single change in the shared component
- All summary cards automatically stretch to fill their grid cell
- No need to touch FinalizeStep.tsx or individual card components
- Cards that are already full-width (Family, Goals, Assumptions) are unaffected since `h-full` on a block-level element with no constrained parent is a no-op

## Verification
- `npm run build` — type check passes
- Visual check: Assets and CashFlow cards should be the same height in the 2-col grid
- Full-width cards (Family, Goals, Assumptions) should look unchanged
