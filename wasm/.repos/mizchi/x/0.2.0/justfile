# MoonBit Project Commands

# Default target (native for IO operations)
target := "native"

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check
check:
    moon check --target {{target}}

# Run tests
test:
    moon test --target {{target}}

# Update snapshot tests
test-update:
    moon test --update --target {{target}}

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test

# Pre-release check on all supported targets
release-check-all:
    just release-check
    just target=js check

# Check upstream test coverage gap
sync-tests package="":
    @if [ -n "{{package}}" ]; then \
        ./scripts/sync-upstream-tests.sh {{package}}; \
    else \
        ./scripts/sync-upstream-tests.sh; \
    fi

# Run HTTP comparison benchmark via k6 (default: js vs native)
bench-http port="18080" vus="128" duration="20s" body_size="16384":
    PORT={{port}} VUS={{vus}} DURATION={{duration}} BODY_SIZE={{body_size}} ./scripts/k6/run_http_bench.sh
