
#import "@preview/oxdraw:0.1.0": oxdraw as mermaid
// TODO use fletcher
// @löhr: github links, doku etc.: muss das in die bibliographie rein oder reichen fußnoten?

#set heading(numbering: "1.1")
#outline()

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
