#!/usr/bin/env bash

set -e

# Create a temporary directory for this test
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Copy test fixtures to the test directory
cp ../fixtures/simple.ts "$TEST_DIR/input.ts"

# Run the merger
../ts-merger "$TEST_DIR/input.ts" -o "$TEST_DIR/output.ts"

# Verify the output exists
if [ ! -f "$TEST_DIR/output.ts" ]; then
    echo "Error: Output file was not created"
    exit 1
fi

# Add more specific assertions here based on expected output
# For example, check if certain patterns exist in the output
if ! grep -q "export class" "$TEST_DIR/output.ts"; then
    echo "Error: Expected 'export class' in output"
    exit 1
fi

echo "Test passed successfully!"