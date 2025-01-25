#!/usr/bin/env bash

set -e

# Create a temporary directory for this test
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Copy test fixtures to the test directory
cp ../fixtures/order.ts "$TEST_DIR/input.ts"

# Run the merger
../ts-merger "$TEST_DIR/input.ts" -o "$TEST_DIR/output.ts"

# Verify the output exists
if [ ! -f "$TEST_DIR/output.ts" ]; then
    echo "Error: Output file was not created"
    exit 1
fi

# Check for order management patterns
if ! grep -q "interface Order" "$TEST_DIR/output.ts"; then
    echo "Error: Expected Order interface in output"
    exit 1
fi

if ! grep -q "class OrderService" "$TEST_DIR/output.ts"; then
    echo "Error: Expected OrderService class in output"
    exit 1
fi

if ! grep -q "interface OrderItem" "$TEST_DIR/output.ts"; then
    echo "Error: Expected OrderItem interface in output"
    exit 1
fi

if ! grep -q "enum OrderStatus" "$TEST_DIR/output.ts"; then
    echo "Error: Expected OrderStatus enum in output"
    exit 1
fi

echo "Test passed successfully!"