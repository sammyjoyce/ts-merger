#!/usr/bin/env bash

# Run all test cases for the TypeScript merger
# Test cases are found by traversing the "cases" directory

DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

# Create cases directory if it doesn't exist
mkdir -p ${DIR}/cases

# We always copy the binary in case it was rebuilt
cp ${DIR}/../zig-out/bin/ts-merger ${DIR}/

# Build our test environment if needed
IMAGE=$(docker build --file ${DIR}/Dockerfile -q ${DIR})

# Find and execute all test cases
find ${DIR}/cases \
  -type f \
  -name '*.sh' | \
  sort | \
  parallel \
  --will-cite \
  ${DIR}/run-host.sh \
    --case '{}' \
    --rewrite-abs-path \
    $@