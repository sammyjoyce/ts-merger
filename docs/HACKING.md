# Development Guide

## Setup

1. Install Zig (version 0.11.0 or later)
2. Clone the repository
3. Run `zig build` to compile

## Project Structure

```
src/
├── ast/          # AST handling
├── languages/    # Language implementations
├── merge/        # Core merge functionality
├── testing/      # Test utilities
└── utils/        # Common utilities
```

## Adding a New Language

1. Create a new file in `src/languages/`
2. Implement the common language interface
3. Add tree-sitter parser integration
4. Add tests
5. Update documentation

## Running Tests

```bash
# Run all tests
zig build test

# Run specific test
zig build test -- --test-filter "ast"
```

## Code Style

- Follow Zig style guidelines
- Keep functions small and focused
- Write tests for new functionality
- Document public APIs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## Building Documentation

Documentation is written in Markdown and located in the `docs/` directory.
