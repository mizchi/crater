# Test SPEC

22 tests across 2 module(s) — 12 pending, 10 active

## `specs/`

### `crater.pkl`

- [ ] **Studio e2e comparison is tracked** [draft] — verifies: studio.e2e-comparison — tags: spec, studio, e2e
  > The crater-vs-Chromium Studio scenario should become a pkspec-linked external compatibility contract.
  - contributes to: goal.browser-compat, goal.visual-regression
  - body: _not yet implemented_

- [ ] **WPT DOM compatibility is tracked** [draft] — verifies: wpt.dom-contract — tags: spec, wpt, dom
  > WPT DOM runner coverage should become a pkspec-linked compatibility contract once the stable subset is agreed.
  - contributes to: goal.browser-compat
  - body: _not yet implemented_

- [ ] **approved specs are linked** (critical) — verifies: spec.check — tags: spec, pkspec
  > pkspec --check runs over crater specs and fails when approved scenarios lack an implementing test.
  - contributes to: goal.spec-contracts
  - body: _not yet implemented_

- [ ] **benchmark gate is named** — verifies: task.bench — tags: spec, pkfire, benchmark
  > The benchmark task groups component VRT bench, component baseline checks, and crater CLI bench output.
  - contributes to: goal.local-gates
  - body: _not yet implemented_

- [ ] **browser compatibility gates are separated from VRT** — verifies: browser.playwright — tags: spec, browser, playwright
  > Playwright adapter and website scenario tasks are grouped under a browser-facing gate.
  - contributes to: goal.browser-compat
  - body: _not yet implemented_

- [ ] **check gate groups static validation** (critical) — verifies: task.check — tags: spec, pkfire, ci
  > The check task aggregates MoonBit checks, TypeScript checks, flaker metadata checks, and pkspec checks.
  - contributes to: goal.local-gates, goal.spec-contracts
  - depends on: task.prepare, spec.check
  - body: _not yet implemented_

- [ ] **pkfire exposes task inventory** — verifies: task.default — tags: spec, pkfire
  > Running the default pkfire task lists the curated local task graph.
  - contributes to: goal.local-gates
  - decisions: 1 entry(ies)
  - body: _not yet implemented_

- [ ] **prepare gate refreshes generated code** — verifies: task.prepare — tags: spec, pkfire, moonbit
  > The prepare task depends on MoonBit interface generation and formatting.
  - contributes to: goal.local-gates
  - depends on: task.default
  - body: _not yet implemented_

- [ ] **publish order can be checked before release** — verifies: release.publish-order — tags: spec, release, moonbit
  > Release tasks expose dry validation and plan printing for MoonBit workspace publish order.
  - contributes to: goal.release-safety
  - body: _not yet implemented_

- [ ] **spec wiring has executable smoke tests** — verifies: spec.test — tags: spec, pkspec
  > pkspec exec runs lightweight shell tests that validate task and spec wiring without launching heavy browser suites.
  - contributes to: goal.spec-contracts, goal.local-gates
  - depends on: spec.check
  - body: _not yet implemented_

- [ ] **test gate groups fast executable tests** (critical) — verifies: task.test — tags: spec, pkfire, ci
  > The test task aggregates JS-target MoonBit tests, Vitest, node:test suites, and pkspec shell tests.
  - contributes to: goal.local-gates, goal.spec-contracts
  - depends on: task.check, spec.test
  - body: _not yet implemented_

- [ ] **visual regression gates are separated** — verifies: vrt.report — tags: spec, vrt, paint
  > Paint VRT and WPT VRT tasks are grouped independently from DOM and locator compatibility gates.
  - contributes to: goal.visual-regression
  - body: _not yet implemented_

### `tasks.Test.pkl`

- [x] **pkfire_lists_bench_task** — verifies: task.bench — tags: pkfire, smoke
  > Benchmark smoke and baseline checks should stay grouped under bench.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_browser_compatibility_tasks** — verifies: browser.playwright — tags: browser, playwright, pkfire
  > DOM and locator compatibility work should have a browser-facing pkfire group.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_check_task** — verifies: task.check — tags: pkfire, smoke
  > The static validation gate should stay visible as check.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_default_task** — verifies: task.default — tags: pkfire, smoke
  > The default task should remain discoverable as the task inventory entrypoint.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_prepare_task** — verifies: task.prepare — tags: pkfire, smoke
  > The prepare gate should stay visible for pre-commit generated-file refreshes.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_release_plan_tasks** — verifies: release.publish-order — tags: release, pkfire
  > Release checks should expose publish-order validation and plan printing without publishing.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_spec_test_task** — verifies: spec.test — tags: pkspec, pkfire, smoke
  > The pkspec executable smoke suite should be exposed through pkfire.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_test_task** — verifies: task.test — tags: pkfire, smoke
  > The fast executable gate should stay visible as test.
  - body: `cmd` (exit 0 expected)

- [x] **pkfire_lists_visual_regression_tasks** — verifies: vrt.report — tags: vrt, pkfire
  > Visual regression work should have a separate pkfire group from browser API compatibility.
  - body: `cmd` (exit 0 expected)

- [x] **pkspec_check_validates_declared_scenarios** — verifies: spec.check — tags: pkspec, contract
  > Approved crater scenarios should be linked to this Test module or explicit implementation pointers.
  - body: `cmd` (exit 0 expected)


## Outstanding questions

- **studio.e2e-comparison** — Which private Studio scenario can be represented by a public reusable contract?
- **wpt.dom-contract** — Which WPT DOM subset is stable enough to require in every local check?
