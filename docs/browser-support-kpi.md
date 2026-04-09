# Browser Support KPI Snapshot (2026-04-09)

## Executive summary

- Current published browser-behavior snapshot remains green:
  - DOM WPT: `9296 / 9296 = 100.0%`
  - WebDriver BiDi tracked suites: `4537 / 4537 = 100.0%`
- Current published CSS subset snapshot is now `1396 / 1484 = 94.1%`.
- This is lower than the previous published snapshot (`1472 / 1484 = 99.2%`) because the measurement baseline moved after refreshing browser-side Node dependencies, especially `puppeteer` and its bundled Chromium.
- Visual fidelity sample numbers are unchanged in the published README:
  - `example.com`: `1.16%`
  - `info.cern.ch`: `3.30%`
  - `google`: `3.80%`
  - `wikipedia`: `7.65%`
  - `news.ycombinator.com`: `12.4%`
- Practical fixtures remain strong:
  - Tailwind practical fixtures: `38 / 38 = 100%`
  - Tailwind audited property coverage: `16 / 90 = 17.8%`

## KPI table

| Area | Metric | Source |
| --- | ---: | --- |
| DOM behavior | `9296 / 9296 = 100.0%` | `README.md` |
| WebDriver BiDi | `4537 / 4537 = 100.0%` | `README.md` |
| CSS subset | `1396 / 1484 = 94.1%` | `README.md` |
| Tailwind practical fixtures | `38 / 38 = 100%` | `tailwind-compat.json` |
| Tailwind audited property coverage | `16 / 90 = 17.8%` | `tailwind-coverage.json` |

## Dependency refresh impact

The current README snapshot was regenerated after refreshing Node dependencies to current latest versions:

- `puppeteer`: `23.11.1 -> 24.40.0`
- `@playwright/test`: `1.58.0 -> 1.59.1`
- `playwright`: `1.58.0 -> 1.59.1`
- `preact`: `10.28.2 -> 10.29.1`
- `vitest`: `3.2.4 -> 4.1.4`
- `ws`: `8.19.0 -> 8.20.0`
- `@bytecodealliance/jco`: `1.15.4 -> 1.17.6`

Published CSS subset totals therefore moved as follows:

| Snapshot | Passed | Total | Rate |
| --- | ---: | ---: | ---: |
| Previous published snapshot | `1472` | `1484` | `99.2%` |
| Current published snapshot | `1396` | `1484` | `94.1%` |
| Delta | `-76` | `0` | `-5.1pt` |

This should be treated as a browser-baseline refresh first, not automatically as a renderer regression.

## Remaining CSS subset failures by module

| Module | Passed | Total | Failed | Rate |
| --- | ---: | ---: | ---: | ---: |
| `css-flexbox` | 282 | 289 | 7 | 97.6% |
| `css-grid` | 32 | 33 | 1 | 97.0% |
| `css-tables` | 30 | 32 | 2 | 93.8% |
| `css-sizing` | 83 | 94 | 11 | 88.3% |
| `css-align` | 37 | 44 | 7 | 84.1% |
| `css-position` | 83 | 84 | 1 | 98.8% |
| `css-overflow` | 214 | 243 | 29 | 88.1% |
| `css-contain` | 283 | 303 | 20 | 93.4% |
| `filter-effects` | 98 | 106 | 8 | 92.5% |
| `css-content` | 1 | 2 | 1 | 50.0% |
| `css-break` | 26 | 27 | 1 | 96.3% |

Total remaining CSS subset failures: `88`.

## Suggested priority

1. `css-overflow`
   Absolute count is largest at `29` fails, so this is the highest-yield bucket.
2. `css-contain`
   `20` fails remain, and this area often affects downstream layout behavior.
3. `css-sizing`
   `11` fails remain, and this is likely to interact with overflow and contain fixes.
4. `filter-effects`
   `8` fails remain, but they are clustered and still good candidates for targeted issue slicing.
5. `css-align` and `css-flexbox`
   Counts are smaller than overflow/contain, but they touch broadly visible layout behavior.

## Verification

Commands used for the current published snapshot:

```sh
pnpm outdated
pnpm up --latest @bytecodealliance/jco @playwright/test playwright preact ws puppeteer vitest
pnpm exec vitest run scripts/wpt-ci-summary.test.ts scripts/wpt-vrt-summary.test.ts scripts/wpt-vrt-summary-cli.test.ts scripts/wpt-runner.test.ts
pnpm exec vitest run scripts/script-cli.test.ts scripts/script-runtime.test.ts
pnpm exec playwright test tests/playwright-adapter.test.ts
npx tsx scripts/update-wpt-readme.ts
```

## Notes

- The CSS subset numbers above are the same values now published in `README.md` and `README.mbt.md`.
- If issue slicing needs exact failing fixture names again, rerun the failing modules individually after the dependency refresh, because the old pre-refresh breakdown is no longer authoritative.
