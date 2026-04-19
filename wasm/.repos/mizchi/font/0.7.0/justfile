# Download test fixtures from GitHub Release
setup:
    bash scripts/download-fixtures.sh

# Run all tests
test: setup
    moon test

# Run tests for a specific package
test-pkg pkg: setup
    moon test -p {{pkg}}

# Type check
check:
    moon check --deny-warn

# Format code
fmt:
    moon fmt

# Generate type definition files
info:
    moon info

# Update snapshot tests
update: setup
    moon test -u
