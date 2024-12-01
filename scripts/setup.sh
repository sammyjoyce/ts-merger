#!/bin/bash
set -e

# Create deps directory if it doesn't exist
mkdir -p deps

# Clone tree-sitter if it doesn't exist
if [ ! -d "deps/tree-sitter" ]; then
    git clone --depth 1 --branch v0.20.8 https://github.com/tree-sitter/tree-sitter.git deps/tree-sitter
fi

# Clone tree-sitter-typescript if it doesn't exist
if [ ! -d "deps/tree-sitter-typescript" ]; then
    git clone --depth 1 --branch v0.20.1 https://github.com/tree-sitter/tree-sitter-typescript.git deps/tree-sitter-typescript
fi
