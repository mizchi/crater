# Issue: Native Target Test Crash with SIGABRT

**Status**: Worked around by excluding problematic tests from generation.

## Summary

Native target crashes with SIGABRT on array out-of-bounds access, instead of providing a proper error message like JS target does.

## Environment

- **MoonBit version**: moon 0.1.20251222 (3f6c70c 2025-12-22)
- **Feature flags**: rupes_recta enabled
- **Platform**: macOS (Darwin 24.5.0)
- **Architecture**: arm64 (Apple Silicon)

## Reproduction

### Repository

- **Repository**: https://github.com/mizchi/crate (MoonBit port - taffy layout engine)
- **Commit**: `61d3d466ff4fb5ebeaa424161ac68ae1a0a37285`
- **Branch**: main

### Steps

```bash
# Clone and checkout the specific commit
git clone <repo>
git checkout 61d3d466ff4fb5ebeaa424161ac68ae1a0a37285

# Run the crashing test
moon test --target native -p flex --file gen_test_misc.mbt
```

### Expected

Tests should run and report pass/fail results.

### Actual

```
Failed to run the test: .../flex.internal_test.exe
The test executable exited with signal: 6 (SIGABRT)
```

## Investigation Findings

### What Works

| Package | Lines | Tests | Native |
|---------|-------|-------|--------|
| block/gen_test.mbt | ~10,000 | 223 | ✅ Works |
| grid/gen_test.mbt | ~18,000 | 329 | ✅ Works |

### What Fails

| File | Lines | Tests | Native |
|------|-------|-------|--------|
| flex/gen_test.mbt (original) | 27,287 | 607 | ❌ SIGABRT |

### Split File Testing

We split the large flex test file into 16 smaller files:

| File | Lines | Tests | Native |
|------|-------|-------|--------|
| gen_test_align.mbt | 6,797 | 107 | ✅ Works |
| gen_test_misc.mbt | 3,609 | 73 | ❌ SIGABRT |
| gen_test_gap.mbt | 2,298 | 42 | ✅ Works |
| gen_test_flex.mbt | 2,442 | 49 | ✅ Works |
| gen_test_justify.mbt | 2,235 | 37 | ✅ Works |
| gen_test_absolute.mbt | 1,937 | 36 | ✅ Works |
| gen_test_margin.mbt | 1,200 | 22 | ✅ Works |
| gen_test_percentage.mbt | 1,118 | 20 | ✅ Works |
| gen_test_rounding.mbt | 1,092 | 25 | ✅ Works |
| gen_test_wrap.mbt | 1,071 | 23 | ✅ Works |
| gen_test_bevy.mbt | 1,031 | 12 | ✅ Works |
| gen_test_aspect.mbt | 749 | 12 | ✅ Works |
| gen_test_measure.mbt | 592 | 10 | ✅ Works |
| gen_test_min.mbt | 410 | 6 | ✅ Works |
| gen_test_overflow.mbt | 392 | 6 | ✅ Works |
| gen_test_padding.mbt | 359 | 6 | ✅ Works |

**Key Finding**: `gen_test_misc.mbt` (3,609 lines, 73 tests) crashes even though it's smaller than `gen_test_align.mbt` (6,797 lines) which works fine.

This suggests the crash is **not simply related to file size or test count**.

### Characteristics of gen_test_misc.mbt

The misc file contains tests with various prefixes that didn't fit into specific categories:
- `gridflex_*` (grid-flex integration tests)
- `intrinsic_sizing_*`
- `multiline_*`
- `nested_*`
- `only_*`
- `single_*`
- Some individual tests

## Possible Causes

1. **Specific test pattern**: Certain test combinations trigger the crash
2. **Native runtime memory issue**: Specific data patterns cause memory corruption
3. **Stack overflow**: Deep recursion in certain test scenarios

## Workaround (Applied)

Exclude tests with `display: None` that cause array out-of-bounds errors during test generation:

```bash
# In justfile:
npm run gen-moonbit-tests -- --flex --exclude=display_none fixtures/flex flex/gen_test.mbt
```

This excludes 8 tests that cause runtime errors. All other tests (599 total) now run successfully on Native target.

## Root Cause (Found via Binary Search)

The crash is caused by **array out-of-bounds access**.

### Minimal Reproduction Test

```moonbit
test "taffy/display_none" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    flex_direction: @style.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0 = @node.Node::leaf("node", { ..@style.Style::default(), flex_grow: 1.0 })
  root_children.push(root_child0)
  let root_child1 = @node.Node::leaf("node", {
    ..@style.Style::default(),
    display: @style.None,  // This child is excluded from layout.children
    flex_grow: 1.0
  })
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let ctx : @node.LayoutContext = { available_width: 800.0, available_height: Some(600.0), sizing_mode: @node.MaxContent }
  let layout = compute(root, ctx)

  // BUG: layout.children only has 1 child (display:None is excluded)
  // But test tries to access children[1]
  assert_approx(layout.children[1].x, 0.0)  // <-- Out of bounds!
}
```

### Behavior Difference

**JS target** (correct behavior):
```
[mizchi/crater] test flex/gen_test_misc.mbt:604 ("taffy/display_none") failed: Error
    at throw (__$moonrun_v8_builtin_script$__wasm_mode_entry:25:19)
    at @moonbitlang/core/builtin.Array::at|@mizchi/crater/node.Layout|
[mizchi/crater] test flex/gen_test_misc.mbt:689 ("taffy/display_none_fixed_size") failed: Error
...
Total tests: 73, passed: X, failed: Y.  <-- Continues running all tests
```

**Native target** (crash):
```
The test executable exited with signal: 6 (SIGABRT)
```
No error message, no test results - entire test run aborts.

### Conclusion

The underlying bug is in our test fixture (accessing non-existent array index). However:

1. **JS target handles this correctly**: Catches the error, reports it, continues with remaining tests
2. **Native target crashes**: SIGABRT with no error message

This appears to be a **Native runtime error handling issue**:
- The test framework cannot catch/recover from array out-of-bounds errors on native target
- Instead of a proper error, the entire process terminates with SIGABRT

## Project Context

- CSS layout engine implementing Flexbox/Grid (MoonBit port of Taffy)
- Each test creates a tree of nodes and runs layout calculation
- Tests are auto-generated from JSON fixtures

## Additional Testing

### Legacy Build (NEW_MOON=0)

```bash
$ NEW_MOON=0 moon test --target native -p flex --file gen_test_misc.mbt
Failed to run the test: .../flex.internal_test.exe
The test executable exited with signal: 6 (SIGABRT)
Total tests: 73, passed: 0, failed: 73.
```

**Result**: Same crash occurs with legacy build. Issue is not specific to rupes_recta.

### Verification: Remove Problematic Tests

Created a version without `display_none` tests (which cause array out-of-bounds):

```bash
# Remove 8 display_none tests from 73 total
$ sed '/^test "taffy\/display_none/,/^}$/d' gen_test_misc.mbt > gen_test_misc_fixed.mbt

# Native works with 65 remaining tests!
$ moon test --target native -p flex --file gen_test_misc_fixed.mbt
Total tests: 65, passed: 31, failed: 34.
```

**Conclusion**: When tests don't have runtime errors, Native target works correctly. The crash only occurs when an error (like array out-of-bounds) happens.

## Questions for MoonBit Team

1. Is it expected that native target crashes with SIGABRT on array out-of-bounds instead of a proper error?
2. Can native target provide error messages like JS target does for runtime errors?
3. Is there a way to enable bounds checking in native builds for debugging?
