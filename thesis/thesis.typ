// # GLOBAL TODOS
// - [] fix glossary keys being displayed when no short variant exists
// - [] fix "ich/mein/mir/mich"
// # STYLE
// @löhr: deutsch passiviert / englisch "we"
// - https://academics.umw.edu/swc/files/2024/02/IEEE-Formatting-Guidelines.pdf
//   - capitalize headers
//
// # FINAL REFACTOR
// - grep for glossary/abbrev instances
// - "therefor"
// - "atleast"

#import "@preview/oxdraw:0.1.0": oxdraw as mermaid

// TODO use fletcher
// @löhr: github links, doku etc.: muss das in die bibliographie rein oder reichen fußnoten?

#import "@preview/glossarium:0.5.10": gls, glspl, make-glossary, print-glossary, register-glossary
#show: make-glossary
#import "glossary.typ": glossary-list
#register-glossary(glossary-list)

// FIXME schau dir short/long/blah nochmal an, anscheinend werden bei nichtvorhandensein von short die keywords wiederholt oder so


#import "@local/ohm:0.1.0": thesis

// requirements:
// - author - dict{name, student-id}
// - examinors - dict{first, second}
// - every figure has a caption
#show: rest => {
  thesis(
    author: (name: "Florian Meißner", student-id: "3210376"),
    examinors: (first: "Prof. Dr. Hans Löhr", second: "Prof. Dr. Michael Zapf"),
  )[#rest]
}

= Introduction

- Rust is increasing usage in system level
- but still many big projects (linux etc.) are written in C


Since the beginning of programming, there has been a discrepancy between the input states an interface formally accepts, and the input states that are sound to handle.
For example, a reciprocal function $$ f(x) = 1/x $$ might formally accept a 32 bit integer --- and therefore all of its $$2 ^ 32$$ input states ---, but the mathematical formula it tries to model will not give a sensible result for $$ x = 0 $$; least of all if the function in turn returns an integer, since there is no integer $$ n: 1 / x = n $$.

One straightforward solution has always been to limit the function domain via documentation. Users of that function are expected to read that documentation and recognize that it is a violation of interface contract to call it with $$ x = 0 $$. Violation of that contract would in turn result in an error, a crash, or --- worse yet --- @UB:long. An approach with drawbacks, as there are now two sources of truth about the function domain. One of these --- the function signature, expressed in code --- is already technically incorrect, as we have not stated a way to express "integers without zero" as a valid type. Additionally, as the program developes, the chance of both sources of truth to get further out-of-sync increases. This discrepancy,between the high-level contract, expressible only in additional information in text form, and the function signature the compiler handles, raises the following question: Can we encode this precondition in such a way that the function signature makes it impossible to pass in values that violate any API contract?

// TODO maybe use contract programming thought model, and explain keywords (invariants, preconditions)

In languages where we have strict and strong typing /* TODO define */, we can enforce invariants about types we create, since we have to explicitly provide the methods of construction for these types, and we can make then fail if some invariants are not upheld. This allows us to express function signatures of the kind discussed previously, by creating a new type `NonZeroI32`@nonzeroi32_reciprocal that represents the idea of an integer that cannot be zero. By making the inner value private, we then ensure that users of our library are forced to use the only construction method we provide them with, ```rust NonZeroI32::new(i32)```. This `new()` function can be total, since it returns a result value representing a fallible computation. In that sense, the function signature of `new()` expresses that *every 32-bit integer is either a valid non-zero 32-bit integer or an error*.

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

- Modern language with many features that can increase correctness and safety
- is marketed/intended as a low level language, usually competes near C in benchmarks
  - Rust in Linux kernel
  - RedoxOS
  - coreutils / libc rewrite
- features
  - borrow checker / lifetime tracking / ownership tracking
  - strict types /* TODO define, quote */, (almost) no implicit conversions
  - RAII / destructors / `Drop` trait
  - no data races
  - fearless concurrency // <-> data races?
  - error handling
  - ADTs / modeling complex types
  - generics
  - typestate pattern
- Unsafe rust
  - *what we keep, what we lose*
  - additional promises to uphold
  - (ausblick: additional tools, static analysis, sanitizers etc.)

== FUSE
- filesystem as process in userspace
- don't have to build kernel modules (safer, easier dev workflow)
- should be comparable though (why? give reasons)
- architecture (/* TODO image */)
  - fuse kernel module
  - libfuse
  - FS impl
  - *=> our layer*


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

  pub fn reciprocal(n: NonZeroI32) -> NonZeroI32 {
    // ...
  }
  ```,
  caption: [A new type `NonZeroI32` that represents the idea of a 32-bit integer *guaranteed* to not be zero],
) <nonzeroi32_reciprocal>

= Related work

// TODO bento (found by @Oikawa2023)

== `rust-fatfs`@Oikawa2023

A Rust reimplementation of the FAT filesystem standard created by Microsoft.
It is implemented as a kernel module without usage of FUSE.
Although the authors claim exploring security and safety benefits as motivation, the evaluation focuses on performance, benchmarking the work against the established C kernel module.

// FIXME @löhr: explizit auch nennen, was der unterschied zu meiner lösung ist. gerne klarer werden.

== `fuser`

== Rust for Linux@rustforlinux-website

- rust-fatfs
- fuser
  - auch in rust
  - fuse LowLevel statt "normal" API (mine)
  - *aber*: verwendet eh niemand // TODO die paar papers finden die das gesagt haben
- rust in linux kernel

= Concept

// alle wahrsch. auch wichtig bei Motivation
@jung2020safe
@10.1145_3102980.3103006
@10.1145_3360573
@10.1145_3428204
@10592287

- read similar rust projects, get idea about how the structure and approach would look for the libfuse bindings
- read up about `cbindgen` by mozilla (will def. need to use it)
- read up about theoretical foundation of type systems and using them to encode programmer contracts
- for every libfuse API call:
  - decide if in-scope
  - enumerate a list of (sensible) contracts
  - encode through type system
    - if that fails or becomes too hard, skip them and document that
- (if possible) collect filesystem related CVEs from databases
- (else) CWEs allgemein sammeln
- match CVEs/CWEs with libfuse calls, find potential weaknesses/threads
- evaluate if my rust constructs can fix those weaknesses. if not, try to improve bindings.
- create stats and tables (e.g. percentage CVEs prevented, taken from a) sub section X, b) time span Y, etc.)
- write introduction with foundational concepts

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

=== Pointers

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

=== Strings and Unicode

Rust's native string types (`str`, `String`) exclusively store UTF-8.#cite(<rust-book>, supplement: "ch. 8.2")
The main kind of strings this library needs to handle are the file paths that filesystem callbacks are called on.
The encoding of those is platform-dependent, usually being C-like ASCII strings on Unix-like systems and UTF-16 on newer Windows versions. /* TODO cite */
Correctly detecting and handling string encodings is a hard problem  /* MAYBE cite? */, and since UTF-8 is a superset of ASCII, we chose to not handle UTF-16 or other cases and emit an error when encountering non-UTF-8 input. This limits the complexity of the prototype without limiting the scope of the reseach question.

=== Unwinding across FFI boundaries
- => is UB
- have to wrap every possible panic point inside ```rust catch_unwind()```
- not provably panic-free with just compiler
  - but there is an interesting crate: `https://github.com/dtolnay/no-panic` => *future work*
// EXTRA what about possible (hidden) panics in my own code? integer overflow, slice indexing etc.

When a Rust program is compiled with stack unwinding support and a panic is triggered, the default uwind handler will walk up the stack in order to react to the panic, collecting debug information or cleaning up data. /* FIXME lookup & cite? */
In a program using FFI, this can lead to crossing into another language runtime while walking the stack.
Doing so correctly is a non-trivial task and can easily lead to @UB.#cite(<rust-reference-1.92>, supplement: "ch. 14")
On the other hand, turning unwinding off loses helpful stack traces and debug information when a panic happens.
We therefore decided to keep unwinding behaviour while preventing any panic from propagating across a FFI boundary.

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
- these 4 functions seem to be the bare minimum for a R/O filesystem (see libfuse example `hello`)
- open can be a noop

=== getattr
- "bread and butter" call, is the first one executed on all filesystem paths, lets user decide how to continue (readdir on dirs, read/open on files e.g.)
-

=== readdir
=== open
=== read

// EXTRA split into two? or one sub the other?
== Initialization and Global State Management
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
Otherwise, runtime checks are emitted to still provide correctness to a very high degree.
/* FIXME @ask auch in "future work"? */It would be common practice in low-level Rust crates to provide ```rust *_unchecked()``` variants for these runtime-checked methods, to give users the choice of circumventing those checks and trading performance for possible @UB.
Due to the goals of this work, and time constraints, this was mostly skipped.

// FIXME @ask genug?

=== `stat`

The @libfuse `stat` struct is very similar to the namesake found in @POSIX. Both describe an entry in an abstract filesystem, and contain most of its attributes.
This set of attributes is needed for most interaction, because it provides data not limited to: the type of the entry --- file, directory, symbolic link or other --- it's permissions, size and modification dates. It is usually the set of information our wrapper has to provide to the surrounding system when some interaction with the filesystem takes place, e.g. listing or changing into a directory, or opening a file.
@stat.3type_manpage

Our attempt at modeling lead us to break down the struct into smaller parts, which require more attention:
- `FileType`, which is an enum flag of several possible values that have to specifically match magic IDs from the corresponding C header.
- `FilePermissions`, which are stored as a positive integer and usually displayed as an octal number in the range of `0o000` to `0o777` and represent restrictions on reading, writing and executing the underlying entry.
- three bitflags (`setuid`, `setgid`, and `vtx_flag`), that are context-dependent and enable additional features. These are stored inside the permissions integer in the underlying Unix APIs.

Other fields, like file size and modification time, were not deemed as interesting, since it can be correct for them to assume every valid bit pattern the underlying C type can represent, and checking the correctness semantically would introduce significant runtime overhead. E.g. validating modification time would have to detect modification in arbitrary files, and file size is an attribute that the wrapper has no insight into as per abstraction.

// FIXME @ask explizit schreiben warum die drei davor aber interessant waren.

=== `fuse_file_info`
=== `FileMode`
==== Typed builder
- question: how do I model type creation?
  - free function: no named parameters, gets unreadable quickly, no optional parameters
  - struct init: grundsätzlich recht sicher, aber
    - pro: parameter sind benannt
    - manche felder mandatory, manche optional: geht nicht
    - struct muss default trait implementieren, dann sind alle felder basically optional, und es ist möglich, potentiell invalide objekte zu erstellen
    - keine schicken auto-converts und transformations, bounds checking etc.
  - "normal" runtime builder
    - pro: sehr flexibel, ergonomisch
    - con: wird ein mandatory feld vergessen, gibts erst zur runtime nen fehler
  - typed builder:
    - pro: flexibilität und mächtigkeit eines runtime builders, trotzdem werden fehler schon zur compilezeit gefangen
    - con: state ist im typ encodiert, macht es schwer bis unmöglich (type erasure stunts), z.b. in einer if-bedingung konditional ein feld zu setzen
- da für jeden einsatzzweck ein anderes pattern optimal sein kann, habe ich mehrere für meine struct(s) implementiert
// TODO table?

=== `OpenFlags`

// TODO: add user code call to open, check that the function looks fully functional, then we can better use the solutions from this part.
// MAYBE explain macro `bitflag_accessor`

== Error handling
// allg: conversion between rust `Result<>` and errno
// `{try,bail,ensure}_errno!()`
// Verweis auf `panics/unwind across FFI`

= Evaluation



@cwe-top25-2025

// hier CVEs auswerten, vlt oben in Methodology schon konkret auflisten
== A prototype filesystem implementation: `hello2`
// FIXME @ask geht das in die richtige richtung?

To test our wrapper library, we created a minimal filesystem using it. /* FIXME @ask duplicate zu: libfuse implt auch nur 3? */
It implements only three callbacks --- `getattr`, `read`, `open` --- as this is enough to provide a complete, usable filesystem.#cite(<libfuse_docs>, supplement: "/example_2hello_8c.html")

This filesystem is read-only, since that narrows down the functionality we have to implement.
Files are declared in a static global array, and are even associated with a closure object, to facilitate files with dynamic content. The following example shows a global file table of two entries: `time.txt`, which always reads the current system date and time, and `pid.txt`, which always reads the ID of the filesystem process.@hello2_file_table

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
