# Design memo: mixed `calc()` + border longhand cascade (issues #67, #68)

Status: design only. The fixes below mostly live in the **external `mizchi/css`
package** (a registry dependency, `.mooncakes/mizchi/css`), so they cannot be
landed from the `mizchi/crater` repo alone — they need a `mizchi/css` change, a
version bump, and the crater-side wiring listed here.

This memo records the precise root causes (which differ from the original issue
hypotheses) and the change shape, so the work can be picked up directly.

---

## Part A — mixed `calc()` has no representation (#67)

### Root cause

`@types.Dimension` (`mizchi/css` `src/values/types.mbt`) has **no `calc` variant**:

```
enum Dimension { Length(Double); Percent(Double); Auto; MinContent; MaxContent; FitContent(Double) }
```

`src/parser/inline.mbt::parse_calc_expression` already accumulates the px and
percent parts **separately** (`result_px`, `result_pct`), but when both are
non-zero it cannot store the result and returns `None`, and `parse_dimension`
then falls back to `@types.Auto`. The package's own test pins this:

> `inline_test.mbt:288` — *"parse width: calc() mixed px + % falls back to Auto"*

So `calc(50% - 3px)`, `calc(5em - 3px)`, `calc(50% + 1px)`, `calc(25% + 25%)`
all become `Auto`. Pure single-unit calc (`calc(500px)` → `Length`, `calc(50%)`
→ `Percent`) already works, which is why only the *mixed* tests fail.

### Proposed `mizchi/css` change

1. Add a linear calc variant (covers the `calc(<percentage> ± <length>)` form
   that these tests use):

   ```
   Calc(px~ : Double, percent~ : Double)   // used value = context * percent + px
   ```

2. `parse_calc_expression`: when both `result_px` and `result_pct` are non-zero,
   return `Some(Calc(px=result_px, percent=result_pct / 100.0))` instead of
   `None`. (Keep the pure-length / pure-percent collapses.)

3. `Dimension::resolve(context)`: add `Calc(px, percent) => Some(context * percent + px)`.
   `resolve_or`, `resolve_rect`, `resolve_rect_intrinsic` then inherit it.
   In an *intrinsic* context (no definite container), resolve the percent part
   against the relevant intrinsic basis per CSS sizing — this is what
   `calc-max-width-block-intrinsic-1` exercises (float shrink-to-fit), so confirm
   the percentage basis matches Chromium (197 = innermost 200 − 3, not 397).

4. Update `derive(Eq)`, the `Show` impl, and `eq_length` / `eq_percent` for the
   new variant.

5. **`em` / `rem`**: the calc parser currently only handles `px` and `%` tokens
   (em is silently dropped — `calc(5em - 3px)` loses the `5em`). Either resolve
   `em` at parse time against the computed font-size (needs font context in the
   parser) or add an `em` term to the linear form. Out of scope for the first
   cut but required for `calc(5em - 3px)`.

### Crater-side wiring (`mizchi/crater`)

Most width/height consumption already routes through `Dimension::resolve` /
`@types.resolve_rect*`, so step 3 above covers them automatically. The spots
that `match` on `Dimension` variants explicitly need a `Calc` arm (or to switch
to `resolve`):

- `layout/table/table.mbt` — column/cell width reads at ~`432`, ~`1200`, ~`1262`
  (`match col.style.width { ... }`, `match cell.style.width { ... }`).
- `layout/*` block/flex/grid sizing that pattern-matches `style.width` /
  `style.height` (e.g. `compute_inline_child`, block sizing) — audit for
  `match { Length | Percent | Auto | MinContent | MaxContent | FitContent }`
  arms and add `Calc`.
- `renderer/renderer/style_resolve.mbt` resolved-rect paths (border/padding/
  margin) inherit from `resolve_rect`, no change expected.

### Tests unblocked

`calc-max-width-block-intrinsic-1`, `calc-width-block-intrinsic-1`,
`calc-width-table-auto-1`, `calc-width-table-fixed-1`, `calc-height-table-1`
(measured failing today; `calc-min-width-block-intrinsic-1`,
`calc-max-width-block-1`, `calc-width-block-1` already pass).

---

## Part B — border shorthand clobbers a later `border-*-width` longhand (#68.1)

### Root cause (symptom-level)

`wpt/css/css-images/gradients-with-border.html`:

```css
body > div > div { width: 200px; border: solid 10px; }
#gradient1 { border-left-width: 100px; }
```

Expected border-box width `= 200 + 100 (left) + 10 (right) = 310`. Crater
reports `220 = 200 + 10 + 10` — the `border-left-width: 100px` longhand is
dropped in favour of the `border` shorthand's `10px`.

`mizchi/css` `src/computed/compute.mbt` applies both `"border"` (sets
`builder.border_left = width`, ~line 1536–1542) and `"border-left-width"`
(`builder.border_left = resolve_dimension(...)`, ~line 1604). If declarations
are not applied in **cascade order** (specificity, then source order), the
shorthand can overwrite the longhand. The fix is to ensure a `border-*-width`
longhand that wins the cascade is applied *after* (or not overwritten by) the
`border` shorthand — i.e. apply declarations in cascade order, or expand the
shorthand into longhands during cascade so normal cascade resolution applies.

### Crater-side wiring

None expected — this is internal to `mizchi/css` computed-value resolution.
Verify against `gradients-with-border.html` after the `mizchi/css` fix.

---

## Part C — `sibling-index()` is unimplemented (#68.2)

`wpt/css/css-images/linear-gradient-body-sibling-index.html` uses the
`sibling-index()` function (CSS Values 5). It is not implemented, so Crater
falls back to a default 600px viewport where the browser intentionally collapses
the body to height 0. This is a **new feature** (resolve `sibling-index()` in
`mizchi/css` value resolution with the element's sibling position), materially
larger than Parts A/B. Recommend tracking it as its own scenario rather than
bundling with the `css-images` baseline.

---

## Sequencing

1. `mizchi/css`: Part A (calc variant) and Part B (border cascade), with unit
   tests; publish a new version.
2. `mizchi/crater`: bump the `mizchi/css` dependency; add the `Calc` match arms
   in `layout/table` and any enumerating sizing sites; re-run the WPT tests
   above to confirm and pin a `css-values` / `css-images` baseline.
3. Part C (`sibling-index()`) as a separate feature.

Once Parts A/B land, `css-values` and `css-images` can move toward being enabled
as regular `wpt.json` modules (the original goal of #65 / #67 / #68).
