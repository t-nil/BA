// GLOBAL TODOS
// - [] fix glossary keys being displayed when no short variant exists

#import "@preview/oxdraw:0.1.0": oxdraw as mermaid

// TODO use fletcher
// @löhr: github links, doku etc.: muss das in die bibliographie rein oder reichen fußnoten?

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
  )[#rest]
}

= Outline

1. Introduction
2. Motivation
3. Review of similar solutions
4. Methodology
5. Implementation
6. Evaluation
7. Conclusion
8. Future work

= Introduction

- Rust is increasing usage in system level
- but still many big projects (linux etc.) are written in C

// MAYBE exkurs über linear types?

== Rust

== FUSE

// unterschied zur motivation:
// - "eine ebene drüber, ungenauer"
// - TODO löhr fragen: brauche ich beides, passt das so?
// - basics erklären: was ist {dateisystem,rust,typsystem,FUSE}?

@bugden2022rustprogramminglanguagesafety

= Motivation

@bugden2022rustprogramminglanguagesafety
@방인영2024study
@287352
@10.1145_3428204


- Low level APIs are dangerous when misused (by concept)
- Documentation is rarely read completely and correctly, and rarely updated consistently
- Would be nice if Compiler could enforce correct usage
- you (usually) need a strong type system for that
// TODO find grundlagenbücher about type systems / type theory (scholar, chatgpt, opac)
- Rust provides that and is usable as system language
- (see linux kernel efforts to move rust into the project, especially in filesystems area)
- can CVEs be effectively prevented?
- (Or, if non-exploitable, can crashes be prevented?)

= Review of similar solutions

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
=== Pointers
- for every C pointer we have to use
  - is it aligned?
  - is it non-null?
  - (is it valid? not checkable without allocator control or sanitizer or sim.)

=== Strings and Unicode
- rust only allows UTF-8 Strings
- although there are wrappers for C-style strings, most APIs are built to only work on Unicode
- => we disallow non-UTF-8 strings for simplicity

=== Panics across FFI boundaries
- => is UB
- have to wrap every possible panic point inside ```rust catch_unwind()```
- not provably panic-free with just compiler
  - but there is an interesting crate: `https://github.com/dtolnay/no-panic` => *future work*

== FUSE operations
- these 4 functions seem to be the bare minimum for a R/O filesystem (see libfuse example `hello`)
- open can be a noop

=== getattr
- "bread and butter" call, is the first one executed on all filesystem paths, lets user decide how to continue (readdir on dirs, read/open on files e.g.)
-

=== readdir
=== open
=== read

== Initialization / global state management
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
A non-trivial problem, that is not obvious at first sight, is how the trampoline knows which filesystem implementation to dispatch to.
There are two basic options how to use the trampolines:

1. use one global trampoline per callback, and somehow transport the choice on which filesystem to use inside the C arguments that @libfuse_wrapper gets passed by @libfuse.
2. somehow generate a set of trampolines per user filesystem, which are then hard-coded towards the specific filesystem implementation.

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
// löhr: ist es ok, die unterkapitel nach technischen (Typ-)namen zu benennen, oder soll ich allgemeinere kategorien wählen?
=== `stat`
- gives basic info about FS entry
- returned by getattr
-
=== `fuse_file_info`
=== FileMode
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

=== OpenFlags

// TODO: add user code call to open, check that the function looks fully functional, then we can better use the solutions from this part.
// MAYBE explain macro `bitflag_accessor`

== Error handling
// allg: conversion between rust `Result<>` and errno
// `{try,bail,ensure}_errno!()`
// Verweis auf `panics/unwind across FFI`

= Evaluation



@cwe-top25-2025

// hier CVEs auswerten, vlt oben in Methodology schon konkret auflisten
== Beispiel-FS `hello2`

= Conclusion

= Future work



#bibliography("bibliography.bib", style: "ieee")

#pagebreak()
= Glossary
// Your document body
#print-glossary(
  glossary-list,
)
