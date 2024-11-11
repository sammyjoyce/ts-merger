# ts-merger

A command-line tool written in Zig that merges TypeScript files into a single file while preserving exports, maintaining module structure, and respecting index.ts barrel exports.

## Features

- Preserves export order from index.ts
- Handles internal imports between merged files
- Preserves comments (optional)
- Sorts imports (optional) 
- Excludes files via patterns
- Recursive directory processing

## Installation

```bash
git clone [repository-url]
cd ts-merger
zig build
```

## Usage

```bash
ts-merger [options]

Options:
  --dir <path>          Target directory (default: current)
  --out <name>         Output filename
  --recursive          Process subdirectories (default: true)
  --exclude <patterns> Comma-separated exclude patterns
  --preserve-comments  Keep comments (default: true)  
  --sort-imports      Sort imports (default: true)
  -h, --help          Show help
```

## Roadmap

- **Tree-sitter Integration**
  - AST-based parsing for to improve syntax handling
  - Improved import/export dependency resolution
  - Namespace merging and conflict detection
  - Source map preservation
```
