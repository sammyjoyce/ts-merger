#!/usr/bin/env bash

set -e

# Create a temporary directory for this test
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Copy test fixtures to the test directory
cp ../fixtures/component.ts "$TEST_DIR/input.ts"

# Run the merger
../ts-merger "$TEST_DIR/input.ts" -o "$TEST_DIR/output.ts"

# Verify the output exists
if [ ! -f "$TEST_DIR/output.ts" ]; then
    echo "Error: Output file was not created"
    exit 1
fi

# Check for component patterns
if ! grep -q "@Component" "$TEST_DIR/output.ts"; then
    echo "Error: Expected component decorator in output"
    exit 1
fi

if ! grep -q "class UserProfile extends" "$TEST_DIR/output.ts"; then
    echo "Error: Expected component class definition in output"
    exit 1
fi

if ! grep -q "@Prop()" "$TEST_DIR/output.ts"; then
    echo "Error: Expected property decorator in output"
    exit 1
fi

if ! grep -q "@Emit()" "$TEST_DIR/output.ts"; then
    echo "Error: Expected emit decorator in output"
    exit 1
fi

echo "Test passed successfully!"