# Issue: Flex Native Test Crash

## Summary

flex/gen_test.mbt crashes with SIGABRT when running with Native target.

## Symptoms

```
$ moon test --target native -p flex
error: failed to run test for target Native

Caused by:
    Failed to run the test: .../flex/flex.blackbox_test.rspfile
    The test executable exited with signal: 6 (SIGABRT)
```

## Investigation

1. JS target works fine (435/607 tests pass)
2. Block native tests work fine (198/223 tests pass)
3. Grid native tests work fine (248/329 tests pass)
4. The crash is not related to recent code changes (tested with older commits)

## Possible Causes

1. **Test file too large**: flex/gen_test.mbt is 27,287 lines
2. **Native runtime issue**: MoonBit native runtime limitation
3. **Resource exhaustion**: Stack overflow or memory issues

## Workaround

Use JS target for flex tests:
```
moon test -p flex
```

## Priority

P1 - Affects development workflow but JS target provides functional alternative.

## Related

- flex/gen_test.mbt: 27,287 lines
- block/gen_test.mbt: ~10,000 lines (works)
- grid/gen_test.mbt: ~18,000 lines (works)
