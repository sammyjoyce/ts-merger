#!/usr/bin/env bash

# This script runs a single test case in a controlled environment

set -e

DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --case)
      CASE="$2"
      shift 2
      ;;
    --rewrite-abs-path)
      REWRITE_ABS_PATH=1
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$CASE" ]; then
  echo "Must specify --case"
  exit 1
fi

# Run the test case in Docker
docker run \
  --rm \
  -v "${DIR}:/test" \
  -w /test \
  "${IMAGE}" \
  /bin/bash "${CASE}"