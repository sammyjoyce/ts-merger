# Fuze

**Fuze** is a robust command-line tool written in [Zig](https://ziglang.org/) that merges TypeScript source files into a single file. Consolidating your codebase is particularly useful for refactoring, debugging, sharing code, and enhancing compatibility with Large Language Models (LLMs). By organizing your codebase based on control flow, Fuze aids both LLMs and developers in better understanding and maintaining complex projects.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [Stable Release](#stable-release)
  - [Nightly Build](#nightly-build)
- [Usage](#usage)
  - [Options](#options)
  - [Example](#example)
- [Roadmap](#roadmap)
  - [Code Understanding & Analysis](#code-understanding--analysis)
  - [Code Organization & Flow](#code-organization--flow)
  - [Import Management](#import-management)
  - [Code Quality & Preservation](#code-quality--preservation)
  - [Developer Experience](#developer-experience)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Preserves Export Order:** Maintains the sequence of exports from the index file.
- **Handles Internal Imports:** Manages internal import statements between merged files.
- **Preserves Comments:** Optionally retains comments within the code.
- **Sorts Imports:** Optionally organizes import statements for better readability.
- **Excludes Files:** Allows exclusion of specific files using patterns.
- **Recursive Directory Processing:** Processes directories recursively to merge files efficiently.

## Installation

You can install **Fuze** by downloading the appropriate release artifact for your operating system and placing it in your system's `PATH`. Alternatively, use the provided installation scripts for streamlined setup.

### Stable Release

#### Unix-like Systems (Linux, macOS)

**Using `curl`:**

```bash
curl -fsSL https://raw.githubusercontent.com/sammyjoyce/fuze/main/.github/scripts/install.sh | bash
```

**Using Installation Scripts:**

```bash
curl -L -o install.sh https://github.com/sammyjoyce/fuze/raw/main/.github/scripts/install.sh
chmod +x install.sh
./install.sh
```

#### Windows (PowerShell)

**Using `Invoke-WebRequest`:**

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/sammyjoyce/fuze/main/.github/scripts/install.ps1 -OutFile install.ps1
.\install.ps1
```

**Using Installation Scripts:**

```powershell
irm https://raw.githubusercontent.com/sammyjoyce/fuze/main/.github/scripts/install.ps1 | iex
```

*Ensure that your system's `PATH` includes the directory where **Fuze** is installed.*

### Nightly Build

For the latest nightly build with the newest features (may be unstable):

#### Unix-like Systems (Linux, macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/sammyjoyce/fuze/main/.github/scripts/install-nightly.sh | bash
```

#### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/sammyjoyce/fuze/main/.github/scripts/install-nightly.ps1 | iex
```

*Note: Nightly builds contain the latest features but may be unstable. For production use, we recommend using the stable release.*

## Usage

```bash
fuze [options]
```

### Options

- `--dir <path>`          Target directory (default: current directory)
- `--out <filename>`      Output filename (default: `merged.ts`)
- `--recursive`           Process subdirectories recursively (default: `true`)
- `--exclude <patterns>`  Comma-separated exclude patterns (e.g., `tests,docs`)
- `--preserve-comments`   Preserve comments in the merged file (default: `true`)
- `--sort-imports`        Sort import statements alphabetically (default: `true`)
- `-h, --help`            Show help message

### Example

Merge all TypeScript files in the `src` directory into a single file named `merged.ts`, excluding any files in the `tests` directory while preserving comments and sorting imports:

```bash
fuze --dir src --out merged.ts --exclude tests
```

## Roadmap

Our roadmap outlines the key features and improvements planned for **Fuze**. Contributions are welcome!

### Code Understanding & Analysis

- [x] **AST-Based Parsing:** Implemented TypeScript parsing using Tree-sitter for accurate syntax handling
- [x] **Basic Flow Graph:** Implemented dependency and reference tracking between nodes
- [x] **Code Flow Analysis:** Basic code flow and dependency tracking
- [ ] **Context-aware Analysis:** Understand type information and semantic relationships
- [ ] **Cross-module Analysis:** Track dependencies and references across files

### Code Organization & Flow

- [x] **Basic Dependency Resolution:** Implemented import/export dependency tracking
- [x] **Simple Ordering:** Basic two-pass ordering system (exports first)
- [ ] **Dependency-based Ordering:** Implement topological sorting and circular dependency resolution
- [ ] **Smart Code Organization:** Group related declarations and maintain logical code blocks
- [ ] **Reference-based Positioning:** Place code based on usage patterns and references
- [ ] **Enhanced Dependency Resolution:** Add support for complex import patterns and circular dependencies
- [ ] **Namespace Merging:** Implement namespace merging and conflict detection

### Import Management

- [x] **Sort Imports:** Implemented configurable import sorting
- [x] **Basic Import Organization:** Group imports by type
- [ ] **Advanced Import Organization:** Intelligently organize imports by scope (built-in, external, internal)
- [ ] **Import Path Optimization:** Simplify and normalize import paths
- [ ] **Remove Redundancies:** Eliminate redundant import statements
- [ ] **Dead Code Elimination:** Remove unused imports and code

### Code Quality & Preservation

- [x] **Comment Preservation:** Maintain code comments during merging
- [ ] **Code Style Preservation:** Maintain consistent code formatting
- [ ] **Source Map Preservation:** Maintain source maps for better debugging

### Developer Experience

- [x] **Error Handling:** Added robust error handling and reporting
- [ ] **Incremental Processing:** Only reprocess modified files and their dependents
- [x] **File Watching:** Implemented file system watching for automatic updates
- [ ] **Watch Mode:** Automatically reprocess files on changes with caching
- [ ] **Progress Reporting:** Add detailed progress and status information
