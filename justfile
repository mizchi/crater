# Justfile for crater test runner

# Default target
default: test

# Run all tests (JS target)
test:
    moon test -p block
    moon test -p flex
    moon test -p grid

# Run all tests with native target
test-native:
    moon test --target native -p block
    moon test --target native -p flex
    moon test --target native -p grid

# Run quick tests (block only, fastest)
test-quick:
    moon test -p block

# Generate flex tests (excluding display_none tests that crash native)
gen-flex-tests:
    npm run gen-moonbit-tests -- --flex --exclude=display_none fixtures/flex flex/gen_test.mbt

# Generate block tests
gen-block-tests:
    npm run gen-moonbit-tests -- --block fixtures/block block/gen_test.mbt

# Generate grid tests
gen-grid-tests:
    npm run gen-moonbit-tests -- fixtures/grid grid/gen_test.mbt

# Generate all tests
gen-tests: gen-flex-tests gen-block-tests gen-grid-tests

# Check compilation
check:
    moon check

# Clean build artifacts
clean:
    moon clean

# Run gentest to generate JSON fixtures from HTML
gentest pattern:
    npm run gentest -- --batch fixtures/html fixtures/{{pattern}} {{pattern}}
