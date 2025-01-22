# Zig Release Notes Extraction

## https://ziglang.org/download/0.11.0/release-notes.html

  *   * 

A green check mark (✅) indicates the target meets all the requirements for the support tier. The other icons indicate
what is . In other words, the icons are . If you find any wrong data here please !

  * All the behavior tests and applicable standard library tests pass for this target. All language features are known to work correctly. Experimental features do not count towards disqualifying an operating system or architecture from Tier 1. The 🐛 icon means there are known preventing this target from reaching Tier 1. 

  * The supports this target, but it is possible that some APIs will give an "Unsupported OS" compile error. One can link with libc or other libraries to fill in the gaps in the standard library. The 📖 icon means the standard library is too incomplete to be considered Tier 2 worthy.

  * If this target is provided by LLVM, LLVM may have the target as an experimental target, which means that you need to use Zig-provided binaries for the target to be available, or build LLVM from source with special configure flags. will display the target if it is available.

The baseline value used for "i386" was a pentium4 CPU model, which is actually i686. It is also possible to target a
more bare bones CPU than pentium4. Therefore it is more correct to use "x86" rather than "i386" for this CPU
architecture. This architecture has been renamed in the CLI and APIs ().

For this change we also had to update the strategy of exporting all symbols to the host. We no longer unconditionally
export all symbols to the host. Previously this would result in unwanted symbols existing in the final binary. By
default we now only export the symbol to the linker, meaning they will only be visible to other object files so they can
be resolved correctly. If you wish to export a symbol to the host environment, the flag can be used. Alternatively, the
flag can be used to export all visible symbols to the host environment. By setting the field to on a symbol will remain
only visible to the linker and not be exported to the host. With this breaking change, the linker will behave the same
whether a user is using or Clang directly.

Three new built-in functions are added to aid with writing GPGPU kernels in Zig: , , and . These are respectively used
to query the index of the work group of the current thread in a kernel invocation, the size of a work group in threads,
and the thread index in the current work group. For now, these are only wired up to work when compiling Zig to AMD GCN
machine code via LLVM, that can be used with ROCm. In the future they will be added to the LLVM-based NVPTX and self-
hosted SPIR-V backends as well.

The officially supported minimum version of Windows is now 10, because . Patches to Zig supporting for older versions of
Windows are still accepted into the codebase, but they are not regularly tested, not part of the , and not covered by
the .

  * Add CPU feature detection for ARMv8 processors on Windows - the feature detection is based on parsing Windows registry values which contain a read-only view at the contents of system ID registers. The values are mapped as registry keys which we now pull and parse for CPU feature information.

  * remove incorrect assertion in panicking during panic - this fixes a class of bugs on macOS where a segfault happening in a loaded dylib with no debug info would cause a panic in the panic handler instead of simply noting that the dylib has no valid debug info via . An example could be code linking some system dylib and causing some routine to segfault on say invalid pointer value, which should normally cause Zig to print an incomplete stack trace anchored at the currently loaded image and backtrace all the way back to the Zig binary with valid debug info. Currently, in a situation like this we would trigger a panic within a panic.

In this release-cycle the gained experimental support for WASI-threads. This means it will be possible to create a
multi-threaded application when targeting WASI without having to change your codebase. Keep in mind that the feature is
still in proposal phase 1 of the WASI specification, so support within the standard library is still experimental and
bugs are to be expected. As the feature is still experimental, we still default to single-threaded builds when targeting
WebAssembly. To disable this, one can pass in combination with the flags. This also requires the CPU features and to be
enabled.

The same flags will also work for freestanding modules, allowing a user to build a multi-threaded WebAssembly module for
other runtimes. Be aware that the threads in the standard library are only available for WASI. For freestanding, the
user must implement their own such as Web Workers when building a WebAssembly module for the browser.

Zig now gives to the file if it is an executable and the OS is WASI. Some systems may be configured to execute such
binaries directly. Even if that is not the case, it means we will get "exec format error" when trying to run it rather
than "access denied", and then can react to that in the same way as trying to run an ELF file from a foreign CPU
architecture.

  * Matching
  * Multiple terms

  *     *       * 

In this new code, we use the new for loop syntax to iterate over both slices simultaneously, capturing the output
element by reference so we can write to it. The index capture is no longer necessary in this case. Note that this is not
limited to two operands: arbitrarily many slices can be passed to the loop provided each has a corresponding capture.
The language asserts that all passed slices have the same length: if they do not, this is safety-checked .

Previously, index captures were implicitly provided if you added a second identifier to the loop's captures. With the
new multi-object loops, this has changed. As well as standard expressions, the operand passed to a for loop can also be
a . These take the form or , with the latter form being exclusive on the upper bound. If an upper bound is provided,
must match the length of any given slices (or other bounded ranges). If no upper bound is provided, the loop is bounded
based on other range or slice operands. All for loops must be bounded (i.e. you cannot iterate over only an unbounded
range). The old behavior is equivalent to adding a trailing operand to the loop.

```

```

This code previously worked because the language implicitly took a reference to . This no longer happens: if you use a
pointer capture, the corresponding iterable must be a pointer or slice. In this case, the fix - as suggested by the
error note - is simply to take a reference to the array.

now takes two parameters. The first is the destination, and the second is the source. The builtin copies values from the
source address to the destination address. Both parameters may be a slice or many-pointer of any element type; the
destination parameter must be mutable in either case. At least one of the parameters must be a slice; if both parameters
are a slice, then the two slices must be of equal length.

Since this builtin now encompasses the most common use case of , that function has been renamed to . Like , the only use
case for that function is when the source and destination slices overlap, meaning elements must be copied in a
particular order. When migrating code, it is safe to replace all uses of with , but potentially more optimal and clearer
to instead use provided the slices are guaranteed not to overlap.

The builtins and have undergone two key changes. The first is that they now take arbitrarily many arguments, finding the
minimum/maximum value across arguments: for instance, . The second change relates to the type returned by these
operations. Previously, was used to unify the operand types. However, this sometimes led to redundant uses of : for
instance can always fit in a . To avoid this, when these operations are performed on integers (or vectors thereof), the
compiler will now notice comptime-known bounds of the result (based on either comptime-known operands or on differing
operand types) and refine the result type as tightly as possible.

In previous versions of Zig, casting builtins took as a parameter the of the cast, for instance . This was easy to
understand, but can lead to code duplication where a type must be repeated at the usage site despite already being
specified as, for instance, a parameter type or field type.

As a motivating example, consider a function parameter of type which you are passing a . You need to use to convert your
value to the correct type. Now suppose that down the line, you find out the parameter needs to be a so you can pass in
larger values. There is now a footgun here: if you don't change every to cast to the correct type, you have a silent bug
in your program which may not cause a problem for a while, making it hard to spot.

This is the basic pattern motivating this change. The idea is that instead of writing , you instead write , and the
destination type of the cast is inferred based on the type. This is not just about function parameters: it is also
applicable to struct initializations, return values, and more.

This language change removes the destination type parameter from all cast builtins. Instead, these builtins now use to
infer the result type of the cast from the expression's "result type". In essence, this means type inference is used.
Most expressions which have a known concrete type for their operand will provide a result type. For instance:

```

```

The builtins and would become quite cumbersome to use under this system as described, since you would now have to
specify the full intermediate pointer types. Instead, pointer casts (those two builtins and ) are special. They combine
into a single logical operation, with each builtin effectively "allowing" a particular component of the pointer to be
cast rather than "performing" it. (Indeed, this may be a helpful mental model for the new cast builtins more generally.)
This means any sequence of nested pointer cast builtins requires only one result type, rather than one at every
intermediate computation.

Now that we have started to get into writing our own and not relying exclusively on , the flaw with the previous API
becomes clear: writing the result through a pointer parameter makes it too hard to use a special value returned from the
builtin and detect the pattern that allows lowering to the efficient code.

The actual language change here is that this is now supported for many-ptrs. Where previously you had to write , you can
now instead write . Note that in general, unbounded slicing of many-pointers is still not permitted, requiring pointer
arithmetic: only this "slicing by length" pattern is allowed.

Previously, blocks in runtime code worked in a highly unintuitive way: they . This has been resolved in 0.11.0. The
entire body of a block will now be evaluated at compile time, and a compile error is triggered if this is not possible.

Previously, when this happened, the source file became "owned" by whichever import the compiler happened to reach first.
This was a problem, because it could lead to inconsistent behavior in the compiler based on a race condition. This could
be fixed by having the compiler analyzing the files multiple times - once for each module they're imported from -
however, this could lead to slowdowns in compile times, and generally this kind of structure is indicative of a mistake
anyway.

```

$

foo.zig main.zig common.zig

$

// An empty file

$

// This is the root of the 'foo' module

pub const common = @import("common.zig");

$

// This file is the root of the main module

comptime {

  _ = @import("foo").common;

  _ = @import("common.zig");

}

$

common.zig:1:1: error: file exists in multiple modules

main.zig:4:17: note: imported from module root

  _ = @import("common.zig");

        ^~~~~~~~~~~~
foo.zig:2:28: note: imported from module root.foo

pub const common = @import("common.zig");

              ^~~~~~~~~~~~

```

Method call syntax only works when the first parameter of has a specific type: previously, this was either the type
containing the method, or a pointer to it. It is now additionally allowed for this type to be an optional pointer. The
value the method call is performed on must still be a non-optional pointer, but it is coerced to an optional pointer for
the method call.

There has been an for several years about the fact that Zig will emit all referenced functions to a binary, even if the
function is only used at compile-time. This can cause , as well as potentially triggering false positive compile errors
if a function is intended to only be used at compile-time.

As well as avoiding potential false positive compile errors, this change leads to a slight decrease in binary sizes, and
may slightly speed up compilation in some cases. Note that as a consequence of this change, it is no longer sufficient
to write to force a function to be analyzed and emitted to the binary. Instead, you must write .

```

```

0.10 had some arbitrary restrictions on the types of function parameters and their return types: they were not permitted
to be or . While these types are rarely useful in this context, they are still completely normal comptime-only types, so
this restriction on their usage was needless. As such, they are now allowed as parameter and return types.

As the note indicates, an explicit is not needed at the end of a naked function anymore. Since explicit returns are no
longer allowed, it will just be assumed to be unreachable. Therefore, all that needs to be done is to delete the
statement, which works even when the return type of the function is not .

The Allocator interface now allows implementations to refuse to shrink (). This makes ArrayList more efficient because
it avoids copying allocated but unused bytes by attempting a resize in place, and falling back to allocating a new
buffer and doing its own copy. With a realloc() call, the allocator implementation would pointlessly copy the extra
capacity:

We could remove these functions entirely in favor of other existing functions in std.mem such as std.mem.sliceTo(), but
that would be a somewhat nasty breaking change as std.mem.span() is very widely used for converting sentinel terminated
pointers to slices. It is however not at all widely used for anything else.

Sorting is now split into two categories: stable and unstable. Generally, it's best to use unstable if you can, but
stable is a more conservative choice. Zig's stable sort remains a blocksort implementation, while unstable sort is a new
pdqsort implementation. heapsort is also available in the standard library ().

The more recent TurboSHAKE variant is also available, as and . TurboSHAKE benefits from the extensive analysis of SHA-3,
its output can also be of any length, and it has good performance across all platforms. In fact, on CPUs without SHA-256
acceleration, and when using WebAssembly, TurboSHAKE is the fastest function we have in the standard library. If you
need a modern, portable, secure, overall fast hash function / XOF, that is not vulnerable to length-extension attacks
(unlike SHA-256), TurboSHAKE should be your go-to choice.

`SIGPIPE` is triggered when a process attempts to write to a broken pipe. By default, SIGPIPE will terminate the process
without giving the program an opportunity to handle the situation. Unlike a segfault, it doesn't trigger the panic
handler so all the developer sees is that the program terminated with no indication as to why.

When something goes wrong in your program, at the very least you expect it to output a stack trace. In many cases, upon
seeing the stack trace, the error is obvious and can be fixed without needing to attach a debugger. If you are a project
maintainer, having correct stack trace output is a necessity for your users to be able to provide actionable bug reports
when something goes wrong.

In order to print a stack trace, the panic (or segfault) handler needs to unwind the stack, by traversing back through
the stack frames starting at the crash site. Up until now, this was done strictly by utilizing the . This method of
stack unwinding works assuming that a frame pointer is available, which isn't the case if the code is compiled without
one - ie. if was used.

It can be beneficial for performance reasons to not use a frame pointer, since this frees up an additional register, so
some software maintainers may choose to ship libraries compiled without it. One of the motivating reasons for this
change was solving a bug where unwinding a stack trace that started in Ubuntu's libc wasn't working - and indeed it is
compiled with .

In order to save space, DWARF unwind tables aren't program-sized lookup tables, but instead sets of opcodes which run on
a virtual machine inside the unwinder to build the lookup table dynamically. Additionally, these tables can define
register values in terms of DWARF expressions, which is a separate stack-machine based bytecode. This is all supported
in the new unwinder.

```

Segmentation fault at address 0x1234

../sysdeps/x86_64/multiarch/strlen-avx2.S:74:0: 0x7fefd03b297d in ??? (../sysdeps/x86_64/multiarch/strlen-avx2.S)

./libio/ioputs.c:35:16: 0x7fefd0295ee7 in _IO_puts (ioputs.c)

src/lib.c:8:5: 0x7fefd04484aa in add_mult3 (/home/user/temp/stack/src/lib.c)

  puts((const char*)0x1234);

  ^

src/lib.c:13:12: 0x7fefd0448542 in add_mult2 (/home/user/temp/stack/src/lib.c)

  return add_mult3(x, y, n);

      ^
src/lib.c:17:12: 0x7fefd0448572 in add_mult1 (/home/user/temp/stack/src/lib.c)

  return add_mult2(x, y, n);

      ^
src/lib.c:21:12: 0x7fefd04485a2 in add_mult (/home/user/temp/stack/src/lib.c)

  return add_mult1(x, y, n);

      ^
/home/user/temp/stack/src/main.zig:6:45: 0x2123b7 in main (main)

  std.debug.print("add: {}\n", .{ add_mult(5, 3, null) });

                      ^
/home/user/kit/zig/build-stage3-release-linux/lib/zig/std/start.zig:608:37: 0x2129b4 in main (main)

      const result = root.main() catch |err| {
                  ^
../sysdeps/nptl/libc_start_call_main.h:58:16: 0x7fefd023ed8f in __libc_start_call_main (../sysdeps/x86/libc-start.c)

../csu/libc-start.c:392:3: 0x7fefd023ee3f in __libc_start_main_impl (../sysdeps/x86/libc-start.c)

???:?:?: 0x212374 in ??? (???)

???:?:?: 0x0 in ??? (???)

Aborted

```

If there is no unwind information available for a given frame, the unwinder will fall back to frame pointer unwinding
for the rest of the stack trace. For example, if the above program is built for x86-linux-gnu on the same system (which
only has x86_64 libc debug information installed), it results in the following output:

This system works for both panic traces as well as segfaults. In the case of a segfault, the OS will pass a context
(containing the state of all the registers at the time of the segfault) to the handler, which will be used by the
unwinder. In the case of a panic, the unwinder still needs a register context, so one is captured by the panic handler.
If the program is linking libc, then libc's is used, otherwise an implementation in is used if available. On platforms
where isn't available, the stack unwinder falls back to frame pointer based unwinding.

The ELF format allows for splitting debug information sections into separate files. If the user of the software does not
typically need to debug it, then debug info can be shipped an as optional dependency to reduce the size of the
installation. A primary use case for this feature is libc debug information, which can be quite large. Some
distributions have a separate package that contains only the debug info for their libc, which can be installed
separately.

The depth of / nesting in the output of is now 256. Now that the implementation of uses a , we have safety checks for
matching to and such, which requires memory: 1 bit per nesting level. To disable syntax checks and save that memory, use
. To make syntax checks available to custom implementations to arbitrary nesting depth, use and provide an allocator.

The posix_spawn behavior means the zig build runner can't tell the difference between a failure to run a foreign binary,
and a binary that did run, but failed in some other fashion. This is unacceptable, because attempting to execve is the
proper way to support things like Rosetta.

Zig 0.11 is the début of the official package manager. The package manager is still in its early stages, but is mature
enough to use in many cases. There is no "official" package repository: packages are simply arbitrary directory trees
which can be local directories or archives from the Internet.

Package information is declared in a file named . ZON (Zig Object Notation) is a simple data interchange format
introduced in this release cycle, which uses Zig's anonymous struct and array initialization syntax to declare objects
in a manner similar to other formats such as JSON. The file for a package should look like this:

The information provided is the package name and version, and a list of dependencies, each of which has a name, a URL to
an archive, and a hash. The hash is not of the archive itself, but of its contents. In order to find it, it can be
omitted from the file, and will emit an error containing the expected hash. There will be tooling in future to make this
file easier to modify.

This information is provided in a separate file (rather than declared in the script) to speed up the package manager by
allowing package fetching to happen without the need to build and run the build script. This also allows tooling to
observe dependency graphs without having to execute potentially dangerous code.

Every dependency can expose a collection of and from itself. The function creates a new Zig module which is publicly
exposed from your package; i.e. one which dependant packages can use. (To create a private module, instead use .)
Regarding binary artifacts, any artifact which is (for instance, via ) is exposed to dependant packages.

Both and take a parameter . This is an anonymous struct containing arbitrary arguments to pass to the build script,
which it can access as if they were passed to the script through flags (through . Options from the current package are
not implicitly provided to dependencies, and must be explicitly forwarded where required.

```

```

Some planned features include optional dependencies, better support for binary dependencies, the ability to construct a
from an arbitrary file from a dependency, improved tooling, and more. However, the package manager is in a state where
it is usable for some projects, particularly simple pure-Zig projects.

Previously, when the build system invoked the Zig compiler, it simply forwarded stderr to the terminal, so the user
could see any errors. This solution limits the possibility of integration between the build system and the compiler.
Therefore, the build system now communicates information to the compiler using a binary protocol.

The usage of this compiler protocol does mean there can be a small time delay between something like a compilation error
occurring and it being reported by , however it has the advantage of allowing the build system to receive much more
detailed information about the build, allowing for functionality like the .

```

--summary [mode]       Control the printing of the build summary

  all             Print the build summary in its entirety

  failures          (Default) Only print failed steps

  none            Do not print the build summary

```

```

Build Summary: 67/80 steps succeeded; 13 skipped; 36653/39320 tests passed; 2667 skipped

test-behavior success

├─ run test behavior-native-Debug cached

│ └─ zig test Debug native cached 21s MaxRSS:52M

├─ run test behavior-native-Debug-libc cached

│ └─ zig test Debug native cached 21s MaxRSS:52M

├─ run test behavior-native-Debug-single cached

│ └─ zig test Debug native cached 20s MaxRSS:52M

├─ run test behavior-native-Debug-libc-cbe 1666 passed 113 skipped 16ms MaxRSS:20M

│ └─ zig build-exe behavior-native-Debug-libc-cbe Debug native success 16s MaxRSS:731M

│   └─ zig test Debug native success 21s MaxRSS:134M

├─ run test behavior-x86_64-linux-none-Debug-selfhosted 1488 passed 291 skipped 29ms MaxRSS:17M

│ └─ zig test Debug x86_64-linux-none success 1s MaxRSS:115M

├─ run test behavior-wasm32-wasi-Debug-selfhosted 1441 passed 342 skipped 639ms MaxRSS:51M

│ └─ zig test Debug wasm32-wasi success 718ms MaxRSS:115M

├─ run test behavior-x86_64-macos-none-Debug-selfhosted skipped

│ └─ zig test Debug x86_64-macos-none success 21s MaxRSS:121M

├─ run test behavior-x86_64-windows-gnu-Debug-selfhosted skipped

│ └─ zig test Debug x86_64-windows-gnu success 2s MaxRSS:114M

├─ run test behavior-wasm32-wasi-Debug 1674 passed 109 skipped 2s MaxRSS:83M

│ └─ zig test Debug wasm32-wasi cached 20ms MaxRSS:51M

├─ run test behavior-wasm32-wasi-Debug-libc 1674 passed 109 skipped 1s MaxRSS:93M

│ └─ zig test Debug wasm32-wasi cached 8ms MaxRSS:51M

├─ run test behavior-x86_64-linux-none-Debug cached

│ └─ zig test Debug x86_64-linux-none cached 24ms MaxRSS:52M

├─ run test behavior-x86_64-linux-gnu-Debug-libc skipped

│ └─ zig test Debug x86_64-linux-gnu success 13s MaxRSS:440M

├─ run test behavior-x86_64-linux-musl-Debug-libc 1698 passed 91 skipped 353ms MaxRSS:17M

│ └─ zig test Debug x86_64-linux-musl success 13s MaxRSS:439M

├─ run test behavior-x86-linux-none-Debug 1693 passed 96 skipped 20ms MaxRSS:20M

│ └─ zig test Debug x86-linux-none success 21s MaxRSS:436M

├─ run test behavior-x86-linux-musl-Debug-libc 1693 passed 96 skipped 26ms MaxRSS:19M

│ └─ zig test Debug x86-linux-musl success 20s MaxRSS:454M

├─ run test behavior-x86-linux-gnu-Debug-libc skipped

│ └─ zig test Debug x86-linux-gnu success 21s MaxRSS:462M

├─ run test behavior-aarch64-linux-none-Debug 1687 passed 102 skipped 2s MaxRSS:31M

│ └─ zig test Debug aarch64-linux-none success 16s MaxRSS:449M

├─ run test behavior-aarch64-linux-musl-Debug-libc 1687 passed 102 skipped 1s MaxRSS:34M

│ └─ zig test Debug aarch64-linux-musl success 17s MaxRSS:457M

├─ run test behavior-aarch64-linux-gnu-Debug-libc skipped

│ └─ zig test Debug aarch64-linux-gnu success 14s MaxRSS:457M

├─ run test behavior-aarch64-windows-gnu-Debug-libc skipped

│ └─ zig test Debug aarch64-windows-gnu success 14s MaxRSS:402M

├─ run test behavior-arm-linux-none-Debug 1686 passed 103 skipped 737ms MaxRSS:29M

│ └─ zig test Debug arm-linux-none cached 12ms MaxRSS:51M

├─ run test behavior-arm-linux-musleabihf-Debug-libc 1686 passed 103 skipped 768ms MaxRSS:31M

│ └─ zig test Debug arm-linux-musleabihf cached 12ms MaxRSS:52M

├─ run test behavior-mips-linux-none-Debug 1686 passed 103 skipped 447ms MaxRSS:36M

│ └─ zig test Debug mips-linux-none success 25s MaxRSS:454M

├─ run test behavior-mips-linux-musl-Debug-libc 1686 passed 103 skipped 417ms MaxRSS:39M

│ └─ zig test Debug mips-linux-musl success 28s MaxRSS:471M

├─ run test behavior-mipsel-linux-none-Debug 1688 passed 101 skipped 406ms MaxRSS:34M

│ └─ zig test Debug mipsel-linux-none success 23s MaxRSS:454M

├─ run test behavior-mipsel-linux-musl-Debug-libc 1688 passed 101 skipped 751ms MaxRSS:37M

│ └─ zig test Debug mipsel-linux-musl cached 14ms MaxRSS:53M

├─ run test behavior-powerpc-linux-none-Debug 1687 passed 102 skipped 849ms MaxRSS:31M

│ └─ zig test Debug powerpc-linux-none cached 13ms MaxRSS:51M

├─ run test behavior-powerpc-linux-musl-Debug-libc 1687 passed 102 skipped 782ms MaxRSS:32M

│ └─ zig test Debug powerpc-linux-musl cached 8ms MaxRSS:51M

├─ run test behavior-powerpc64le-linux-none-Debug 1690 passed 99 skipped 758ms MaxRSS:31M

│ └─ zig test Debug powerpc64le-linux-none cached 12ms MaxRSS:51M

├─ run test behavior-powerpc64le-linux-musl-Debug-libc 1690 passed 99 skipped 542ms MaxRSS:31M

│ └─ zig test Debug powerpc64le-linux-musl cached 9ms MaxRSS:51M

├─ run test behavior-powerpc64le-linux-gnu-Debug-libc skipped

│ └─ zig test Debug powerpc64le-linux-gnu cached 11ms MaxRSS:51M

├─ run test behavior-riscv64-linux-none-Debug 1689 passed 100 skipped 669ms MaxRSS:28M

│ └─ zig test Debug riscv64-linux-none cached 7ms MaxRSS:49M

├─ run test behavior-riscv64-linux-musl-Debug-libc 1689 passed 100 skipped 711ms MaxRSS:30M

│ └─ zig test Debug riscv64-linux-musl cached 7ms MaxRSS:51M

├─ run test behavior-x86_64-macos-none-Debug skipped

│ └─ zig test Debug x86_64-macos-none cached 20s MaxRSS:51M

├─ run test behavior-aarch64-macos-none-Debug skipped

│ └─ zig test Debug aarch64-macos-none cached 7ms MaxRSS:49M

├─ run test behavior-x86-windows-msvc-Debug skipped

│ └─ zig test Debug x86-windows-msvc cached 7ms MaxRSS:50M

├─ run test behavior-x86_64-windows-msvc-Debug skipped

│ └─ zig test Debug x86_64-windows-msvc cached 21s MaxRSS:51M

├─ run test behavior-x86-windows-gnu-Debug-libc skipped

│ └─ zig test Debug x86-windows-gnu cached 7ms MaxRSS:50M

└─ run test behavior-x86_64-windows-gnu-Debug-libc skipped

  └─ zig test Debug x86_64-windows-gnu cached 7ms MaxRSS:52M

```

Zig build scripts are, by default, run by , a program distributed with Zig. In some cases, such as for custom tooling
which wishes to observe the step graph, it may be useful to override the build runner to a different Zig file. This is
now possible using the option .

The Zig build system is now capable of running multiple build steps in parallel. The build runner analyzes the build
step graph, and runs steps in a thread pool, with a default thread count corresponding to the number of CPU cores
available for optimal CPU utilization. The number of threads used can be changed with the option.

The build system contains a type called (formerly ) which allows depending on a file or directory which originates from
one of many sources: an absolute path, a path relative to the build runner's working directory, or a build artifact. The
build system now makes extensive use of anywhere we reference an arbitrary path.

```

-fdarling, -fno-darling   Integration with system-installed Darling to
                execute macOS programs on Linux hosts
                (default: no)
 -fqemu,   -fno-qemu    Integration with system-installed QEMU to execute
                foreign-architecture programs on Linux hosts
                (default: no)
 --glibc-runtimes [path]   Enhances QEMU integration by providing glibc built

                for multiple foreign architectures, allowing
                execution of non-native programs that link with glibc.
 -frosetta, -fno-rosetta   Rely on Rosetta to execute x86_64 programs on
                ARM64 macOS hosts. (default: no)
 -fwasmtime, -fno-wasmtime  Integration with system-installed wasmtime to
                execute WASI binaries. (default: no)
 -fwine,   -fno-wine    Integration with system-installed Wine to execute
                Windows programs on Linux hosts. (default: no)
```

The Zig compiler has several code backends. The primary one in usage today is the LLVM backend, which emits LLVM IR in
order to emit highly optimized binaries. However, this release cycle also saw major improvements to many of our "self-
hosted" backends, most notably the which is now passing the vast majority of behavior tests. Improvements to these
backends is key to reaching the goal of .

Besides those language features, the WebAssembly backend now also uses the regular logic as well as the standard test-
runner. This is a big step as the default test-runner logic uses a client-server architecture, requiring a lot of the
language to be implemented for it to work. This will also help us further with completing the WebAssembly backend as the
test-runner provides us with more details about which test failed.

This release cycle saw significant improvement of the self-hosted SPIR-V backend. SPIR-V is a bytecode representation
for shaders and kernels that run on GPUs. For now, the SPIR-V backend of Zig is focused on generating code for OpenCL
kernels, though Vulkan compatible shaders may see support in the future too.

While still a highly WIP feature, this release cycle saw many improvements paving the way to incremental compilation
capabilities in the compiler. One of the most significant was the . This change is mostly invisible to Zig users, but
brings many benefits to the compiler, amongst them being that we are now much closer to incremental compilation. This is
because this changeset brings new in-memory representations to many internal compiler datastructures (most notably types
and values) which are trivially serializable to disk, a requirement for incremental compilation.

defines a module with a given name, dependency list, and root source file. specifies the list of dependencies of the
main module. These options are not order-dependant. This defines modules in a "flat" manner, and specifies dependencies
indirectly, allowing dependency loops and shared dependencies. The name of a dependency can optionally be overridden
from the "default" name in the dependency string.

  * when finding by address, note the end of section symbols too - previously, if we were looking for the very last symbol by address in some section, and the next symbol happened to also have the same address value but would reside in a different section, we would keep going finding the wrong symbol in the wrong section. This mechanism turns out vital for correct linking of Go binaries where the runtime looks for specially crafted synthetic symbols which mark the beginning and end of each section. In this case, we had an unfortunate clash between the end of PC marked machine code section () and beginning of read-only data ().

During this release, a lot of work has gone into the in-house WebAssembly linker. The biggest feature it gained was the
support of the feature. This allows multiple WebAssembly modules to access the same memory. This feature opens support
for multi-threading in WebAssembly. This also required us to implement support for Thread-Local Storage. The linker is
now fully capable of linking with , also. Users can now make use of the in-house linker by supplying the flag to your
CLI invocation.

We are closer than ever to replace LLVM's linker wasm-ld with our in-house linker. The last feature to implement for
statically built WebAssembly modules is garbage collection. This ensures unreferenced symbols get removed from the final
binary keeping the binaries small in disk size. Once implemented, we can make the in-house linker the default linker
when building a WebAssembly module and gather feedback and fix any bugs that haven't been found yet. We can then start
working on other features such as dynamic-linking support and any future proposals.

```

-search_paths_first      For each library search path, check for dynamic
                lib then static lib before proceeding to next path.
-search_paths_first_static   For each library search path, check for static
                lib then dynamic lib before proceeding to next path.
-search_dylibs_first      Search for dynamic libs in all library search
                paths, then static libs.
-search_static_first      Search for static libs in all library search
                paths, then dynamic libs.
-search_dylibs_only      Only search for dynamic libs.
-search_static_only      Only search for static libs.

```

Zig ships with the source code to . When the musl C ABI is selected, Zig builds static musl from source for the selected
target. Zig also supports targeting dynamically linked musl which is useful for Linux distributions that use it as their
system libc, such as .

If there are linker warnings when compiling software, the first thing we have to do is add support for ones linker is
complaining, and only then go file issues. If Zig "successfully" (i.e. status code = 0) compiles a binary, there is
instead a tendency to blame "Zig doing something weird". Adding the unsupported arguments is straightforward; see , ,
for examples.

One thing that trips people up when they use this feature is that the , so always remember the rule: You must use the
same C++ compiler to compile your objects and static libraries. This is an unfortunate limitation of C++ which Zig can
never fix.



---

## https://ziglang.org/download/0.12.0/release-notes.html

In the past, these release notes have been extremely long, attempting to take note of all enhancements that occurred
during the release cycle. In the interest of not overwhelming the reader as well as the maintainers creating these
notes, this document is abridged. Many changes, including API breaking changes, are not mentioned here.

A green check mark (✅) indicates the target meets all the requirements for the support tier. The other icons indicate
what is . In other words, the icons are . If you find any wrong data here please !

  * All the behavior tests and applicable standard library tests pass for this target. All language features are known to work correctly. Experimental features do not count towards disqualifying an operating system or architecture from Tier 1. The 🐛 icon means there are known preventing this target from reaching Tier 1. 

  * The supports this target, but it is possible that some APIs will give an "Unsupported OS" compile error. One can link with libc or other libraries to fill in the gaps in the standard library. The 📖 icon means the standard library is too incomplete to be considered Tier 2 worthy.

  * If this target is provided by LLVM, LLVM may have the target as an experimental target, which means that you need to use Zig-provided binaries for the target to be available, or build LLVM from source with special configure flags. will display the target if it is available.

The HTTP server creates the requested files on the fly, including rebuilding if any of its source files changed, and
constructing , meaning that any source changes to the documented files, are immediately reflected when viewing docs.
Prefixing the URL with results in a debug build of the WebAssembly module.

```

Benchmark 1 (3 runs): old/zig test /home/andy/dev/zig/lib/std/std.zig -fno-emit-bin -femit-docs=docs

 measurement     mean ± σ      min … max      outliers     delta

 wall_time     13.3s ± 405ms  12.8s … 13.6s      0 ( 0%)    0%

 peak_rss      1.08GB ± 463KB  1.08GB … 1.08GB     0 ( 0%)    0%

 cpu_cycles     54.8G ± 878M   54.3G … 55.8G      0 ( 0%)    0%

 instructions    106G ± 313K   106G … 106G      0 ( 0%)    0%

 cache_references  2.11G ± 35.4M   2.07G … 2.14G      0 ( 0%)    0%

 cache_misses    41.3M ± 455K   40.8M … 41.7M      0 ( 0%)    0%

 branch_misses    116M ± 67.8K   116M … 116M      0 ( 0%)    0%

Benchmark 2 (197 runs): new/zig build-obj -fno-emit-bin -femit-docs=docs ../lib/std/std.zig

 measurement     mean ± σ      min … max      outliers     delta

 wall_time     24.6ms ± 1.03ms  22.8ms … 28.3ms     4 ( 2%)    ⚡- 99.8% ± 0.3%

 peak_rss      87.3MB ± 60.6KB  87.2MB … 87.4MB     0 ( 0%)    ⚡- 91.9% ± 0.0%

 cpu_cycles     38.4M ± 903K   37.4M … 46.1M     13 ( 7%)    ⚡- 99.9% ± 0.2%

 instructions    39.7M ± 12.4K   39.7M … 39.8M      0 ( 0%)    ⚡-100.0% ± 0.0%

 cache_references  2.65M ± 89.1K   2.54M … 3.43M      3 ( 2%)    ⚡- 99.9% ± 0.2%

 cache_misses    197K ± 5.71K   186K … 209K      0 ( 0%)    ⚡- 99.5% ± 0.1%

 branch_misses    184K ± 1.97K   178K … 190K      6 ( 3%)    ⚡- 99.8% ± 0.0%

```

The previous implementation implemented scroll history in JavaScript, which is impossible to do correctly. The new
system makes careful use of the 'popstate' event combined with the history API to scroll to the top of the window only
when the user navigates to a new link - respecting the browser's saved scroll history in all other cases.

```

 std = ();

 assert = std.debug.assert;

 expectEqual = std.testing.expectEqual;

  {

   z:  = ;

   x,  y, z = []{ , ,  };

  y += ;

   expectEqual(, x);

   expectEqual(, y);

   expectEqual(, z);

}

  {

  
   x,  y = (, ){ ,  };

   assert(x == );

   assert(y == );

}

  {

   runtime:  = ;

  runtime = ;

   x,  y = .{ , runtime };

  
  
   assert(x == );

   expectEqual(, y);

}

```

The "captures" of a type refers to the set of comptime-known types and values which it closes over. In other words, it
is the set of values referenced within the type but declared outside of it. For instance, the parameter of is captured
by the type it returns. If two namespace types are declared by the same piece of code and have the same captures, they
are now considered to be precisely the same type.

In Zig 0.11.0, this code would create two distinct types, because the calls to are distinct and thus the declaration was
analyzed separately for each call. In Zig 0.12.0, these types are identical (), because while the function is called
twice, the declaration does not capture any value.

This restriction was put in place to fix some soundness bugs. When a pointer to a becomes runtime-known, mutations to it
become invalid since the pointed-to data becomes constant, but the type system fails to reflect this, leading to the
potential for runtime segmentation faults in what appears to be valid code. In addition, the value you read from such a
pointer at runtime would be its "final" comptime value, which was an unintuitive behavior. Thus, these pointers can no
longer be runtime-known.

This code raises the same compile error as the previous example. This restriction has been put in place primarily to aid
the implementation of incremental compilation in the Zig compiler, which depends on the fact that analysis of global
declarations is order-independent, and the dependencies between declarations can be easily modeled.

↓

Previous releases of Zig included an builtin which performed a safety-checked cast from one error set to another,
potentially smaller, one. In Zig 0.12.0, this builtin is replaced with . Previous uses will continue to work, but in
addition, this new builtin can cast the error set of an error :

On Windows, the command line arguments of a program are a single encoded string and it's up to the program to split it
into an array of strings. In C/C++, the entry point of the C runtime takes care of splitting the command line and
passing argc/argv to the main function.

This release updates Zig's command line splitting to match , which ensures consistent behavior between Zig and modern
C/C++ programs on Windows. Additionally, the suggested mitigation for relies on the post-2008 C runtime splitting
behavior for roundtripping of the arguments given to cmd.exe.

↓

Instead, some headers are provided via explicit field names populated while parsing the HTTP request/response, and some
are provided via new fields that support passing extra, arbitrary headers. This resulted in simplification of logic in
many places, as well as elimination of the possibility of failure in many places. There is less deinitialization code
happening now. Furthermore, it made it no longer necessary to clone the headers data structure in order to handle
redirects.

The new code uses static allocations for all structures, doesn't require allocator. That makes sense especially for
deflate where all structures, internal buffers are allocated to the full size. Little less for inflate where the
previous verision used less memory by not preallocating to theoretical max size array which are usually not fully used.

```

 std = ();

 data = ();

  () ! {

   gpa = std.heap.GeneralPurposeAllocator(.{}){};

   std.debug.assert(gpa.deinit() == .ok);

   allocator = gpa.allocator();

   oldDeflate(allocator);

   new(std.compress.flate, allocator);

   oldZlib(allocator);

   new(std.compress.zlib, allocator);

   oldGzip(allocator);

   new(std.compress.gzip, allocator);

}

  ( pkg: , allocator: std.mem.Allocator) ! {

   buf = std.ArrayList().init(allocator);

   buf.deinit();

  
   cmp =  pkg.compressor(buf.writer(), .{});

  _ =  cmp.write(data);

   cmp.finish();

   fbs = std.io.fixedBufferStream(buf.items);

  
   dcp = pkg.decompressor(fbs.reader());

   plain =  dcp.reader().readAllAlloc(allocator, std.math.maxInt());

   allocator.free(plain);

   std.testing.expectEqualSlices(, data, plain);

}

  (allocator: std.mem.Allocator) ! {

   deflate = std.compress.v1.deflate;

  
   buf = std.ArrayList().init(allocator);

   buf.deinit();

  
  
   cmp =  deflate.compressor(allocator, buf.writer(), .{});

  _ =  cmp.write(data);

   cmp.close();

  cmp.deinit();

  
   fbs = std.io.fixedBufferStream(buf.items);

  
  
  
   dcp =  deflate.decompressor(allocator, fbs.reader(), );

   dcp.deinit();

   plain =  dcp.reader().readAllAlloc(allocator, std.math.maxInt());

   allocator.free(plain);

   std.testing.expectEqualSlices(, data, plain);

}

  (allocator: std.mem.Allocator) ! {

   zlib = std.compress.v1.zlib;

   buf = std.ArrayList().init(allocator);

   buf.deinit();

  
  
  
   cmp =  zlib.compressStream(allocator, buf.writer(), .{});

  _ =  cmp.write(data);

   cmp.finish();

  cmp.deinit();

   fbs = std.io.fixedBufferStream(buf.items);

  
  
  
  
   dcp =  zlib.decompressStream(allocator, fbs.reader());

   dcp.deinit();

   plain =  dcp.reader().readAllAlloc(allocator, std.math.maxInt());

   allocator.free(plain);

   std.testing.expectEqualSlices(, data, plain);

}

  (allocator: std.mem.Allocator) ! {

   gzip = std.compress.v1.gzip;

   buf = std.ArrayList().init(allocator);

   buf.deinit();

  
  
  
   cmp =  gzip.compress(allocator, buf.writer(), .{});

  _ =  cmp.write(data);

   cmp.close();

  cmp.deinit();

   fbs = std.io.fixedBufferStream(buf.items);

  
  
  
  
   dcp =  gzip.decompress(allocator, fbs.reader());

   dcp.deinit();

   plain =  dcp.reader().readAllAlloc(allocator, std.math.maxInt());

   allocator.free(plain);

   std.testing.expectEqualSlices(, data, plain);

}

```

```

  tc_lflag_t =  (native_arch) {

  .powerpc, .powerpcle, .powerpc64, .powerpc64le =>  () {

    _0:  = ,
    ECHOE:  = ,
    ECHOK:  = ,
    ECHO:  = ,
    ECHONL:  = ,
    _5:  = ,
    ISIG:  = ,
    ICANON:  = ,
    _9:  = ,
    IEXTEN:  = ,
    _11:  = ,
    TOSTOP:  = ,
    _23:  = ,
    NOFLSH:  = ,
  },

  .mips, .mipsel, .mips64, .mips64el =>  () {

    ISIG:  = ,
    ICANON:  = ,
    _2:  = ,
    ECHO:  = ,
    ECHOE:  = ,
    ECHOK:  = ,
    ECHONL:  = ,
    NOFLSH:  = ,
    IEXTEN:  = ,
    _9:  = ,
    TOSTOP:  = ,
    _:  = ,
  },

   =>  () {

    ISIG:  = ,
    ICANON:  = ,
    _2:  = ,
    ECHO:  = ,
    ECHOE:  = ,
    ECHOK:  = ,
    ECHONL:  = ,
    NOFLSH:  = ,
    TOSTOP:  = ,
    _9:  = ,
    IEXTEN:  = ,
    _:  = ,
  },

};

```

```

  Options =  {

  enable_segfault_handler:  = debug.default_enable_segfault_handler,

  
  wasiCwd:  () os.wasi.fd_t = fs.defaultWasiCwd,

  
  log_level: log.Level = log.default_level,

  log_scope_levels: [] log.ScopeLevel = &.{},

  logFn:  (

     message_level: log.Level,
     scope: (.enum_literal),
     format: [] ,
    args: ,
  )  = log.defaultLog,

  fmt_max_depth:  = fmt.default_max_depth,

  cryptoRandomSeed:  (buffer: [])  = ().defaultRandomSeed,

  crypto_always_getrandom:  = ,

  crypto_fork_safety:  = ,

  
  
  
  
  
  
  
  
  
  
  
  keep_sigpipe:  = ,

  
  
  
  
  
  http_disable_tls:  = ,

  side_channels_mitigations: crypto.SideChannelsMitigations = crypto.default_side_channels_mitigations,

};

```

```

$

$

thread 223429 panic: reached unreachable code

:

  if (!ok) unreachable; // assertion failure

       
:

    assert(l.state == .unlocked);
       
:

        self.pointer_stability.lock();
                      
:

      const gop = try self.getOrPutContextAdapted(allocator, key, ctx, ctx);
                            
:

      const result = try self.getOrPutContext(allocator, key, ctx);
                          
:

      return self.putContext(allocator, key, value, undefined);
                 
:

  try m.put(gpa, 42, 420);

       
:

  gop.value_ptr.* = try calculate(gpa, &map);

                  
:

      const result = root.main() catch |err| {
                  
:

  asm volatile (switch (native_arch) {

  
:

(process terminated by signal)

```

```

@@ -5,18 +5,8 @@ pub fn build(b: *std.Build) void {

   const optimize = b.standardOptimizeOption(.{

     .preferred_optimize_mode = .ReleaseSafe,
   });

   const use_llvm = b.option(bool, "use-llvm", "LLVM backend");



   b.installDirectory(.{

     .source_dir = .{ .path = "public" },
     .install_dir = .lib,
@@ -31,7 +21,22 @@ pub fn build(b: *std.Build) void {

     .use_llvm = use_llvm,
     .use_lld = use_llvm,
   });

   b.installArtifact(server);



   const run_cmd = b.addRunArtifact(server);

```

```

System Integration Options:

 --system [dir]        System Package Mode. Disable fetching; prefer system libs

 -fsys=[name]         Enable a system integration
 -fno-sys=[name]       Disable a system integration
 Available System Integrations:        Enabled:

  groove                   no

  z                      no

  mp3lame                   no

  vorbis                   no

  ogg                     no

```

```

andy@ark ~/d/a/zlib (main)> zig build --release

the project does not declare a preferred optimization mode. choose: --release=fast, --release=safe, or --release=small

error: the following build command failed with exit code 1:

/home/andy/dev/ayb/zlib/zig-cache/o/6f46a03cb0f5f70d2c891f31086fecc9/build /home/andy/Downloads/zig/build-
release/stage3/bin/zig /home/andy/dev/ayb/zlib /home/andy/dev/ayb/zlib/zig-cache /home/andy/.cache/zig --seed 0x3e999c60
--release

andy@ark ~/d/a/zlib (main) [1]> zig build --release=safe

andy@ark ~/d/a/zlib (main)> vim build.zig

andy@ark ~/d/a/zlib (main)> git diff

diff --git a/build.zig b/build.zig

index 76bbb01..1bc13e6 100644

--- a/build.zig
+++ b/build.zig

@@ -5,7 +5,9 @@ pub fn build(b: *std.Build) void {

   const lib = b.addStaticLibrary(.{

     .name = "z",
     .target = b.standardTargetOptions(.{}),
-    .optimize = b.standardOptimizeOption(.{}),
+    .optimize = b.standardOptimizeOption(.{
+      .preferred_optimize_mode = .ReleaseFast,
+    }),
   });

   lib.linkLibC();

   lib.addCSourceFiles(.{

andy@ark ~/d/a/zlib (main)> zig build --release

andy@ark ~/d/a/zlib (main)> zig build --release=small

andy@ark ~/d/a/zlib (main)>

```

```

[nix-shell:~/dev/2Pew]$ zig build --system ~/tmp/p -fno-sys=SDL2

error: lazy dependency package not found:
/home/andy/tmp/p/1220c5360c9c71c215baa41b46ec18d0711059b48416a2b1cf96c7c2d87b2e8e4cf6

info: remote package fetching disabled due to --system mode

info: dependencies might be avoidable depending on build configuration

[nix-shell:~/dev/2Pew]$ zig build --system ~/tmp/p

[nix-shell:~/dev/2Pew]$ mv ~/.cache/zig/p/1220c5360c9c71c215baa41b46ec18d0711059b48416a2b1cf96c7c2d87b2e8e4cf6 ~/tmp/p

[nix-shell:~/dev/2Pew]$ zig build --system ~/tmp/p -fno-sys=SDL2

steps [5/8] zig build-lib SDL2 ReleaseFast native... Compile C Objects [75/128] e_atan2... ^C

[nix-shell:~/dev/2Pew]$

```

```

```

```

$

thread 2904684 panic: dependency 'groove' is marked as lazy in build.zig.zon which means it must use the lazyDependency
function instead

/home/andy/Downloads/zig/lib/std/debug.zig:434:22: 0x11901a9 in panicExtra__anon_18741 (build)

  std.builtin.panic(msg, trace, ret_addr);

           ^
/home/andy/Downloads/zig/lib/std/debug.zig:409:15: 0x1167399 in panic__anon_18199 (build)

  panicExtra(null, null, format, args);

       ^
/home/andy/Downloads/zig/lib/std/Build.zig:1861:32: 0x1136dca in dependency__anon_16705 (build)

        std.debug.panic("dependency '{s}{s}' is marked as lazy in build.zig.zon which means it must use the lazyDependency function instead", .{ b.dep_prefix, name });
                ^
/home/andy/dev/groovebasin/build.zig:33:40: 0x10e8865 in build (build)

    const groove_dep = b.dependency("groove", .{
                    ^
/home/andy/Downloads/zig/lib/std/Build.zig:1982:33: 0x10ca783 in runBuild__anon_8952 (build)

    .Void => build_zig.build(b),
                ^
/home/andy/Downloads/zig/lib/build_runner.zig:310:29: 0x10c6708 in main (build)

    try builder.runBuild(root);
              ^
/home/andy/Downloads/zig/lib/std/start.zig:585:37: 0x10af845 in posixCallMainAndExit (build)

      const result = root.main() catch |err| {
                  ^
/home/andy/Downloads/zig/lib/std/start.zig:253:5: 0x10af331 in _start (build)

  asm volatile (switch (native_arch) {

  ^

???:?:?: 0x8 in ??? (???)

Unwind information for `???:0x8` was not available, trace may be incomplete

error: the following build command crashed:

/home/andy/dev/groovebasin/zig-cache/o/20af710f8e0e96a0ccc68c47688b2d0d/build /home/andy/Downloads/zig/build-
release/stage3/bin/zig /home/andy/dev/groovebasin /home/andy/dev/groovebasin/zig-cache /home/andy/.cache/zig --seed
0x513e8ce9 -Z4472a09906216280 -h

```

↓ ↓ ↓

Zig 0.12.0 changes it so that installed headers are added to the compile step itself instead of modifying the top-level
install step. To handle the construction of the include search path for dependent linking modules, an intermediary step
responsible for constructing the appropriate include tree is created and set up the first time a module links to an
artifact.

↓ ↓ ↓

```

Benchmark 1 (8 runs): zig-0.12.0 build-exe hello.zig

 measurement     mean ± σ      min … max      outliers     delta

 wall_time      667ms ± 26.7ms   643ms … 729ms     1 (13%)    0%

 peak_rss      175MB ± 19.3MB   168MB … 223MB     1 (13%)    0%

 cpu_cycles     3.42G ± 532M   3.21G … 4.74G      1 (13%)    0%

 instructions    6.20G ± 1.05G   5.83G … 8.79G      1 (13%)    0%

 cache_references  241M ± 19.9M   234M … 291M      1 (13%)    0%

 cache_misses    48.3M ± 1.26M   47.7M … 51.4M      1 (13%)    0%

 branch_misses   35.3M ± 4.07M   33.7M … 45.4M      1 (13%)    0%

Benchmark 2 (26 runs): zig-0.12.0 build-exe hello.zig -fno-llvm -fno-lld

 measurement     mean ± σ      min … max      outliers     delta

 wall_time      196ms ± 5.77ms   187ms … 208ms     0 ( 0%)    ⚡- 70.6% ± 1.7%

 peak_rss      88.7MB ± 721KB  87.8MB … 90.4MB     2 ( 8%)    ⚡- 49.3% ± 4.3%

 cpu_cycles     842M ± 6.01M   836M … 866M      1 ( 4%)    ⚡- 75.4% ± 6.0%

 instructions    1.60G ± 9.62K   1.60G … 1.60G      0 ( 0%)    ⚡- 74.1% ± 6.5%

 cache_references  56.6M ± 378K   56.0M … 57.3M      0 ( 0%)    ⚡- 76.6% ± 3.2%

 cache_misses    8.43M ± 104K   8.30M … 8.79M      2 ( 8%)    ⚡- 82.5% ± 1.0%

 branch_misses   7.20M ± 30.2K   7.15M … 7.28M      2 ( 8%)    ⚡- 79.6% ± 4.4%

```

```

Benchmark 1 (61 runs): master/zig build-exe hello.c -target native-native-musl -lc

 measurement     mean ± σ      min … max      outliers     delta

 wall_time     81.4ms ± 1.76ms  77.7ms … 87.1ms     1 ( 2%)    0%

 peak_rss      64.6MB ± 77.7KB  64.4MB … 64.7MB     0 ( 0%)    0%

 cpu_cycles     97.2M ± 1.04M   95.1M … 101M      1 ( 2%)    0%

 instructions    153M ± 11.1K   152M … 153M      0 ( 0%)    0%

 cache_references  2.21M ± 97.1K   2.05M … 2.54M      2 ( 3%)    0%

 cache_misses    529K ± 24.4K   486K … 600K      4 ( 7%)    0%

 branch_misses    409K ± 6.45K   397K … 437K      1 ( 2%)    0%

Benchmark 2 (189 runs): cache-dedup/zig build-exe hello.c -target native-native-musl -lc

 measurement     mean ± σ      min … max      outliers     delta

 wall_time     25.8ms ± 1.26ms  23.9ms … 30.7ms     11 ( 6%)    ⚡- 68.4% ± 0.5%

 peak_rss      65.2MB ± 61.8KB  65.1MB … 65.4MB     2 ( 1%)    💩+ 1.0% ± 0.0%

 cpu_cycles     41.2M ± 608K   40.1M … 46.3M      4 ( 2%)    ⚡- 57.6% ± 0.2%

 instructions    64.3M ± 12.6K   64.3M … 64.4M      2 ( 1%)    ⚡- 57.8% ± 0.0%

 cache_references  1.28M ± 34.5K   1.21M … 1.35M      0 ( 0%)    ⚡- 41.9% ± 0.7%

 cache_misses    348K ± 18.6K   297K … 396K      0 ( 0%)    ⚡- 34.2% ± 1.1%

 branch_misses    199K ± 1.34K   197K … 206K      6 ( 3%)    ⚡- 51.2% ± 0.2%

```

Zig has had several long-standing bugs relating to accessing pointers at compile time. When attempting to access
pointers in a non-trivial way, such as loading a slice of an array or reinterpreting memory, you would at times be
greeted with a false positive compile error stating that the comptime dereference required a certain type to have a
well-defined layout.

The merge of resolves this issue. In Zig 0.12.0, the compiler should no longer emit incorrect compile errors when doing
complex things with comptime memory. This change also includes some fixes to the logic for comptime ; in particular,
bitcasting aggregates containing pointers no longer incorrectly forces the operation to occur at runtime.



---

## https://ziglang.org/download/0.13.0/release-notes.html



  * All the behavior tests and applicable standard library tests pass for this target. All language features are known to work correctly. Experimental features do not count towards disqualifying an operating system or architecture from Tier 1. The 🐛 icon means there are known preventing this target from reaching Tier 1. 

  * The supports this target, but it is possible that some APIs will give an "Unsupported OS" compile error. One can link with libc or other libraries to fill in the gaps in the standard library. The 📖 icon means the standard library is too incomplete to be considered Tier 2 worthy.

  * If this target is provided by LLVM, LLVM may have the target as an experimental target, which means that you need to use Zig-provided binaries for the target to be available, or build LLVM from source with special configure flags. will display the target if it is available.

This is a breaking change for direct users of the old polynomial api. Specifically when using a custom or non-standard
polynomial (the alias will continue to work). There are clear compile errors indicating what is required in order to
retain existing functionality, this may require a small code-change from the user.

```

crc32-slicing-by-8 # 8K of tables

  iterative: 3074 MiB/s [2d191d9400000000]

 small keys: 32B 4650 MiB/s 152387950 Hashes/s [20024c446a99a300]

crc32-half-byte-lookup # 64b of tables

  iterative:  281 MiB/s [2d191d9400000000]

 small keys: 32B  389 MiB/s 12751954 Hashes/s [20024c446a99a300]

crc32 # 1K of tables

  iterative: 3077 MiB/s [2d191d9400000000]

 small keys: 32B 4660 MiB/s 152709182 Hashes/s [20024c446a99a300]

```

  * Performance notes:

In the future there will be even more breaking changes. For example, instead of creating a Child and then setting fields
on it and then calling spawn, there will be which takes an "options" parameter and then returns the Child, which is an
object that lasts only from spawn until termination. This is a practice that we have been moving more towards in Zig,
which is to have types designed to have minimal lifetimes and minimal states with undefined fields.

The previous implementation of had the design limitation that it could not assume ownership of the terminal. This meant
that it had to play nicely with sub-processes purely via what was printed to the terminal, and it had to play nicely
with progress-unaware stderr writes to the terminal. It also was forbidden from installing a SIGWINCH handler, or
running ioctl to find out the rows and cols of the terminal.

The new implementation is designed around the idea that a single process will be the sole owner of the terminal, and all
other progress reports will be communicated back to that process. With this change in the requirements, it becomes
possible to make a much more useful progress bar.

This creates a standard "Zig Progress Protocol" and uses it so that the same API works both when an application is the
main owner of a terminal, and when an application is a child process. In the latter case, progress information is
communicated semantically over a pipe to the parent process.

In order to avoid performance penalty for using this API, the and APIs are thread-safe, lock-free, infallible, and do
minimal amount of memory loads and stores. In order to accomplish this, a statically allocated buffer of storage is used
- one array for parents, and one array for the rest of the data. Children are not stored. The statically allocated
buffer is used for a bespoke allocator implementation. A static buffer is sufficient because we can set an upper bound
on supported terminal width and height. If the terminal size exceeds this, the progress bar output will be truncated
regardless.

A separate thread periodically refreshes the terminal on a timer. This progress update thread iterates over the entire
preallocated parents array, looking for used nodes. This is efficient because the parents array is only 200 8-bit
integers, or about 4 cache lines. When iterating, this thread "serializes" the data into a separate preallocated array
by atomically loading from the shared data into data that is only touched by a single thread - the progress update
thread. It then looks for nodes that are marked with a file descriptor that is a pipe to a child process. Such nodes are
replaced during the serialization process with the data from reading from the pipe. The data can be memcpy'd into place
except for the parents array which needs to be relocated. Once this serialization process is complete, there are two
paths, one for a child process, and one for the root process that owns the terminal.

The root process that owns the terminal scans the serialized data, computing children and sibling pointers. The
canonical data only stores parents, so this is where the tree structure is computed. Then the tree is walked, appending
to a static buffer that will be sent to the terminal with a single write() syscall. During this process, the detected
rows and cols of the terminal are respected. If the user resizes the terminal, it will cause a SIGWINCH which signals
the update thread to wake up and redraw with the new rows and cols.

A child process, instead of drawing to the terminal, takes the same serialized data and sends it across a pipe. The pipe
is in non-blocking mode, so if it fills up, the child drops the message; a future update will contain the new progress
information. Likewise when the parent reads from the pipe, it discards all messages in the buffer except for the last
one. If there are no messages in the pipe, the parent uses the data from the last update.

> Causes the Run step to be considered to have side-effects, and therefore always execute when it appears in the build
> graph. It also means that this step will obtain a global lock to prevent other steps from running in the meantime. The
> step will fail if the subprocess crashes or returns a non-zero exit code.
When it comes to the inverse task of forcing color output even when not writing to a terminal, there exist two
standards, and . Neither of these two standards come even close to being as ubiquitous as , but they both have some
precedence and are respected by a handful of CLI tools.

Zig ships with the source code to . When the musl C ABI is selected, Zig builds static musl from source for the selected
target. Zig also supports targeting dynamically linked musl which is useful for Linux distributions that use it as their
system libc, such as .



---

