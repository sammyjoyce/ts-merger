#!/usr/bin/env bash

set -e

# Create a temporary directory for this test
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Copy test fixtures to the test directory
cp ../fixtures/complex.ts "$TEST_DIR/input.ts"

# Run the merger
../ts-merger "$TEST_DIR/input.ts" -o "$TEST_DIR/output.ts"

# Verify the output exists
if [ ! -f "$TEST_DIR/output.ts" ]; then
    echo "Error: Output file was not created"
    exit 1
fi

# Check for complex type features
if ! grep -q "class Container<T, U>" "$TEST_DIR/output.ts"; then
    echo "Error: Expected generic class definition in output"
    exit 1
fi

if ! grep -q "interface StorageWithLogging extends BaseStorage, Logger" "$TEST_DIR/output.ts"; then
    echo "Error: Expected interface with multiple inheritance in output"
    exit 1
fi

if ! grep -q "@Service()" "$TEST_DIR/output.ts"; then
    echo "Error: Expected decorator in output"
    exit 1
fi

if ! grep -q "abstract class BaseService" "$TEST_DIR/output.ts"; then
    echo "Error: Expected abstract class in output"
    exit 1
fi

echo "Test passed successfully!"