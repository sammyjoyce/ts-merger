#!/usr/bin/env bash

set -e

# Create a temporary directory for this test
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Copy test fixtures to the test directory
cp ../fixtures/user.ts "$TEST_DIR/input.ts"

# Run the merger
../ts-merger "$TEST_DIR/input.ts" -o "$TEST_DIR/output.ts"

# Verify the output exists
if [ ! -f "$TEST_DIR/output.ts" ]; then
    echo "Error: Output file was not created"
    exit 1
fi

# Check for user management patterns
if ! grep -q "interface User" "$TEST_DIR/output.ts"; then
    echo "Error: Expected User interface in output"
    exit 1
fi

if ! grep -q "class UserService" "$TEST_DIR/output.ts"; then
    echo "Error: Expected UserService class in output"
    exit 1
fi

if ! grep -q "interface AuthenticationResult" "$TEST_DIR/output.ts"; then
    echo "Error: Expected AuthenticationResult interface in output"
    exit 1
fi

if ! grep -q "@Injectable()" "$TEST_DIR/output.ts"; then
    echo "Error: Expected Injectable decorator in output"
    exit 1
fi

echo "Test passed successfully!"