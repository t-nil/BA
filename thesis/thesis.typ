// # GLOBAL TODOS
// - [x] fix glossary keys being displayed when no short variant exists
// - [x] fix "ich/mein/mir/mich"
// # STYLE
// @löhr: deutsch passiviert / englisch "we"
// - https://academics.umw.edu/swc/files/2024/02/IEEE-Formatting-Guidelines.pdf
//   - capitalize headers
// - [ ] glossary ausformulieren
//
// # FINAL REFACTOR
// - grep for glossary/abbrev instances
// - "therefor"
// - "atleast"

#import "@preview/oxdraw:0.1.0": oxdraw as mermaid

// TODO use fletcher
// _löhr: github links, doku etc.: muss das in die bibliographie rein oder reichen fußnoten?
//  - wenn inhalt bezogen wird, in die bib.
// @löhr:
// -

#import "@preview/glossarium:0.5.10": gls, glspl, make-glossary, print-glossary, register-glossary
#show: make-glossary
#import "glossary.typ": glossary-list
#register-glossary(glossary-list)

#import "@local/ohm:0.1.0": thesis

// requirements:
// - author - dict{name, student-id}
// - examinors - dict{first, second}
// - every figure has a caption
#show: rest => {
  thesis(
    author: (name: "Florian Meißner", student-id: "3210376"),
    examinors: (first: "Prof. Dr. Hans Löhr", second: "Prof. Dr. Michael Zapf"),
    show_chapters: true,
  )[#rest]
}

= Introduction

- Rust is increasing usage in system level
- but still many big projects (linux etc.) are written in C


Since the beginning of computer programming, there has been a discrepancy between the input states an interface formally accepts, and the input states that are sound to handle.
For example, a reciprocal function $$ f(x) = 1/x $$ might formally accept a 32 bit integer --- and therefore all of its $$2 ^ 32$$ input states ---, but the mathematical formula it tries to model will not give a sensible result for $$ x = 0 $$; least of all if the function in turn returns an integer, since there is no integer $$ n: 1 / x = n $$.

One straightforward solution has always been to limit the function domain via documentation. Users of that function are expected to read that documentation and recognize that it is a violation of interface contract to call it with $$ x = 0 $$. Violation of that contract would in turn result in an error, a crash, or --- worse yet --- @UB:long. An approach with drawbacks, as there are now two sources of truth about the function domain. One of these --- the function signature, expressed in code --- is already technically incorrect, as we have not stated a way to express "integers without zero" as a valid type (@c_reciprocal). Additionally, as the program developes, the chance of both sources of truth to get further out-of-sync increases. For example, special behavior could be introduced to handle the undefined case by printing out errors. This discrepancy, between the high-level contract, expressible only in additional information in text form, and the function signature the compiler handles, raises the following question: Can we encode this precondition in such a way that the function signature makes it impossible to pass in values that violate any API contract?

#figure(
  ```c
  // `n` CANNOT BE ZERO!
  double reciprocal(int n) {
    if (n == 0) {
      crash(); // we warned you!
    }
    return (double) 1 / n;
  }
  ```,
  caption: [A typical C implementation of `reciprocal()`],
) <c_reciprocal>



// TODO maybe use contract programming thought model, and explain keywords (invariants, preconditions)

In programming languages where we have strict and strong typing /* TODO define */, we can enforce invariants about types we create, since we have to explicitly provide the methods of construction for these types, and we can make then fail if some invariants are not upheld. This allows us to express function signatures of the kind discussed previously, by creating a new type `NonZeroI32`@nonzeroi32_reciprocal that represents the idea of an integer that cannot be zero. By making the inner value private, we then ensure that users of our library are forced to use the only construction method we provide them with, ```rust NonZeroI32::new(i32)```. This `new()` function can be total, since it returns a result value representing a fallible computation. In that sense, the function signature of `new()` expresses that *every 32-bit integer is either a valid non-zero 32-bit integer or an error*.@nonzeroi32_reciprocal shows a possible implementation of this concept in Rust.

#figure(
  ```rust
  pub struct NonZeroI32(i32);

  impl NonZeroI32 {
    pub fn new(n: i32) -> Result<Self> {
      if n == 0 {
        Err("n == 0 is not allowed!")
      } else {
        Ok(n)
      }
    }
  }

  pub fn reciprocal(n: NonZeroI32) -> f64 {
    // ...
  }
  ```,
  caption: [A new type `NonZeroI32` that represents the idea of a 32-bit integer *guaranteed* to not be zero],
) <nonzeroi32_reciprocal>

// FIXME @löhr: kleiner Überblick über die Arbeit

// HOWTO bei der einleitung jmd vorstellen, der das thema nicht kennt, und eine schöne einführung will.

// MAYBE exkurs über linear types?

// unterschied zur motivation:
// - "eine ebene drüber, ungenauer"
// - FIXME löhr fragen: brauche ich beides, passt das so?
//   - ja, eher "background" nennen
//   - beides != hauptteil, nur das erklären was auch gebraucht wird
// - basics erklären: was ist {dateisystem,rust,typsystem,FUSE}?

@bugden2022rustprogramminglanguagesafety

= Background



== Rust
// TODO more sub headings?

// - Modern language with many features that can increase correctness and safety
// - is marketed/intended as a low level language, usually competes near C in benchmarks
//   - Rust in Linux kernel
//   - RedoxOS
//   - coreutils / libc rewrite
// - features
//   - borrow checker / lifetime tracking / ownership tracking
//   - strict types /* TODO define, quote */, (almost) no implicit conversions
//   - RAII / destructors / `Drop` trait
//   - no data races
//   - fearless concurrency // <-> data races?
//   - error handling
//   - ADTs / modeling complex types
//   - generics
//   - typestate pattern
// - Unsafe rust
//   - *what we keep, what we lose*
//   - additional promises to uphold
//   - (ausblick: additional tools, static analysis, sanitizers etc.)

== FUSE
// - filesystem as process in userspace
// - don't have to build kernel modules (safer, easier dev workflow)
// - should be comparable though (why? give reasons)
// - architecture (/* TODO image */)
//   - fuse kernel module
//   - libfuse
//   - FS impl
//   - *=> our layer*


// @bugden2022rustprogramminglanguagesafety
// @방인영2024study
// @287352
// @10.1145_3428204
// - Low level APIs are dangerous when misused (by concept)
// - Documentation is rarely read completely and correctly, and rarely updated consistently
// - Would be nice if Compiler could enforce correct usage
// - you (usually) need a strong type system for that
// // TODO find grundlagenbücher about type systems / type theory (scholar, chatgpt, opac)
// - Rust provides that and is usable as system language
// - (see linux kernel efforts to move rust into the project, especially in filesystems area)
// - can CVEs be effectively prevented?
// - (Or, if non-exploitable, can crashes be prevented?)
//
// TODO stuff aus Praxisbericht/Projektbericht klauen?

// TODO I talk about programming in general but clearly focus on an early machine-level language like C. state explicitly?


= Related work

// TODO bento (found by @Oikawa2023)

== `rust-fatfs`@Oikawa2023

A Rust reimplementation of the FAT filesystem standard created by Microsoft.
It is implemented as a kernel module, whereas our library lives in userspace with the usage of FUSE.
Although the authors claim exploring security and safety benefits as motivation, the evaluation focuses only on performance, benchmarking the work against the established C kernel module. We did not consider empirical performance analysis, and focus on which kinds of CVEs can be prevented.

== `fuser`

The `fuser` crate, maintained by GitHub user `cberner`, is currently the most used FUSE bindings crate on `crates.rs`, counting over 150k downloads per month, and over 1k stars on GitHub./* FIXME @ask how to quote */
It is not an academic project, but a practical solution for integrating FUSE into the Rust ecosystem, thereby leveraging the advantages of Rusts architecture for filesystem development.
While our goals are not conceptually different as a whole, there is no explicit focus on security.
Types are modeled very closely to the underlying C architecture, although users aren't forced to create C ABI compatible functions, since that --- like in our solution --- is abstracted away.
In fact, probably due to increased performance, `fuser` does not use @libfuse but talks directly to the FUSE module via socket.
This is a complex, low-level undertaking and was out of scope for our project, although it would have been interesting in principle, as the same design principles could still be applied.
Still, results are comparable because the crate models `fuse_operations` very closely to @libfuse.
Also, while we chose to use the high-level @libfuse API, which identifies files via paths directly and submits results synchronously, `fuser` leverages the low-level (LL) @libfuse API, which uses Inodes to represent entries and message helper structs to return asynchronously.
This was carefully considered, but the high-level API simplifies some implementation parts while losing almost none of the targeted design space for safe systems programming, so it was deemed the better choice. // TODO also: sources for fuse LL api vs. "normal" (why normal is better)

@fuser_docs

== Rust for Linux@rustforlinux-website

// - rust-fatfs
// - fuser
//   - auch in rust
//   - fuse LowLevel statt "normal" API (mine)
//   - *aber*: verwendet eh niemand // TODO die paar papers finden die das gesagt haben
// - rust in linux kernel

= Concept

// alle wahrsch. auch wichtig bei Motivation
@jung2020safe
@10.1145_3102980.3103006
@10.1145_3360573
@10.1145_3428204
@10592287

// - read similar rust projects, get idea about how the structure and approach would look for the libfuse bindings
// - read up about `cbindgen` by mozilla (will def. need to use it)
// - read up about theoretical foundation of type systems and using them to encode programmer contracts
// - for every libfuse API call:
//   - decide if in-scope
//   - enumerate a list of (sensible) contracts
//   - encode through type system
//     - if that fails or becomes too hard, skip them and document that
// - (if possible) collect filesystem related CVEs from databases
// - (else) CWEs allgemein sammeln
// - match CVEs/CWEs with libfuse calls, find potential weaknesses/threads
// - evaluate if my rust constructs can fix those weaknesses. if not, try to improve bindings.
// - create stats and tables (e.g. percentage CVEs prevented, taken from a) sub section X, b) time span Y, etc.)
// - write introduction with foundational concepts

= Implementation
// diagram (petrinetz)
// describe every part
// describe design decisions
// tables with pro/cons, interactions of components

#mermaid(read("architecture.mmd"))

== Basic C interop
// source: rust unsafe invariants
// - https://rust-lang.github.io/unsafe-code-guidelines/ => obsolete, out of date?
// - https://doc.rust-lang.org/nomicon/what-unsafe-does.html => too informal?

// TODO bindgen

Safe @Rust can never (sans compiler errors) cause @UB in the resulting binary program. /* TODO quote */
In unsafe @Rust, this is not the case; the programmer now has to uphold several invariants to ensure @soundness. /* TODO quote */
In the C standard, where behavior in any situation not explicitly defined by the language standard is implicitly “undefined“, Rust limits these invariants to a set of specific, well-documented cases.
This makes reviewing the @soundness property of unsafe code easier.

=== Pointers <ch_pointers>

// TODO shorthand for u/i8, u/i16.
// EXTRA what are pointers? stefan "abstraktion über adressen? 'obermenge von references'"

Regarding use of raw pointers in unsafe Rust, the following invariants exist:

1. No dereferencing of dangling or unaligned /* FIXME point to `Alignment` */ pointers.
2. Respect aliasing rules: no pointer is allowed to point to memory that's also pointed-to by a mutable reference, since a mutable reference in Rust is guaranteed to be exclusive.
3. Respect immutability: no pointer is allowed to modify data that's also pointed-to by a shared reference, since a value behind a shared reference is guaranteed not to change.
4. Values in memory must be valid for their respective types: pointers must not be used to change the representation in memory of to a value --- or reference --- to a state which is not valid for the type this value --- or reference --- has. E.g. a `NonZeroU8`, represented in memory as a `u8`, will have one bit pattern that would correspond to a numeric zero and is therefore illegal.

Because @libfuse calls all our callbacks with at least one C pointer, we have to check these invariants as rigorously as possible before we call into user code, if we want to eliminate them as sources of @UB.

// TODO punkte oben nochmal kurz wiederholen
1. We have to differentiate between three cases:
  - *Unaligned pointer*: this is easy, as Rust provides ```rust ptr::is_aligned()```, which takes a pointer and detects misalignment.
  - *Dangling null-pointer*: this is also easy, both manually and through the Rust-provided ```rust ptr::is_null()```, which takes a pointer and detects null-ness.
  - *Dangling non-null pointer*: this happens when a pointer is used-after-free or if pointer arithmetic goes wrong, and is much harder to avoid.
    Since we don't control memory allocation in C, we largely have to trust C code to not pass us pointers from this category.
    This would cause UB and should therefore be documented visibly as soundness assumption.
2. For pointers passed to us by @libfuse, the solution is simply to not create a reference to it.
  If it is necessary to pass a mutable reference into user code, an intermediate owned value must be created, and the target value must be copied in and out of that intermediate.
3. When dealing with non-const pointers, care must be taken to not create a shared reference to it.
  Const pointers don't matter for that aspect, since it is impossible to modify values through them, given they are not cast to non-const pointers.
4. This only matters when primitive C-style casts or ```rust mem::transmute()``` /* todo explain? define? quote? */ are used, as otherwise the Rust typesystem protects us from writing values of the wrong type, even inside unsafe blocks.
  Writing to a pointer can involve writing raw bytes; if that is required, extra care must be taken, and it is therefore usually better to avoid this.

=== Strings and Unicode <ch_strings_unicode>

Rust's native string types (`str`, `String`) exclusively store UTF-8.#cite(<rust-book>, supplement: "ch. 8.2")
The main kind of strings this library needs to handle are the file paths that filesystem callbacks are called on.
The encoding of those is platform-dependent, usually being C-like ASCII strings on Unix-like systems and UTF-16 on newer Windows versions. /* TODO cite */
Correctly detecting and handling string encodings is a hard problem  /* MAYBE cite? */, and since UTF-8 is a superset of ASCII, we chose to not handle UTF-16 or other cases and emit an error when encountering non-UTF-8 input. This limits the complexity of the prototype without limiting the scope of the reseach question.

=== Unwinding across FFI boundaries <ch_unwind>
// - => is UB
// - have to wrap every possible panic point inside ```rust catch_unwind()```
// - not provably panic-free with just compiler
//   - but there is an interesting crate: `https://github.com/dtolnay/no-panic` => *future work*
// EXTRA what about possible (hidden) panics in my own code? integer overflow, slice indexing etc.

When a Rust program is compiled with stack unwinding support and a panic is triggered, the default uwind handler will walk up the stack in order to react to the panic, collecting debug information or cleaning up data. /* FIXME lookup & cite? */
In a program using FFI, this can lead to crossing into another language runtime while walking the stack.
Doing so correctly is a non-trivial task and can easily lead to @UB.#cite(<rust-reference-1.92>, supplement: "ch. 14")
On the other hand, turning unwinding off loses helpful stack traces and debug information when a panic happens.
We therefore decided to keep unwinding behaviour while preventing any panic from propagating across an FFI boundary.

Every function that is visible to C can potentially be called from an environment where unwinding works differently or not at all.
Therefore each of those functions must be panic-free.
As of now, there is no compiler flag or lint that detects or prevents use of panicking functions, operators or language keywords.
As a result, this must be done manually by reviewing the source code of the functions in question, and, recursively, the functions they call.
A convention exists to note possible panics in a section of the function documentation, but even the standard library doesn't consistenly follow it.
// MAYBE enumerate sources for panics

// FIXME move to future work? or implement real quick >:)
One crate /* FIXME define crate */ that tackles this problem is `no_panic`#footnote[https://docs.rs/no-panic/latest/no_panic/] by David Tolnay, a prominent figure amongst the Rust community. It provides the ability to annotate function declarations with an attribute macro, and promises to halt the compilation with an error if the function is *not provably panic-free*.
This implies that it is possible to write functions that would not panic, but would still not compile if the compiler is unable to prove that property.
The crate thereby takes a stance typical of Rust philosophy: it is preferable to reject sound programs, than to accept unsound ones.

While preventing panics in self-maintained code requires careful manual analysis, this is not possible for user-provided functions.
For this, there exists a function ```rust panic::catch_unwind()```@rust-std-1.92 that takes a closure and executes it, catching any unwind that would occur and returning an error instead.
Wrapping the call to user code inside this function ensures that no panic will be propagated up the call stack from this point on.@catch_unwind

#figure(
  ```rust
  fn call_into_user_code<FS: Filesystem, T>(
      method: &str,
      user_fn: impl FnOnce() -> Result<T, Errno>,
  ) -> Result<T, (String, Errno)> {
      let fs = std::any::type_name::<FS>();
      std::panic::catch_unwind(core::panic::AssertUnwindSafe(user_fn))
          .map_err(|panic| {
              // abort, since internal state of filesystem impl can now be inconsistent
              state::clear();
              (
                  format!("PANIC on `{fs}::{method}`:\n\n{panic:?}\n"),
                  Errno::ENOTRECOVERABLE,
              )
          })
          .and_then(|inner| inner.map_err(|e| (format!("Error in user code `{fs}::{method}`"), e)))
  }
  ```,
  caption: [An exemplary trampoline function signature implementing compile-time static dispatch via generics],
) <catch_unwind>

== FUSE operations

The @libfuse operations struct contains 43 callbacks to implement, most of which are optional and not needed for a filesystem to work properly.
If we can forgo modifying the state, and create a read-only filesystem, the number of required calls can be brought down to 3. #cite(<libfuse_docs>, supplement: "p. structfuse__operations.html")#cite(<libfuse_docs>, supplement: "p. example_2hello_8c.html")

Some of the operations which are superflous for our experiments include:
- `lock`/`flock`: These are used for file locking, enabling safe concurrent access, and locking primitives across processes. Since our filesystem is readonly, no locking is needed.
- `ioctl`: Needed for special I/O commands, when simple seeking to byte offsets, and reading/writing from them is not sufficient. Examples include ejecting CD-ROM or rewinding data tape. Not needed for our general-purpose minimal filesystem.
- `write`/`sync`/`fsync`: These are used for writing data out, and to force flushing buffers to the underlying storage. Irrelevant in a read-only filesystem.
- `mkdir`/`link`/`create`/`mknod`/`unlink`/`rmdir`: Creating and deleting of entries of various types. Not relevant for a read-only filesystem.

All implemented operations check their pointer arguments for validity, with the methods discussed earlier (@ch_pointers).
The obligatory `path` argument, that identifies the entry to operate on, is converted from a C string into native Rust, and also checked for validity (@ch_strings_unicode).
After basic correctness of inputs has been ensured, the code tries to load the filesystem object from the global registry.
This is done to minimize unneccessary work when some inputs are not sound.
The load could fail, e.g. in case the user code triggered a panic earlier, or due to a bug in the wrapper library. This is also handled (@ch_init).

After that, some operation-specific instructions are executed, and a context is set up to call into user code without triggering panic unwinding (@ch_unwind).
@libfuse datatypes are converted to our Rust representations, adding the implicit safety checks.
After the user code has been executed, the results are converted back into @libfuse types, and success of the operation is signaled up the stacks.

Next up is a detailed description of the required calls, accompanied with their respective C and Rust signatures.

=== getattr

```c int(* 	getattr )(const char *, struct stat *, struct fuse_file_info *fi)```
```rust pub unsafe extern "C" fn getattr<FS: Filesystem>(
    path: *const i8,
    stat_out: *mut libfuse::stat,
    _fuse_file_info_out: *mut libfuse::fuse_file_info,
) -> i32
```

This provides information about a filesystem entry, be it a file, a directory, a symbolic link, or some sort of special device. Without this call, no metadata could be queried about our filesystem, and its usefulness would be severely limited.

This function, as do all of the callbacks described here, takes a path in form of a C string to describe the filesystem object to query. It also takes two additional parameters: a `stat` struct as output, to be filled with the resulting metadata (#ref(<ch_stat>)), and an optional `fuse_file_info`, which may be set when the file in question is currently opened, and can provide additional metadata and FUSE settings if set.

We chose to mostly ignore the `fuse_file_info` for now, as it is only used under specific circumstances, and even then provides only very specialized attributes that would go beyond the scope of this exploration. The other two parameters are checked as per concept.

It's the users job to create an instance of `struct Stat` and pass it back to us. This @newtype_struct contains a valid `stat` fuse struct inside, which is needed as return value written into the output pointer argument of same name, and can trivially convert to one.

=== readdir

This function's job is, given a directory as path, provide a list of child entries, enabling directory content listing (as e.g. in the `ls` command). An offset can be provided to support partial listings over multiple calls, however we chose to ignore this, as is allowed in the documentation.#cite(<libfuse_docs>, supplement: "p. structfuse__operations.html")

There exists an alternative, more complex mode, which we could have chosen to support: Implement the additional `opendir` operation to open the directory to enumerate as a file descriptor. Then, `readdir` is called on the active file descriptor, providing a view of the directory that is guaranteed to be the same as when `opendir` was called. This was deemed unneccessary to explore the given research questions, and skipped subsequently.

The API is designed, so that the `readdir` implementation doesn't just return, or write into, an array of entries.
Instead, a function pointer to a "filler" function is provided.
Our operation has to call this function for every entry.
Some of the filler functions parameters correspond to entry metadata, others, like a pointer to an opaque data buffer, have to be forwarded.@readdir_filler_fn#cite(<libfuse_docs>, supplement: "p. structfuse__operations.html")

/* FIXME @ask statt dem ersten und letzten codeblock: 1 zeile comment "// converting string" "// checking error". for brevity? */
#figure(
  ```rust
  // ...
  for entry in entries {
      let entry_as_c_string = try_errno!(CString::new(entry.clone()).map_err(|e| {
          (
              format!("converting dir entry '{entry}' into a C string: {e:#}"),
              Errno::EIO,
          )
      }));
      debug!(?path, "filling entry '{entry}'");
      let fill_result = unsafe {
          filler_fn(
              data_ptr,
              entry_as_c_string.as_ptr(),
              ptr::null(), /* setting `stat` struct to NULL, as per `hello.c` */
              0,           /*: offset */
              libfuse::fuse_fill_dir_flags_FUSE_FILL_DIR_DEFAULTS,
          )
      };

      if fill_result != 0 {
          bail_errno!(
              format!("filler_fn returned non-zero for '{entry}': {fill_result}"),
              Errno::EIO
          );
      }
  }
  // ...
  ```,
  caption: [Excerpt from the `readdir` trampoline, passing the Rust vector of directory entries into the C filler function.],
) <readdir_filler_fn>

// FIXME also: add code snippets to this and `getattr`

=== read

The `read` operation provides us with the means to fetch the content of files, complementing our set of operations to obtain a usable, if minimal, filesystem.
It takes as parameters a size and an offset, determining the range of content to be read, as well as a C character array to store the data in.
Again, an optional `fuse_file_info` struct pointer is provided, which we can ignore.

Dealing with the size and offset parameters provided a challenge. While the requested size parameter is of type `size_t`, which is usually defined as 64-bit integer on modern systems to be used for indexing memory, we have to return the actual amount of read bytes as signed 32-bit integer.
As such, we can only signal successful reads of up to $$2^31 - 1$$ bytes.
Further investigation showed that maximum read size is limited by the Linux kernel#cite(<read.2_manpage>), so the limitation in the API seems reasonable, assuming other operating systems impose similar limits.
We therefore have to carefully check if the input parameter is inside the allowed range, and convert between the respective integer types, in addition to the usual checks.
Furthermore, Rust does not provide a native method of specifying an upper bound for a vector length as part of the type signature, so manual checks are required after the user code returns the data. Dependent types or refinement types would be a possible solution, but are not available in Rust aside from research projects. /* FIXME sources */

If the size checks pass, a pointer copy is issued, for which Rust STD provides a function.
Because we use `unsafe`, we documented the assumptions made and invariants we checked, as is common practice.@read_copy_nonoverlapping

#figure(
  ```rust
    // Safety: we checked that the buffer is big enough to hold the returned data (if `size` argument was correct).
    //         Also we checked that the pointer is aligned and non-null.
    //         Also, the areas cannot overlap, since the Rust vector has reserved its own memory.
    unsafe {
        ptr::copy_nonoverlapping(
            result.content.as_ptr(),
            buf as *mut u8,
            result.content.len(),
        );
    }
  ```,
  caption: [Excerpt from the `read` trampoline, copying the read result into the provided C buffer.],
) <read_copy_nonoverlapping>

== Initialization and Global State Management <ch_init>
// EXTRA split into two? or one sub the other?
// FIXME löhr: _maybe_ ein zwei sätze für sanftere einführung, abbildungen auch immer gut. aber muss auch nicht / ist klar, dass das nicht überall geht.

- We need to supply a number of C functions that know which user impl to call
- Possibility: just use data pointer from `libfuse::init`
  - Con: push raw pointers around, prone to corruption
- My choice: use generics, overload generic trampolines with user Filesystem type
  - that way, the compiler generates a concrete version (with its own address and hard-coded user code address) of our generic trampolines
  - since generic parameter is the only type with ```rust impl Filesystem``` in scope, type system prevents any confusion/programmer error.
  - since compiler generates hardcoded version, memory corruption due to logic errors anywhere is also not a problem
  - con: only one instance per ```Filesystem``` struct type per process.
    - workaround: just use wrapper structs (can be done easily from user code)

Since the libfuse initialization routine takes a struct of callback function pointers (`fuse_ops`), that creates the following problem.
Since the C signature is predetermined, user functions cannot be used, because that would force signatures of user functions to use the lower-level C types which we try to avoid.
That means, even though there is a one-to-one correspondence between FUSE operation callbacks and trait methods on the `Filesystem` trait, they are not compatible and cannot be used interchangably.
The obvious approach is to provide #glspl("trampoline_function"), which then wrap, transform and safety-check the C type values on call and dispatch into user code.
A non-trivial problem, one that is not obvious at first sight, is how the trampoline knows which filesystem implementation to dispatch to.
There are two basic options how to use the trampolines:

1. Use one global trampoline per callback, and somehow transport the choice on which filesystem to use inside the C arguments that @libfuse_wrapper gets passed by @libfuse.
2. Somehow generate a set of trampolines per user filesystem, which are then hard-coded towards the specific filesystem implementation.

A way to implement option 1 is provided in the form of a ```c void *private_data``` pointer that can be passed to @libfuse during filesystem registration. This pointer can contain arbitrary user-specified data, and is not used by @libfuse except for making it available to every fuse operation via the ```c fuse_get_context```#footnote[https://libfuse.github.io/doxygen/fuse_8h.html#a5fce94a5343884568736b6e0e2855b0e] function.

Since it is possible /* FIXME really? prob. not, is a trait object and e fat. we need to use heap alloc, e.g. Box::into_raw() or sim. */ to store a Rust pointer inside a C void pointer, @libfuse_wrapper can submit a pointer to the user implementation as payload for `private_data`, then let each trampoline poll the FUSE context struct, cast the void pointer back to a trait object reference and dispatch into the corresponding trait method. This has the following disadvantages:
- Decaying a managed Rust reference into a raw pointer loses the advantage of lifetime tracking that is one of Rusts fortes in the /* TODO kampf/anstrengung/undertaking */ undertaking of creating safe systems-level code. Manual care has to be taken not to invoke a use-after-free, accessing an uninitialized or unauthorized memory location or --- in the best case --- simply leaking memory. In fact, the safest option would be to initialize this data pointer once, and then never free it, since it is the dealloc part that introduces memory unsafety to a system /* TODO quote? */, and even if leaking memory (and not calling destructors) is acceptable, since @libfuse passes around non-const pointers to everything, bugs at any point of both our trampolines and @libfuse can easily lead to access of corrupted pointers and therefore to @UB. This is usually a tradeoff that must be accepted when dealing with FFI into unsafe languages, but should be mitigated whenever feasible.

// FIXME no second disadvantage?

Both disadvantages would in theory prevented by a solution after option 2, and thankfully, with the use of generics, Rust brings includes the tools to implement such a solution. As seen in @trampoline_fn_signature, this exemplary trampoline function is generic over types implementing our `Filesystem` trait.
This leads the Rust compiler to generate a concrete, independent `getattr` trampoline function for every trait implementation of `Filesystem` that is used to call our initialization function.
The generic approach is then combined with a singleton registry#footnote[https://crates.io/crates/singleton-registry] which provides a global map of values, indexed by types.
We can now store the concrete user-supplied filesystem struct inside this registry and use the type of this filesystem struct as index, which additionally will be deduced implicitly by the compiler from the argument types of our initialization function.
That means, given there are no other implemenations of our `Filesystem` trait in scope when declaring the generic functions, the type system guarantees us that the user's type is the only one that can be used for dispatching, shielding even against potential programmer oversight.

This has the drawback of only allowing one instance of a concrete `Filesystem` type to be mounted per process. But since --- if needed --- @newtype_struct:pl can be used to create different concrete types with minimal boilerplate, this was deemed tolerable.

#figure(
  ```rust
  pub unsafe extern "C" fn getattr<FS: Filesystem>(
      path: *const i8,
      stat_out: *mut libfuse::stat,
      _fuse_file_info_out: *mut libfuse::fuse_file_info,
  ) -> i32 {
  ```,
  caption: [An exemplary trampoline function signature implementing compile-time static dispatch via generics],
) <trampoline_fn_signature>

== Type modeling
// _FIXME _löhr: ist es ok, die unterkapitel nach technischen (Typ-)namen zu benennen, oder soll ich allgemeinere kategorien wählen?
// - geht schon, wär vlt schöner was dazuzuschreiben, aber sind halt wirklich so standard dinger

Creating thin high-level representations of the low-level data types that make up the @libfuse API, that nonetheless verify as many correctness properties as possible, is the main focus of this project.
Where feasible, these properties are checked during compile-time, which gives the additional advantage of not impacting runtime performance.
Otherwise, runtime checks are emitted to still provide correctness, but at the disadvantage of producing runtime errors instead of halting compilation, which increases development cost. /* MAYBE cite */
/* _FIXME @end auch in "future work"? stefan: prob zu klein, hier lassen. */It would be common practice in low-level Rust crates to provide ```rust *_unchecked()``` variants for these runtime-checked methods, to give users the choice of circumventing those checks and trading performance for possible @UB.
Due to the goals of this work, and time constraints, this was mostly skipped.

// FIXME @ask genug?

=== Typed builder

A pattern that is often encountered in Rust is a _builder_.
It tries to solve the problem of value creation, where, for big types, many values must be provided, some of which are interdependant or introduce combined constraints, and some are only available at different times.

There are multiple ways to construct a value in Rust:

- *Initializing a raw struct*: If the struct has only public fields, directly constructing it is possible.
  As downsides, validation of the value as a whole is not possible, since a struct can always be legally constructed from legal values of all its elements, so any checks must be performed through the types of its members.
  Also, staggered initialization is not possible, since at construction point, every value has to be provided. It is possible to let construction use default values for some members, but this doesn't equal partial initialization, since it is not fundamentally possible to tell an uninitialized value from a valid value equalling the default value of the field.
  Thus, this loses some type safety.
- *Constructor function*: Rust doesn't have constructors as language constructs, as opposed to e.g. C++.
  Idiomatically, constructors are member functions with the name `new()` or `new_*()`, since Rust also doesn't allow function overloading.
  Paired with lack of default parameter values, this makes writing constructors rather rigid, and is not substantially different to using raw structs.
  No staggered initialization is possible, as with a struct initialization, but interdependent validity checks can be performed;
  with the caveat, that when a type provides multiple constructors, all of them must duplicate the verification logic or use a private shared constructor that centralizes the checks.
  This is also manual, and can be overlooked, and the probability of oversight increases with the count of constructors.
- *Struct as constructor parameter*:
  An elegant combination of the two concepts above is to use a dedicated initialization struct, that is either passed to a constructor or can be cast to the target type.
  It acts as a sort of dictionary, or list of named parameters.
  This emulates named arguments and also works with private fields, since the target type construction is hidden from the user.I
  It still doesn't solve staggered construction, for the same reasons as stated above.
  But one could maybe imagine using this pattern multiple times, where each initialization struct sets some parameters and generates the next stage of initialization via an opaque intermediate type, thus providing multiple phases of initialization.
  Implementing this from hand would be complex and error-prone, since every combination of initialized-ness has to be coded explicitly, which leads to $$ n! $$ cases, where $$n$$ equals the number of initialization parameters.
- *Typestate builder pattern*: This is where Rusts strengths come in to play.
  Rust provides a rich macro system, enabling the generation of the boilerplate code that is needed for such a multi-stage "build" of a value.
  The pattern described here is named "typestate builder" pattern, or "typed builder" pattern, and is one variant of the more general builder pattern.
  It annotates the target struct, generating a builder struct which allows to set every parameter by itself.
  Required parameters must be set exactly once, optional parameters zero or one times.
  This detects possible bugs as cases, where a value is forgotten to be set, or is set too many times, overwriting the previous choice.
  Additional checks can be added to every member and the struct as a whole, in the form of closure predicates.
  Syntactic sugar for flags is supported to be able to write ```rust boolean_flag()``` to enable a flag, and omission of any call to leave it of, instead of ```rust set_boolean_flag(val: bool)```.
  This improves readability and provides additional correctness checks.
  Also, only the validity closures live in runtime; the basic correctness checks of every field being set the right amount of times are modeled within the type system, leading to compilation errors when disregarded, which is one of our goals.

  The implementation of this builder pattern creates a utility intermediate type for every possible combination of whether a type has been set. An example would be a builder for a struct ```rust struct Point { x: f32, y: f32 }```, which represents a point on a cartesian coordinate system. A manual implementation of a builder could look like this:

#figure(
  ```rust
  struct PointWithXSet { x: f32 }
  struct PointWithYSet { y: f32 }
  struct PointWithNothingSet {}

  impl PointWithNothingSet {
    pub fn set_x(x: f32) -> PointWithXSet { /* ... */ }
    pub fn set_y(y: f32) -> PointWithYSet { /* ... */ }
  }

  impl PointWithXSet {
    pub fn set_y(y: f32) -> Point { /* ... */ }
  }

  impl PointWithYSet {
    pub fn set_x(x: f32) -> Point { /* ... */ }
  }

  impl Point {
    pub fn build() -> PointWithNothingSet { /* ... */ }
  }

  ```,
  caption: [FIXME.],
) <typestate_builder_manual_1>

In this case, the type system makes it invalid to set an x or y coordinate multiple times, or forget to set it.
There are only two possible ways to obtain a value of type ```rust Point```:

- calling ```rust Point::build().set_x().set_y()```
- calling ```rust Point::build().set_y().set_x()```

Therefore we can ensure proper initialization of the point value.

Another way of modeling this pattern uses generics. @typestate_builder_manual_2 shows such an approach.

#figure(
  ```rust
  pub struct PointBuilder<State: PointBuilderState> { state: State };

  trait PointBuilderState {}
  struct NothingSet;
  impl PointBuilderState for NothingSet {};
  struct XSet { x: f32 };
  impl PointBuilderState for XSet {};
  struct YSet { y: f32 };
  impl PointBuilderState for YSet {};

  impl Point {
    pub fn build() -> PointBuilder<NothingSet> { /* ... */ }
  }

  impl PointBuilder<NothingSet> {
    pub fn set_x(x: f32) -> PointBuilder<XSet> { /* ... */ }
    pub fn set_y(y: f32) -> PointBuilder<YSet> { /* ... */ }
  }

  impl PointBuilder<XSet> {
    pub fn set_y(y: f32) -> Point { /* ... */ }
  }

  impl PointBuilder<YSet> {
    pub fn set_x(x: f32) -> Point { /* ... */ }
  }

  ```,
  caption: [FIXME.],
) <typestate_builder_manual_2>

// TODO more theoretical bla on state machines / DEAs
On closer inspection this pattern bears resemblance of a state machine, where states are marker structs --- structs with no associated data fields --- that implement a marker trate --- analogously, a trait without associated items ---.
Methods on these concrete types, which after monomorphisation /* FIXME quote/explain */ are the ```rust PointBuilder``` with a concrete state as type parameter, that return a ```rust PointBuilder``` with a different state type, represent transitions between those states.
This is intuitive because, as a transition can only be applied to the start state and results in the end state of that transition, methods on a type can only be run on an existing value of that type, and always produce the return value.

The implementation using generics has a few advantages:
Since all intermediate types are specializations of a general builder type, there can be methods on the general builder type, which correspond to transitions on any starting state. /* FIXME macht das hier sinn? überhaupt nochmal typestate<->builder überdenken */

While a typestate builder has many advantages in statical correctness, conditional branches can be difficult to handle.
That is because every state of the builder is effectively a different type, and Rust doesn't allow items to have different types depending on a branch.
This is encountered frequently when dealing with complex generics, and while staying inside this type abstraction, there is no solution besides avoiding conditionally setting fields, and instead executing the conditional code only while calculating the value /* FIXME example */.
Runtime builders don't have this issue, as every builder state has the same type, and the information of which field has been initialized is usually stored through optional types.

Because of the tradeoffs discussed between the different solutions, it can be advantageous to provide the user with multiple approaches, enabling them to choose whatever tool appropriate for the context. For example, we chose to provide both a type builder and a runtime builder for our ```rust FileMode``` struct, allowing correctness when flow of execution is well-known, and flexibility with runtime checks, when it's not.


@typed_builder_docs




// - question: how do I model type creation?
//   - free function: no named parameters, gets unreadable quickly, no optional parameters
//   - struct init: grundsätzlich recht sicher, aber
//     - pro: parameter sind benannt
//     - manche felder mandatory, manche optional: geht nicht
//     - struct muss default trait implementieren, dann sind alle felder basically optional, und es ist möglich, potentiell invalide objekte zu erstellen
//     - keine schicken auto-converts und transformations, bounds checking etc.
//   - "normal" runtime builder
//     - pro: sehr flexibel, ergonomisch
//     - con: wird ein mandatory feld vergessen, gibts erst zur runtime nen fehler
//   - typed builder:
//     - pro: flexibilität und mächtigkeit eines runtime builders, trotzdem werden fehler schon zur compilezeit gefangen
//     - con: state ist im typ encodiert, macht es schwer bis unmöglich (type erasure stunts), z.b. in einer if-bedingung konditional ein feld zu setzen
// - da für jeden einsatzzweck ein anderes pattern optimal sein kann, habe ich mehrere für meine struct(s) implementiert
// TODO table?



=== `stat` <ch_stat>

The @libfuse `stat` struct is very similar to the namesake found in @POSIX. Both describe an entry in an abstract filesystem, and contain most of its attributes.
This set of attributes is needed for most interaction, because it provides data not limited to: the type of the entry --- file, directory, symbolic link or other --- it's permissions, size and modification dates. It is usually the set of information our wrapper has to provide to the surrounding system when some interaction with the filesystem takes place, e.g. listing or changing into a directory, or opening a file.
@stat.3type_manpage

Our attempt at modeling lead us to break down the struct into smaller parts, which require more attention: /* FIXME kurzes statement, warum die gut geeignet sind. bissi expliziter halt. zb: es gibt bestimmte komponenten, da macht es sinn die extra zu behandeln, weil gut zu prüfen bla etc…. eigl in extra absatz */
- `FileType`, which is an enum flag of several possible values that have to specifically match magic IDs from the corresponding C header.
- `FilePermissions`, which are stored as a positive integer and usually displayed as an octal number in the range of `0o000` to `0o777` and represent restrictions on reading, writing and executing the underlying entry.
- three bitflags (`setuid`, `setgid`, and `vtx_flag`), that are context-dependent and enable additional features. These are stored inside the permissions integer in the underlying Unix APIs.

Other fields, like file size and modification time, were not deemed as interesting, since it can be correct for them to assume every valid bit pattern the underlying C type can represent, and checking the correctness semantically would introduce significant runtime overhead. E.g. validating modification time would have to detect modification in arbitrary files, and file size is an attribute that the wrapper has no insight into. Further insight into this problem is provided in #ref(<ch_prototype>).

=== `fuse_file_info`

This type, although a parameter to every operation implemented, is optional in every case, and seldomly used.
In fact, due to the limited nature of our experiment, because we don't work with `open` and file descriptors, it can be assumed that the struct never be initialized.
Therefore, modeling was skipped.
This does not mean that `fuse_file_info` is not a good candidate for our methodology.
To the contrary: because it contains a bitset with various flags, these can easily be modeled with associated methods, which atleast provide a simple safeguard against erroneous bit operations.
Additionally, some entries influence further behaviour of the filesystem and could probably be used to implement more correctness checks.

=== `FileMode`

`FileMode` is an abstraction that @libfuse provides, that encapsulates both file type and the permission mask.
To stay close to the lower level, we opted to keep this encapsulation.

=== `OpenFlags`

// TODO: add user code call to open, check that the function looks fully functional, then we can better use the solutions from this part.
// MAYBE explain macro `bitflag_accessor`

== Error handling
// allg: conversion between rust `Result<>` and errno

While @libfuse and Rust both return an error value

// `{try,bail,ensure}_errno!()`
// Verweis auf `panics/unwind across FFI`

= Evaluation

@cwe-top25-2025

// hier CVEs auswerten, vlt oben in Methodology schon konkret auflisten
== A prototype filesystem: `hello2` <ch_prototype>
// FIXME @ask geht das in die richtige richtung?
// - stefan: vlt noch mehr, alles was ich gemacht hab geht in die richtige richtung.

To test our wrapper library, we created a minimal filesystem using it.
It implements only three callbacks --- `getattr`, `read`, `open` --- as this is enough to provide a complete, usable filesystem.#cite(<libfuse_docs>, supplement: "p. example_2hello_8c.html")

This filesystem is read-only, since that narrows down the functionality we have to implement.
Files are declared in a static global array, and are even associated with a closure object, to facilitate files with dynamic content. The following example (@hello2_file_table) shows a global file table of two entries: `time.txt`, which always reads the current system date and time, and `pid.txt`, which always reads the ID of the filesystem process.
This dynamic property of our test filesystem allows us increase confidence in our abstractions, by providing less stability on which to accidentally depend.

Additional logic was deemed necessary to be able to build a hierarchical recursive folder data structure from the provided file table, which is needed for listing directory contents. Implementing this keeps the file table itself clean and readable, and accelerates development and testing.

Besides some boilerplate to iterate over files in a folder, the only logic consists of the block ```rust impl Filesystem for Hello2```, where we implement methods on @libfuse_wrapper's filesystem trait.
The implementations were straight-forward and simple, which which was one of @libfuse_wrapper. Most low-level details and pitfalls were abstracted away.
One aspect that required a proportionally high amount of SLoC was dealing with partial and offset reads, but offloading that to the wrapper would mean that the user has to provide an array with the full file content already contained, only for the wrapper to calculate the correct offsets.
This could be made possible as an additional opt-in API, but would almost certainly result in major inefficiencies, as the filesystem has to procure the whole file's content every time a partial read is requested.

// FIXME @ask more?

#figure(
  ```rust
  static FILES: LazyLock<[FileEntry; 6]> = LazyLock::new(|| {
      [
          ("/pid", Box::new(|| std::process::id().to_string())),
          (
              "/time",
              Box::new(|| format!("{}", chrono::Local::now().format("%c"))),
          ),
      // …
  ```,
  caption: [A global file table for our `hello2` example filesystem],
) <hello2_file_table>

= Conclusion

== Limitations

// TODO more low-level, still as much safety?

= Future work

#bibliography("bibliography.bib", style: "ieee")

#pagebreak()
= Glossary
// Your document body
#print-glossary(
  glossary-list,
)
