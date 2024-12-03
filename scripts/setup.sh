#!/bin/bash
set -e

# Print colorful status messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up development environment...${NC}"

# Create deps directory if it doesn't exist
echo -e "${BLUE}Creating deps directory...${NC}"
mkdir -p deps

# Clone tree-sitter if it doesn't exist
if [ ! -d "deps/tree-sitter" ]; then
    echo -e "${BLUE}Cloning tree-sitter...${NC}"
    git clone --depth 1 --branch v0.20.8 https://github.com/tree-sitter/tree-sitter.git deps/tree-sitter
    echo -e "${GREEN}Successfully cloned tree-sitter${NC}"
else
    echo -e "${GREEN}tree-sitter already exists${NC}"
fi

# Clone tree-sitter-typescript if it doesn't exist
if [ ! -d "deps/tree-sitter-typescript" ]; then
    echo -e "${BLUE}Cloning tree-sitter-typescript...${NC}"
    git clone --depth 1 --branch v0.20.1 https://github.com/tree-sitter/tree-sitter-typescript.git deps/tree-sitter-typescript
    echo -e "${GREEN}Successfully cloned tree-sitter-typescript${NC}"
else
    echo -e "${GREEN}tree-sitter-typescript already exists${NC}"
fi

# Verify the dependencies were installed correctly
echo -e "${BLUE}Verifying dependencies...${NC}"
if [ -d "deps/tree-sitter" ] && [ -d "deps/tree-sitter-typescript" ]; then
    echo -e "${GREEN}All dependencies are installed successfully!${NC}"
else
    echo "Error: Some dependencies are missing. Please check the error messages above."
    exit 1
fi

echo -e "${GREEN}Setup complete! You can now build the project.${NC}"
