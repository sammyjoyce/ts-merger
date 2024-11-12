# Design

## Overview
Fuze is a code merging tool designed to combine multiple source files while preserving their module structure and exports. It uses tree-sitter for robust parsing and supports multiple programming languages.

## Architecture

### Core Components

1. AST Handling
   - Provides a language-agnostic AST representation
   - Implements visitors for traversing and transforming code

2. Language Support
   - Language-specific parsers built on tree-sitter
   - Common utilities shared across languages
   - Extensible design for adding new languages

3. Merge Engine
   - Core merging logic
   - Configurable merge rules
   - Export/import resolution

4. File System Operations
   - File reading and writing
   - Directory traversal
   - Path resolution

## Design Decisions

1. Tree-sitter Integration
   - Robust parsing across languages
   - Handles partial and invalid syntax
   - Excellent performance characteristics

2. Language Abstraction
   - Common interface for all languages
   - Shared utilities reduce duplication
   - Easy to add new language support

3. Merge Strategy
   - Preserves module structure
   - Maintains export order
   - Resolves dependencies correctly
