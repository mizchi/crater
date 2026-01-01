# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg.json` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check the test is passed. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- agent-todo.md has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done

## Test System

### Taffy Compatible Tests

This project includes tests compatible with [taffy](https://github.com/DioxusLabs/taffy), a Rust-based layout engine. These tests ensure layout algorithm correctness.

**Location:**
- Fixtures: `fixtures/` (JSON format)
  - `fixtures/flex/` - Flexbox layout tests
  - `fixtures/grid/` - Grid layout tests
  - `fixtures/block/` - Block layout tests
  - `fixtures/blockflex/`, `fixtures/blockgrid/`, `fixtures/gridflex/` - Mixed layout tests
  - `fixtures/leaf/` - Leaf node tests
- Generated tests: `compute/*/gen_test.mbt`

**Commands:**
```bash
# Generate MoonBit tests from fixtures
npm run gen-moonbit-tests -- fixtures/flex compute/flex/gen_test.mbt --flex
npm run gen-moonbit-tests -- fixtures/grid compute/grid/gen_test.mbt --grid
npm run gen-moonbit-tests -- fixtures/block compute/block/gen_test.mbt --block

# Options:
# --flex, --grid, --block    Select layout type
# --no-header                Skip assert_approx helper (for additional test files)
# --exclude=pattern          Exclude tests matching pattern

# Run tests
moon test
```

**Fixture Format (JSON):**
```json
{
  "name": "test_name",
  "viewport": { "width": 800, "height": 600 },
  "root": {
    "id": "root",
    "style": { "display": "flex", "width": { "unit": "px", "value": 400 }, ... },
    "layout": { "x": 0, "y": 0, "width": 400, "height": 300 },
    "children": [ ... ]
  }
}
```

### WPT (Web Platform Tests)

Browser compatibility tests using actual WPT test files from [web-platform-tests](https://github.com/web-platform-tests/wpt).

**Location:**
- Test files: `wpt-tests/css-flexbox/` (HTML format)
- Tools: `tools/fetch-wpt.ts`, `tools/wpt-runner.ts`

**Commands:**
```bash
# Fetch WPT tests (from GitHub)
npm run wpt:fetch -- css-flexbox
npm run wpt:fetch -- css-flexbox --limit 50
npm run wpt:fetch -- --all
npm run wpt:fetch -- --list     # Show available modules

# Run WPT comparison tests (requires Puppeteer)
npm run wpt -- wpt-tests/css-flexbox/align-content-horiz-001a.html
npm run wpt -- wpt-tests/css-flexbox/*.html
```

**How it works:**
1. Fetches HTML tests from WPT repository
2. Inlines external CSS, removes test scripts
3. Renders in Puppeteer (browser) and Crater
4. Compares layout trees (position, size)
5. Reports mismatches with tolerance

**Available CSS modules:**
- `css-flexbox` - Flexbox tests
- `css-display`, `css-box`, `css-sizing`
- `css-align`, `css-position`, `css-overflow`
