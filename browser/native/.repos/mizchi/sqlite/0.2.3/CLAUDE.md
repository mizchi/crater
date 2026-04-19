# Project CLAUDE.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Native Target

This project targets **native** (not wasm-gc). All build and test commands must include `--target native`.

### C FFI (Foreign Function Interface)

This project uses C language bindings via MoonBit's C-FFI feature.

**Key files:**
- `stub.c` - C wrapper functions that MoonBit calls via `extern "C"`
- `moon.pkg.json` - Contains `"native-stub": ["stub.c"]` to include C source

**How it works:**
1. MoonBit declares external C functions: `extern "C" fn name(args) -> Type = "c_func_name"`
2. C implementations are provided in `stub.c`
3. `moon build --target native` compiles MoonBit to C, then links with `stub.c`

**Commands:**
```bash
moon build --target native   # Build executable
moon run . --target native   # Run the program
moon test --target native    # Run tests
moon bench --target native   # Run benchmarks
```

**Type mapping (MoonBit → C):**
- `Int` → `int32_t`
- `Int64` → `int64_t`
- `Double` → `double`
- `Bool` → `int32_t` (0/1)
- `Unit` → `void`

## Project Structure

- MoonBit packages are organized per directory. Each directory contains a `moon.pkg.json` file listing its dependencies. Each package has its files and blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in `_wbtest.mbt`).

- In the top-level directory, there is a `moon.mod.json` file with module information and metadata.

## Coding Convention

- MoonBit code is organized in block style. Each block is separated by `///|`, and the order of blocks is irrelevant. In some refactorings, you can process block by block independently.

- Try to keep deprecated blocks in a file called `deprecated.mbt` in each directory.

## Tooling

- `moon fmt` - Format your code properly.

- `moon info` - Update the generated interface of the package. Each package has a generated interface file `.mbti`, which is a brief formal description of the package. If nothing in `.mbti` changes, your change does not bring visible changes to external package users - typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and format the code. Check the diffs of `.mbti` file to see if the changes are expected.

- `moon test` - Check if tests pass. MoonBit supports snapshot testing, so when your changes affect the behavior, run `moon test --update` to update the snapshot.

- `moon check` - Check if the code is linted correctly.

- When writing tests, use `inspect` and run `moon test --update` to update snapshots. Only use assertions like `assert_eq` when you are in loops where each snapshot may vary. You can use `moon coverage analyze > uncovered.log` to see which parts of your code are not covered by tests.

- CLAUDE.md has some small tasks that are easy for AI to pick up. Agents are welcome to finish the tasks and check the box when done.

## Resolved Issues

### Priority 2 Features - SOLVED ✅

The following features initially had SIGBUS/infinite loop issues but have been resolved:

1. **`sqlite3_extended_errcode` + `sqlite3_errstr`** ✅
   - Problem: SIGBUS error
   - Cause: Attempting to directly convert static string pointers returned by SQLite to MoonBit's `Bytes` type caused memory access violations
   - Solution: Copy static strings to a global buffer (`static char errstr_buffer[256]`) before returning

2. **`sqlite3_bind_parameter_name` + `sqlite3_bind_parameter_index`** ✅
   - Problem: Infinite loop or hang
   - Cause: Same issue with direct conversion of static strings
   - Solution: Copy static strings to a global buffer (`static char param_name_buffer[256]`) before returning

### Lessons Learned

**Best practices for string handling in MoonBit C FFI:**

1. **Dynamically generated strings (tied to database handle/statement)**
   - Examples: `sqlite3_column_text`, `sqlite3_errmsg`
   - Direct return of `const char*` is fine (MoonBit handles it properly)

2. **Static strings (global constant strings)**
   - Examples: `sqlite3_errstr`, `sqlite3_bind_parameter_name`
   - **Must be copied to a buffer before returning**
   - Example: `strncpy(buffer, src, size); return buffer;`

3. **NULL handling**
   - When NULL is possible, return empty string `""`
   - Example: `return name ? name : "";`

## Writing Benchmarks

See: https://docs.moonbitlang.com/en/latest/language/benchmarks.html

Benchmark files should be named `*_wbtest.mbt` or `*_test.mbt` and use the `@bench.T` parameter in test blocks.
