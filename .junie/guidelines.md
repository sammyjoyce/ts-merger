# Fuze Project Guidelines

## Project Overview
Fuze is a robust command-line tool written in Zig that merges TypeScript source files into a single file. The tool is designed to help with refactoring, debugging, sharing code, and enhancing compatibility with Large Language Models (LLMs).

## Project Structure
- **src/**: Contains the source code for the project
  - **bindings/**: Language bindings for external libraries
  - **commands/**: CLI command implementations
  - **core/**: Core functionality and AST handling
  - **parser/**: Code for parsing TypeScript files
  - **tools/**: Additional utilities
  - **utils/**: General utility functions
  - **watcher/**: File watching functionality
  - **main.zig**: Entry point of the application
  - **project.zig**: Project configuration and management
  - **config.zig**: Configuration definitions
  - **constants.zig**: Constant definitions
- **test/**: Test files and test utilities
- **docs/**: Documentation files
- **scripts/**: Build and utility scripts
- **dist/**: Distribution files
- **.github/**: GitHub-related files and workflows

## Coding Standards

### General Guidelines
1. Keep code modular and focused on a single responsibility
2. Use clear, descriptive names for variables, functions, and types
3. Include comments for complex logic or non-obvious behavior
4. Follow the existing code style and patterns

### Zig-Specific Guidelines
1. Use Zig's error handling mechanisms consistently
2. Prefer explicit error handling over silent failures
3. Use allocators appropriately and avoid memory leaks
4. Follow Zig's naming conventions (camelCase for variables and functions, PascalCase for types)

### TypeScript Parsing Guidelines
1. Use Tree-sitter for parsing TypeScript/TSX files
2. Handle edge cases in TypeScript syntax appropriately
3. Ensure proper handling of imports, exports, and dependencies
4. Maintain code structure and semantics during merging

## Feature Implementation
When implementing new features:
1. Start by understanding the existing codebase
2. Create a clear plan for implementation
3. Write tests for the new feature
4. Implement the feature following the coding standards
5. Document the feature in the README and other relevant documentation

## Testing
1. Write tests for all new functionality
2. Ensure tests cover edge cases and error conditions
3. Run the existing test suite before submitting changes
4. Fix any test failures before submitting changes

## Documentation
1. Keep the README up-to-date with new features and changes
2. Document public APIs and interfaces
3. Include examples for complex functionality
4. Update the roadmap as features are implemented

## Contribution Process
1. Fork the repository
2. Create a feature branch
3. Implement changes following the guidelines
4. Write tests for your changes
5. Submit a pull request with a clear description of the changes
6. Address any feedback from code reviews

## Performance Considerations
1. Be mindful of memory usage, especially for large files
2. Optimize critical paths for performance
3. Consider the impact of changes on processing time
4. Use benchmarks to measure performance improvements

## Security Guidelines
1. Validate all user inputs
2. Be cautious with file system operations
3. Handle errors gracefully without exposing sensitive information
4. Follow secure coding practices

## Roadmap Priorities
Based on the current roadmap, focus on:
1. Completing code flow analysis features
2. Implementing dependency-based ordering
3. Enhancing import management capabilities
4. Improving code quality preservation
5. Enhancing developer experience with features like incremental processing

## Version Control
1. Use meaningful commit messages
2. Keep commits focused on a single change
3. Rebase feature branches before merging
4. Tag releases with semantic versioning