# Agent TODO - VRT & Rendering Improvements

## Completed
- [x] linear-gradient rendering (PR #15)
- [x] border-radius rendering (PR #15)
- [x] Palette expansion to 4096 colors (PR #15)
- [x] border-radius percentage (50%) support (PR #15)

## Remaining Tasks (priority order by cost-effectiveness)

### Low effort / High impact
- [ ] **opacity support** — Add opacity CSS property to framebuffer rendering. Small change in paint pipeline + sixel alpha blending.
- [ ] **font-weight mapping** — Map font-weight values (300, 500, 700 etc.) to correct system fonts. Mainly `start-with-font.ts` changes.

### Medium effort / High impact
- [x] **text-overflow: ellipsis** — Truncate overflowing text with "…". Changes in glyph_render.mbt, needs width measurement.
- [x] **border rendering** — Draw actual border pixels (border-width/border-color) in framebuffer. Similar approach to border-radius masking.
- [x] **box-shadow rendering** — Implement box-shadow with blur, spread, offset in framebuffer.
- [ ] **Real URL snapshot comparison** — VRT tests comparing actual web pages (example.com etc.) between Chromium and Crater.

### Medium effort / Medium impact
- [ ] **float precision** — Improve float/clear layout to reduce L12 VRT budget. Margin collapse edge cases.
- [ ] **WPT test pipeline** — Strengthen WPT css-flexbox auto-comparison pipeline.

### High effort / High impact
- [ ] **CSS Grid precision** — Improve grid-gap/alignment to reduce L10 VRT budget.
- [ ] **CSS transform (basic)** — translate/scale support in framebuffer rendering.
