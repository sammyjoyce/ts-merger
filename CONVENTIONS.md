# Zig Project Conventions

## Quick Reference

- Project uses Zig nightly version: `0.14.0-dev.2367+aa7d13846`
- All code must pass `zlint` checks
- All public APIs must have explicit type annotations
- Error handling must be explicit with custom error sets

## Core Rules

### Type System Rules

#### 1. Type Conversions and Casting
```zig
// CORRECT
const len: u32 = if (size <= std.math.maxInt(u32))
    @intCast(size)
else
    return error.LengthTooLarge;

// INCORRECT - unsafe cast
const len = @intCast(u32, size);
```

#### 2. Pointer Types
```zig
// CORRECT - null-terminated string
const str: [*:0]const u8 = try allocator.dupeZ(u8, slice);

// INCORRECT - unsafe cast
const str: [*:0]const u8 = @ptrCast(slice.ptr);
```

#### 3. Memory Management
```zig
// CORRECT - explicit allocation
var list = std.ArrayList(T).init(allocator);
defer list.deinit();

// INCORRECT - raw allocation
const ptr = allocator.alloc(T, size);
```

### Error Handling Patterns

#### 1. Error Sets
```zig
// CORRECT
const ParseError = error{
    InvalidSyntax,
    UnexpectedToken,
    LengthTooLarge,
};

fn parse(input: []const u8) ParseError!Node {
    if (input.len > std.math.maxInt(u32)) {
        return error.LengthTooLarge;
    }
    // ...
}
```

#### 2. Error Propagation
```zig
// CORRECT
fn processNode(node: *Node) !void {
    try node.validate();
    try node.transform();
    return node.save();
}

// INCORRECT
fn processNode(node: *Node) void {
    node.validate() catch {};
}
```

### Safety Guidelines

#### 1. Undefined Values
```zig
// CORRECT
// SAFETY: location is initialized in the next step
const node = Node{
    .location = undefined,
};
node.location = computeLocation();

// INCORRECT
const node = Node{
    .location = undefined,  // Missing safety comment
};
```

#### 2. Optional Types
```zig
// CORRECT
const value: ?T = map.get(key) orelse return error.NotFound;

// INCORRECT
const value = map.get(key).?;  // Can panic
```

## Notes for code changes

1. When making code changes:
   - Always include explicit type annotations for public APIs
   - Add safety comments for `undefined` values
   - Use error unions for fallible operations
   - Prefer slices over pointers when possible

2. When reviewing code:
   - Check for proper resource cleanup with `defer`
   - Verify error handling is explicit
   - Ensure type conversions are safe
   - Look for proper null-termination handling in C interop

3. Common patterns to enforce:
   - Use of `try` for error propagation
   - Explicit memory management
   - Safe type conversions
   - Proper sentinel-terminated string handling

## Project Structure

- **Core Modules**: Written in Zig, handling the main logic, rendering, I/O operations, and other core functionalities.
- **Platform-Specific Components**:
  - **macOS**: Utilizes appropriate frameworks and tools for native UI elements.
  - **Linux**: Uses suitable libraries and toolkits for the GUI experience.
  - **Other Platforms**: Adapted as necessary based on target platforms.
- **Dependencies**: Custom dependencies, such as event loops and utilities, are implemented in Zig to maintain consistency and performance.

## Coding Standards

### Language Features

- **Zig Language**: The project uses Zig nightly (0.14.0-dev.2367+aa7d13846) for its core components, taking advantage of its compile-time features and performance capabilities.
- **Compile-Time Usage**: Extensive use of Zig's `comptime` capabilities for compile-time computations, optimizations, and metaprogramming tasks.
- **SIMD Optimizations**: Leverage Zig's support for SIMD instructions to enhance performance, especially in data processing and parsing tasks.

### Naming Conventions

- **Modules and Files**: Named clearly to reflect their functionality (e.g., `renderer.zig`, `io_thread.zig`).
- **Variables and Functions**: Use descriptive names following Zig’s standard naming conventions (e.g., `initializeRenderer`, `readPty`).
- **Types and Structures**: Capitalize type names and use `snake_case` for fields within structures (e.g., `FontIndex`, `font_index`).

### Documentation

- **Inline Comments**: Provide explanations for complex logic or non-trivial implementations to aid understanding.
- **Docstrings**: Use Zig’s documentation standards to describe modules, functions, and important data structures, enhancing code readability and maintainability.

## Architecture

### Subsystems

The application is divided into major subsystems, each responsible for distinct functionalities:

- **Entry Point**: Manages the initialization and coordination of the application.
- **Core Functionality**: Handles the main logic, including data processing, rendering, and I/O operations.
- **Platform Integration**: Manages interactions with platform-specific APIs and frameworks.
- **Utilities**: Contains helper modules and shared utilities used across the application.

### Runtime Architecture

- **Application Launch**: Initiates the main entry point, which sets up necessary subsystems and configurations.
- **Subsystem Management**: Each subsystem operates independently while interacting through well-defined interfaces.
- **Thread Responsibilities**:
  - **I/O Thread**: Manages input/output operations, handling data streams, and interfacing with external processes or APIs.

## Key Design Patterns

### Comptime Interfaces

- **Definition**: Interfaces defined at compile time, allowing different implementations based on build-time information.
- **Usage**: Primarily used for platform-specific functionalities, such as rendering engines, runtime environments, and utility modules.
- **Benefits**:
  - Zero runtime overhead for swapping implementations.
  - Cleaner codebase without the need for `#ifdef`-style guards.
- **Considerations**:
  - Ensure all build options are tested to avoid build failures.
  - Utilize Continuous Integration (CI) pipelines to run through all build configurations.

### Data Tables

- **Purpose**: Manage configuration data, such as input encodings, key mappings, and protocol definitions.
- **Implementation**:
  - **Raw Entries**: Defined as tuples or simple structures for ease of table construction.
  - **Compile-Time Processing**: Convert raw entries into runtime-friendly structures at compile time to optimize performance.
- **Advantages**:
  - Reduced binary size by excluding unused data.
  - Elimination of runtime conditional lookups, enhancing efficiency.

### Type Generation with `@Type`

- **Functionality**: Create types at compile time using Zig’s `@Type` builtin.
- **Applications**:
  - Defining exhaustive enums based on data tables.
  - Structuring complex data types with precise memory layouts.
- **Guidelines**:
  - Limit usage to necessary scenarios to maintain readability.
  - Avoid excessive metaprogramming to prevent increased compilation times and reduced code clarity.

### Comptime Union Subsets

- **Definition**: Creating subsets of a tagged union at compile time, allowing functions to operate on specific subsets without losing compiler-enforced exhaustiveness.
- **Usage**: Useful when certain functions only need to handle a subset of a tagged union’s cases, enhancing type safety and reducing boilerplate.

**Implementation Steps**:

1. **Define Scopes**: Introduce an enumeration to categorize each union member.

   ```zig
   pub const Scope = enum {
       app,
       terminal,
   };
   ```

2. **Scope Function**: Create a function that determines the scope of a given union member.

   ```zig
   pub fn scope(action: Action) Scope {
       return switch (action) {
           .quit,
           .close_all_windows,
           .open_config,
           .reload_config => .app,
           .new_window,
           .close_window,
           .scroll_lines => .terminal,
       };
   }
   ```

3. **ScopedAction Type Generator**: Utilize `comptime` to generate a new union type that includes only the members belonging to a specific scope.

   ```zig
   pub fn ScopedAction(comptime s: Scope) type {
       const all_fields = @typeInfo(Action).Union.fields;
       var fields: [all_fields.len]std.builtin.Type.UnionField = undefined;
       var count: usize = 0;

       for (all_fields) |field| {
           const action = @unionInit(Action, field.name, undefined);
           if (action.scope() == s) {
               fields[count] = field;
               count += 1;
           }
       }

       return @Type(.{
           .Union = .{
               .layout = .auto,
               .tag_type = null,
               .fields = fields[0..count],
               .decls = &.{},
           },
       });
   }
   ```

4. **Scoped Function**: Convert a full union to a scoped subset using the generated type.

   ```zig
   pub fn scoped(self: Action, comptime s: Scope) ?ScopedAction(s) {
       return switch (self) {
           else => |v, tag| {
               if (self.scope() != s) {
                   return null;
               }
               return @unionInit(ScopedAction(s), @tagName(tag), v);
           },
       };
   }
   ```

- **Benefits**:
  - **Type Safety**: Ensures that functions only accept relevant union members, preventing accidental handling of unrelated cases.
  - **Compiler Enforcement**: Maintains exhaustiveness checks without requiring catch-all cases.
  - **Zero Runtime Overhead**: All subset generation occurs at compile time, ensuring zero additional runtime cost.

- **Considerations**:
  - **Complexity**: Implementing comptime union subsets introduces additional complexity. Ensure that the benefits in type safety and reduced boilerplate justify this complexity.
  - **Maintenance**: Centralize scope definitions and subset generation logic to minimize maintenance overhead when union members change.

### Performance Optimizations

- **SIMD Utilization**: Implement SIMD (Single Instruction Multiple Data) where appropriate to enhance data processing speeds. Write optimized code paths for different SIMD instruction sets and employ runtime feature detection to select the best implementation.
- **Precomputed Lookup Tables**: Use precomputed lookup tables for performance-critical operations such as codepoint width calculations and grapheme break detections. Ensure these tables are cache-friendly and memory-efficient.
- **Fast-Path Parsing**: Implement fast-path parsers for common patterns (e.g., CSI sequences) to minimize parsing latency and improve throughput.
- **Grapheme Break Detection**: Optimize grapheme break detection by leveraging preconditions and efficient lookup mechanisms to reduce computational complexity.

## Integration with Other Languages

### Interfacing with C-Compatible APIs

- **Objective**: Achieve seamless integration with other programming languages by exposing C-compatible APIs.
- **Methodology**:
  - **C API**: Package core functionalities as a C library to facilitate interaction with languages that can interface with C (e.g., Swift, Python).
  - **Linking Dependencies**: Other language components link against the Zig-compiled C library and interact via the defined C API.
- **Benefits**:
  - Leverages the strengths of other languages while maintaining Zig’s portability and performance.
  - Facilitates future embedding of the application’s core functionalities into other applications by providing a C-compatible interface.

## Performance Considerations

- **Performance Metrics**: Measure key performance indicators such as frame rates, I/O throughput, throughput of plain text and control sequences, and latency during intensive tasks.
- **Comparative Analysis**: Benchmark against existing solutions to identify performance standing and areas for improvement.

### Optimization Areas

- **Input Latency**: Ensure minimal delay between user input and application response.
- **Memory Usage**: Address memory allocation strategies, such as dynamic allocations over fixed preallocations, to reduce memory footprint.
- **Security Enhancements**: Improve handling of external inputs and data streams to enhance security and stability.

## Build and Deployment

### Zig Build System

- **Flexibility**: Utilize Zig’s build system to compile the application for multiple targets and configurations.
- **Advantages**:
  - Simplifies cross-platform builds with minimal configuration.
  - Facilitates the creation of both executable binaries and static libraries for integration with other projects.

### Artifacts

- **Current State**: Generate static libraries and executable binaries as needed for different platforms.
- **Future Plans**: Officially support multiple artifact types to allow embedding core functionalities into other applications seamlessly.

## Testing and Continuous Integration

- **Testing Strategy**:
  - **Unit Tests**: Implement comprehensive unit tests for individual modules and functions.
  - **Integration Tests**: Ensure that different subsystems interact correctly and efficiently.
  - **Fuzz Testing**: Apply fuzz testing to critical parsers and handlers to uncover and fix edge-case bugs.
- **Continuous Integration (CI)**:
  - **Automated Builds**: Set up CI pipelines to automatically build the project across all supported configurations.
  - **Automated Testing**: Integrate testing suites into the CI pipeline to ensure code quality and catch regressions early.
  - **Build Configurations**: Ensure that all possible build options and platform-specific configurations are tested regularly.

## Zig Type System and Casting Rules

### Type Safety Principles

- **Explicit Type Coercion**: Use `@intCast()`, `@floatCast()`, etc. for potentially unsafe conversions
- **Peer Type Resolution**: Let Zig infer common types in if/switch expressions
- **Sentinel-Terminated Pointers**: Use `[*:0]T` for null-terminated arrays, not raw pointers
  - When converting from slices to sentinel-terminated pointers, use `try allocator.dupeZ()`
  - Never directly cast `[]T` or `[*]T` to `[*:0]T`
- **Optional Types**: Use `?T` instead of nullable pointers where possible

### Enum Handling 

- **Enum Comparisons**: 
  - Direct comparison operators (`<`, `<=`, `>`, `>=`) are not allowed on enums
  - Use `@intFromEnum()` to compare enum values numerically
  - Use explicit matching with `switch` or `if` for enum comparisons
  - For ordered enums, define an ordering function:
    ```zig
    fn enumOrder(value: EnumType) u8 {
        return switch(value) {
            .Debug => 0,
            .Info => 1,
            .Warning => 2,
            .Error => 3,
        };
    }
    ```
  - Or use a comparison function:
    ```zig
    fn enumLessThan(a: EnumType, b: EnumType) bool {
        return @intFromEnum(a) < @intFromEnum(b);
    }
    ```
- **Tagged Unions**: 
  - Prefer tagged unions with enum tags for type-safe variants
  - Use `@unionInit()` to safely create union values
  - Always handle all cases in switch statements
- **Explicit Enum Values**:
  - Always specify enum integer values when order matters
  - Use `@enumFromInt()` to safely convert integers to enums
  - Handle invalid integer values with `catch` blocks

### Memory and Pointers

- **Slice Types**: Use `[]T` for arrays of unknown size instead of pointers
- **Many-Item Pointers**: Use `[*]T` only when absolutely necessary
  - Only for C interop or when working with unknown-length arrays
  - Never cast from slices to many-item pointers without explicit bounds checking
- **Sentinel Termination**: 
  - Use `[*:0]T` for null-terminated arrays in C interop
  - Always use `try allocator.dupeZ()` to create sentinel-terminated strings
  - Never cast directly between `[]T`/`[*]T` and `[*:0]T`
  - When reading C strings, use `std.mem.span()` to convert to slice
- **Array Length**: 
  - Prefer `[N]T` with known length over slices where possible
  - Use `std.mem.Allocator` for dynamic arrays
  - Consider using ArrayLists for growing arrays

### Error Handling

- **Error Unions**: Use `!T` for functions that can fail
- **Error Sets**: Define custom error sets for domain-specific errors
- **Try Operator**: Use `try` for propagating errors up the call stack
- **Catch**: Handle errors explicitly with `catch` blocks

### Comptime Features

- **Type Generation**: Use `@Type()` for dynamic type creation
- **Comptime Blocks**: Use `comptime` for compile-time computation
- **Build Options**: Use `@import("builtin")` for conditional compilation
- **Zero-Bit Types**: Leverage types that take no runtime space when possible

### Best Practices

- **Type Inference**: Let Zig infer types when obvious (`const x = 1;`)
- **Explicit Types**: Declare types for public APIs (`pub fn foo(x: i32) void`)
- **Optional Unwrapping**: Use `orelse` for safe optional unwrapping
- **Error Handling**: Always handle or propagate errors explicitly
- **Memory Management**: Use arena allocators for temporary allocations

## Comptime Conditional Section

### Conditional Compilation
```zig
// CORRECT
pub fn getPlatformPath() []const u8 {
    if (comptime @import("builtin").os.tag == .macos) {
        return "/Users";
    } else if (comptime @import("builtin").os.tag == .linux) {
        return "/home";
    }
    @compileError("Unsupported platform");
}

// INCORRECT
pub fn wrongPlatformPath() []const u8 {
    if (@import("builtin").os.tag == .macos) { // Missing comptime
        return "/Users";
    }
    return "/home";
}
```

### Feature Flags
```zig
// CORRECT
pub fn enableFeature(comptime config: Config) type {
    return struct {
        pub fn process() void {
            if (comptime config.debug_mode) {
                std.debug.print("Debug mode\n", .{});
            }
        }
    };
}

// INCORRECT
fn wrongFeatureFlag(config: Config) void {
    if (config.debug_mode) { // Should be comptime
        std.debug.print("Debug mode\n", .{});
    }
}
```

### Comptime Function Boundaries
```zig
// CORRECT
pub fn processWithFeature(comptime enabled: bool) void {
    if (comptime enabled) {
        doFeature();
    } else {
        doDefault();
    }
}

// INCORRECT
pub fn wrongProcess(enabled: bool) void {
    if (enabled) { // Should be comptime
        doFeature();
    }
}
```

### Mixed Runtime and Comptime
```zig
// CORRECT
pub inline fn checkFeature(
    comptime feature: Feature,
    runtime_value: anytype,
) bool {
    if (comptime feature == .debug) {
        return runtime_value > 0;
    } else {
        return true;
    }
}

// INCORRECT
pub fn wrongCheck(feature: Feature, value: anytype) bool {
    return feature == .debug and value > 0; // Should use comptime
}
```

### Build Options
```zig
// CORRECT
pub fn initWithOptions(options: Options) !void {
    if (comptime @hasField(Options, "debug_mode")) {
        if (options.debug_mode) {
            try enableDebugMode();
        }
    }
}

// INCORRECT
pub fn wrongInit(options: Options) !void {
    if (@hasField(Options, "debug_mode")) { // Should be comptime
        if (options.debug_mode) {
            try enableDebugMode();
        }
    }
}
```

### Safety Guidelines

1. Comptime Evaluation
   - Use `comptime` for:
     - Platform-specific code
     - Feature flags
     - Build configuration
     - Type generation
   - Avoid `comptime` for:
     - Runtime data
     - Dynamic configuration
     - User input

2. Function Boundaries
   - Mark functions with `comptime` when all parameters are compile-time known
   - Use `inline` for functions mixing runtime and compile-time logic
   - Keep compile-time conditions at the top level when possible

3. Error Handling
   - Use `@compileError` for compile-time errors
   - Provide clear error messages for compile-time failures
   - Handle all possible compile-time cases

4. Best Practices
   - Centralize compile-time conditions
   - Document compile-time requirements
   - Test all possible compilation paths
   - Use build options for major features