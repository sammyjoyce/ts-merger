# fuze

A command-line tool written in Zig that merges source files into a single file while preserving exports, maintaining module structure, and respecting index file barrel exports.

## Features

- Preserves export order from index file
- Handles internal imports between merged files
- Preserves comments (optional)
- Sorts imports (optional) 
- Excludes files via patterns
- Recursive directory processing

## Installation

```bash
git clone [repository-url]
cd fuze
zig build
```

## Usage

```bash
fuze [options]

Options:
  --dir <path>          Target directory (default: current)
  --out <name>          Output filename
  --recursive           Process subdirectories (default: true)
  --exclude <patterns>  Comma-separated exclude patterns
  --preserve-comments   Keep comments (default: true)  
  --sort-imports        Sort imports (default: true)
  -h, --help            Show help
```

## Roadmap

- **Tree-sitter Integration**
  - AST-based parsing to improve syntax handling
  - Improved import/export dependency resolution
  - Namespace merging and conflict detection
  - Source map preservation

## Project Overview

This project is a Zig-based application named **"fuze"** designed to parse and analyze TypeScript code using the [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) parsing library. The application reads TypeScript source files, constructs an Abstract Syntax Tree (AST), and processes various code constructs such as classes, interfaces, and import statements. Additionally, the project includes robust crash handling to ensure stability during execution.

## Key Components

### 1. **Build System (`build.zig`)**

- **Purpose:** Defines the build configuration for the project, including compilation targets, dependencies, and executable artifacts.
  
- **Highlights:**
  - **Static Libraries:** 
    - **`tree-sitter`:** Compiles the core Tree-sitter library from C source files.
    - **`tree-sitter-typescript`:** Compiles the TypeScript grammar for Tree-sitter.
  - **Executable (`fuze`):** The main application that links against the Tree-sitter libraries.
  - **Build Steps:**
    - Clones necessary Tree-sitter repositories if they are not already present.
    - Compiles necessary C sources for Tree-sitter.
    - Links the Tree-sitter libraries with the Zig executable.
    - Sets up installation and run commands for the executable.

### 2. **Crash Handler (`src/crash_handler.c`)**

- **Purpose:** Implements a system-level crash handler to gracefully handle unexpected signals such as segmentation faults or illegal instructions.
  
- **Highlights:**
  - **Signal Handling:** Captures signals like `SIGSEGV`, `SIGABRT`, `SIGBUS`, `SIGILL`, and `SIGFPE`.
  - **Backtrace Generation:** On receiving a signal, it captures and prints a backtrace to `stderr` for debugging purposes.
  - **Initialization:** Uses a constructor attribute to set up the crash handlers before the application starts executing.

### 3. **Parser Module (`src/parser.zig`)**

- **Purpose:** Provides functionality to parse TypeScript source files into AST nodes using Tree-sitter.
  
- **Highlights:**
  - **Structures:**
    - **`Parser`:** Manages the parsing process, including reading files, invoking Tree-sitter, and storing parsed nodes.
  - **Initialization & Cleanup:**
    - Initializes Tree-sitter parsers for TypeScript.
    - Ensures proper deinitialization of parsers and scanners to manage resources.
  - **Parsing Functions:**
    - **`parseFile`:** Reads a TypeScript file from disk and initiates parsing.
    - **`parseString`:** Parses a given TypeScript source string.
    - **`processNode`:** Processes individual AST nodes based on their type (e.g., classes, interfaces, imports).
    - **`processImportNode`:** Specifically handles import statements within the AST.
  - **Utilities:**
    - Extracts source code segments and locations for nodes to aid in further processing or analysis.

### 4. **Project Management (`src/project.zig`)**

- **Purpose:** Serves as the central manager for the parsing application, orchestrating the parser and flow modules.
  
- **Highlights:**
  - **Structures:**
    - **`Project`:** Encapsulates the overall project state, including the parser and flow components.
  - **Initialization & Cleanup:**
    - **`init`:** Allocates and initializes the project, including its parser and flow components.
    - **`deinit`:** Cleans up resources by deinitializing the parser and flow.
  - **Functionality:**
    - **`parseFile` & `parseString`:** Delegates parsing tasks to the parser component.
    - **`getNodes`:** Retrieves parsed nodes from the parser for further processing.
    - **`writeToFile`:** Writes the processed data to an output file, likely for reporting or analysis purposes.

## Additional Notes

- **Error Handling:** The integration of a crash handler indicates a focus on stability, ensuring that the application can handle and report unexpected failures gracefully.
  
- **Modularity:** The separation of concerns between parsing (`parser.zig`), project management (`project.zig`), and crash handling (`crash_handler.c`) suggests a well-organized codebase that facilitates maintenance and scalability.

- **Dependencies:** The project relies on external C libraries for Tree-sitter, which are integrated into the Zig build process, showcasing interoperability between Zig and C.

## Potential Enhancements

- **Logging:** Implementing more sophisticated logging mechanisms could aid in monitoring and debugging.
  
- **Configuration:** Allowing configurable parsing options or supporting multiple languages by extending Tree-sitter integrations.

- **Testing:** Incorporating comprehensive tests to ensure the reliability of the parsing and processing logic.

## Conclusion

This Zig project is a robust tool for parsing and analyzing TypeScript code, leveraging the power of Tree-sitter for efficient and accurate AST generation. With a solid build system, crash handling, and modular design, it serves as a strong foundation for further development and feature additions.
