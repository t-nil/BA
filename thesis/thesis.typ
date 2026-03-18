// # Missing chapters
// - Background/Rust/Typesystem
// - Background/Rust/Lifetimes
// - Bento
// - Rust for Linux
// - Implementation (top-level)
// - TypedBuilder (a bit of a rework) + some of the data types
// - Eval/CVEs
//
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
//   - "therefor"
//   - "atleast"
// - schauen ob citation punctuation eingehalten wird.
// - template
//   - [ ] english translation
//   - refs auf unterkapitel werden eh nicht übersetzt -> consistency (siehe einleitung.schluss)

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

One straightforward solution has always been to limit the function domain via documentation. Users of that function are expected to read that documentation and recognize that it is a violation of interface contract to call it with $$ x = 0 $$. Violation of that contract would in turn result in an error, a crash, or --- worse yet --- @UB:long. An approach with drawbacks, as there are now two sources of truth about the function domain. One of these --- the function signature, expressed in code --- is already technically incorrect, as we have not stated a way to express "integers without zero" as a valid type (@c_reciprocal). Additionally, as the program developes, the chance of both sources of truth to get further out-of-sync increases. For example, special behavior could be introduced to handle the undefined case (see @c_reciprocal_changed_contract). This discrepancy, between the high-level contract, expressible only in additional information in text form, and the function signature the compiler handles, raises the following question: Can we encode this precondition in such a way that the function signature makes it impossible to pass in values that violate any API contract? /* NEXT beispiel mit "wir crashen nicht mehr, sondern printen fehler und returnen NaN" */

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

#figure(
  ```c
  #include <math.h>
  // `n` CANNOT BE ZERO!
  double reciprocal(int n) {
    if (n == 0) {
      println("Division by 0 is not allowed!");
      return NAN;
    }
    return (double) 1 / n;
  }
  ```,
  caption: [`reciprocal()` with a changed contract.],
) <c_reciprocal_changed_contract>



// TODO maybe use contract programming thought model, and explain keywords (invariants, preconditions)

In programming languages where we have strict and strong typing /* FIXME define */, we can enforce invariants about types we create, since we have to explicitly provide the methods of construction for values of these types, and if any invariants are not upheld, we can detect this unsoundness and trigger an error. This allows us to express function signatures of the kind discussed previously, by creating a new type `NonZeroI32` that represents the idea of an integer that cannot be zero. Unfortunately, not all languages provide the features necessary to formulate such powerful types. One prominent example is C, which is predominantly used in systems level programming, both in general and in the domain we are looking at in this work.
Besides the basic datatypes that exist primarily to differentiate between CPU directives --- integers, floating points, characters, pointers --- users can create composites of these types via the `struct` or `union` constructs, and define functions to work on these datatypes only.
But these type requirements can easily be subverted, because in C, casting between different types is often implicit, and there are no mechanism to enforce invariants of a type --- all user code that can "see" a struct can create or delete instances as it sees fit.

That's why, in this work, we will look at Rust: a modern language that is gaining rapid traction in the area of systems programming, and has a strong, expressible type system as one of its flagship features .
This enables us to explore the latter approach.
@nonzeroi32_reciprocal shows such an implementation in Rust.
It utilizes the concept of a "newtype struct": a `struct` with one anonymous member, which is used to wrap this inner element and to effectively give new type semantics to it.
If the inner value is chosen to be private, ergo not visible or accessible from code from a different module, this prevents any alternative way of constructing or modifying values of this new type other than what the module creator chooses to provide.
This achieves exactly the desired effect. /* TODO evtl kürzen das knaggiger */
By making the inner value private, we then ensure that users of our library are forced to use the only construction method we provide them with, ```rust NonZeroI32::new(i32)```. This `new()` function can be total, since it returns a result value representing a fallible computation. In that sense, the function signature of `new()` expresses that *every 32-bit integer is either a valid non-zero 32-bit integer or an error*.

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

This is one of several features of Rust that promise improving soundness checking and language expressibility with no or minimal runtime impact.
System programming is an area where these soundness guarantees are especially important.
While a logic error stemming from an unchecked invariant in an application can crash this application or corrupt its data, a kernel or @OS bug can cause those failure states in any and every subsystem and program.
Faulty @OS behaviour can cause instability on every layer of the system, and endanger the work of all users. /* FIXME quote? */
Simultaneously, system programming has to produce performant instructions, since they will be running as the backbone of the @OS, which often leads to complex data structures where keeping invariants as cognitive load, for programmers to check upon every code change, is unlikely to produce said stability in the long run.
That is also why solutions that penalize compile time only are especially valuable, because compile time is often expendable --- after all, most @OS:pl run many times as often as they compile.

Our work is therefore targeting a subsystem of modern @OS development. Filesystems were chosen, because they fulfil all stated criteria: their performance matters, their correctness is crucial for stable system usage, and they deal with complicated, highly optimized data structures where invariants between those structures play a major role.
Kernel module development is not a trivial task, though, and challenges during code writing and testing would cost additional time.
Debugging is also comparably harder when the targeted module is injected into the @OS itself.
FUSE (#strong[F]ilesystem in #strong[USE]rspace) offers a way out for this conundrum @linuxkernel_fuse_docs.
It is a framework that works by combining a kernel module with a userspace library.
Filesystems using it link against the userspace library and use it to communicate with the kernel module, which will redirect @OS requests to the userspace program.
This provides an environment not unlike a sandbox: the kernel module is well known and tested, and approximately bug-free.
The concrete filesystem, which we will implement, will live in userspace and therefore be easy to debug and not critical to system stability.
And since the APIs are quite similar, approaches found to be working when modeling FUSE filesystems will with high probability also work in general, e.g. as native kernel modules.

In the following thesis, we will introduce the chosen tools Rust (#ref(<ch_background.rust>)) and FUSE (#ref(<ch_background.fuse>)), followed by a comparison to similar works (#ref(<ch_related>)). A methodology is introduced (#ref(<ch_concept>)), and the implementation thereof described in detail (#ref(<ch_impl>)). Then we evaluate our solution against a sample of #glspl("CVE", first: false) (#ref(<ch_eval>)) and draw our conclusion (#ref(<ch_conclusion>)). Finally, we discuss possible future work (#ref(<ch_future>)).

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

In the following sections we will describe tools Rust and FUSE, and the features they bring that make them suitable for our thesis.

== Rust <ch_background.rust>

// - Modern language with many features that can increase correctness and safety
// - is marketed/intended as a low level language, usually competes near C in benchmarks
//   - Rust in Linux kernel
//   - RedoxOS
//   - coreutils / libc rewrite /* canonical/ubuntu? cite o/

Rust is a modern programming language, created in 2006 by a Mozilla employee and endorsed by Mozilla in hopes of creating a safer web browser engine.
It is intended for use as a low level systems language, usually competing with C in benchmarks @10.1145_3102980.3103006;
compared to C, it incorporates numerous improvements aimed at increasing safety and automatic correctness of written software, with minimal to no runtime impact
@Thompson2023RustFastestGrowing.

=== Type system

@MILNER1978348 @WRIGHT199438

@jung2020safe @10.1145_3360573
// TODO more in-depth

Rust's type system, or rather the specific properties thereof, are an important factor for its usability in correctness-centered software.
We will focus on two important characterizations of a type system: static vs. dynamic, and strong vs. weak.
We define (as seen in #cite(<10.1145_942572.807045>, form: "prose")) a strong type system as a system where every function that expects a certain type of parameter will only accept parameters of that type.
In other words, the less implicit type conversions are performed by a type system, the stronger it is deemed.
In contrast, weak type systems perform many implicit conversions.
Static type systems, as previously defined in #cite(<10.1145_942572.807045>, form: "prose", supplement: "p. 474f"), have the ability to calculate types of all values during compilation, and can therefore statically verify type correctness.
In dynamic type systems, the concrete types of values are indeterminate during compile-time and the compiler will emit the necessary runtime checks that result in execution errors when a type mismatch happens.

We value the strength of a type system highly, because it provides us with the foundational guarantees on which the higher-level contracts can be expressed.
For example, given we want to enforce that a file handle be in a specific, well defined state (open, writable) before writing to it, with a weak type system, we would have two possible scenarios for inconsistency: the file handle implicitly converting into another type, which potentially doesn't check those contractual assertions, and a value of another type implicitly converting into a file handle, where the conversion itself possibly circumvents some checks.
Additionally, strong type systems can prevent bugs of a certain class, where the wrong value is passed into a function, if that value has a different type.
The weaker the type system, the more implicit conversions may accidentally trigger, which would make the program compile without catching the type error.
This is not to say that all implicit conversions are inherently bad, but they pose certain risks and are usually hindering when trying to reason about program code, since every possible place where an implicit conversion could take place exponentially adds possible states that must be considered.
On the other hand, implicit conversions can lead to more concise code and can reduce boilerplate, which, when applied correctly, can improve readability and ability to reason about code effects.
Ergo a middle ground should be found.

Rust takes a strong design stance in that regard #cite(<rust-reference-1.92>, supplement: "ch. 10.7").
The language philosophy is to use as little implicit conversions as possible, to limit the amount of "surprises" encountered when reasoning about code effects.
This is a design principle that aligns well with our goals.

The aspect of static vs. dynamic type checking is also of importance for our thesis.
Dynamic type checking would bring two disadvantages in this case.
First, type errors are reported not during development, but during actual code execution.
This not only delays the bug finding process, but also requires that every part of the program be executed during testing to ensure correctness.
Second, since we aim to enhance type checking to also maintain our higher-level invariants, this comes at the cost of additional logic.
Whereas static type checking would run this logic only during compilation, dynamic type checking leads to runtime overhead, which is usually a critical property of system code, to be reduced whenever possible.

Rust is a predominantly statically typed language, with optional dynamic typing (see #cite(<rust-reference-1.92>, form: "prose", supplement: "10.1.15")) by the name of "trait objects".
This is consistent with other high-level languages, like C++ #cite(<cppreference>, supplement: [section "Type"]).
This gives us the flexibility to fall back to dynamic typing whenever necessary, while having a rich toolset available for expressing type constraints in a static, compiler-verified fashion.

// a.k.a. borrow checker :sunglasses:

// mention RAII and ```rust Drop``` trait

=== Borrow checker, lifetimes and ownership

One of the core improvements made by Rust in the area of static correctness is its memory model, centered around ownership, static reference tracking and reference lifetime @10.1145_3360573.
In Rust, values are, by default, moved instead of copied.
In fact, making a type copy-able involves implementing a special trait (```rust Clone```), while moving values is core to the type system and automatically available for every type.
In contrast, types are memory-copied by default in C++, and must manually influence or prohibit that behavior @cppreference.
Moving values was introduced in C++ 11 and has to be enabled manually.
This core difference, called "linear types" in type theory, brings a range of benefits to the type system @wadler1990linear/* FIXMEE bessere ref? nicht mathe paper, was praktisches */.



=== No data races and fearless concurrency

Concurreny is an important aspects of today's software.
Single maschines usually have several physical processor cores, and programs wanting to take advantage of the hardware capabilities need to deal with some variant of concurrency.
Furthermore, even not hitting hardware limitations, modern software usually consists of multiple distinct subroutines --- rendering a GUI, receiving events, working calculations, providing an API --- that are desired to run simultaneously, lest responsivity and latency suffer, and with it the user experience.
This is also true for @OS code and filesystems, as these too must take advantage of modern computer architecture to deliver performance goals.
A filesystem on a typical modern computer can expect many different programs to concurrently access different files, or even use the filesystem for inter-process communication.
This makes managing concurrency scenarios mandatory.
For example, BtrFS spawns many worker threads to handle the background work necessary to maintain the filesystem structure @btrfs.5_manpage.
Concurrency, while ubiquitous, brings many implementational challenges in modern languages.
C, for example, declares every data race @UB @c_standard.
Rust differs from these in that it leverages the type systems to make certain guarantees in concurrent programming, namely that data races cannot occur.

Data races happen when data is shared mutably between threads without proper synchronization, mutably meaning more than one thread has the means of modifying the state @10.5555_998680.1006709 @linux-kernel-memory-barriers.
Since execution order of instructions between multiple threads is undefined, when multiple threads attempt to change the shared data at the same time, the outcome --- the state of the shared data --- is also undefined.
This arises simply from the fact that reads and writes from the different threads can be interleaved arbitrarily and nondeterministically by the processor, resulting in operations that seem atomic or sequential to the programmer being interrupted or reordered.
/* @ask stefan example? */
/* _ask mehr eingehen auf parallel/concurrent/async/thread/task/foo? => no, its ok */

@data_race_example shows a simple case of a data race.
Picture the `counter()` function running concurrently in two threads.
Each instance has the goal of increasing the global counter by one, a million times.
Yet, as we execute this program multiple times, different values will be reached, ranging from 1,000,000 to 2,000,000.
This is due to operation reordering: since an increment is internally a sequence of "read value" -> "increase" -> "write value", when these instructions get interleaved, multiple threads interfere with each others incrementation, leading to loss of writes.

#figure(
  ```rust
  static mut COUNTER: usize = 0;

  fn counter() {
    for i in 0..1_000_000 {
      unsafe {
        COUNTER += 1;
      }
    }
  }

  pub fn main() {
    let t1 = std::thread::spawn(&counter);
    let t2 = std::thread::spawn(&counter);

    println!("{COUNTER}");
  }
  // ...
  ```,
  caption: [Excerpt from the `readdir` trampoline, passing the Rust vector of directory entries into the C filler function.],
) <data_race_example>


Since data races can lead to program states that are hard to reason about, automatic prevention would be beneficial to the development process @rust-reference-1.92.
By encoding the "concurrent-safe-ness" of data types in the type system, Rust brings about such a mechanism.
There are two traits that function as markers for these properties: ```rust Send``` and ```rust Sync```.
```rust Send``` signals that variables of this type can safely be transferred between threads, while ```rust Sync``` declares a type is safe to be accessed simultaneously by multiple threads.
These traits contain no members, since their only function is marking thread-safety.
Manually implementing them requires an unsafe block, since it is up to the programmer to check that the type really is thread-safe;
on the other side, types only consisting of ```rust Send```/```rust Sync``` members can have their ```rust Send```/```rust Sync```-ness derived automatically via a macro.

As a side note it should be mentioned that while safe Rust guarantees freedom of data races, code races or deadlocks can still happen.
We assume that these cannot be prevented in sufficiently powerful languages, as that would require checking every possible combination of thread execution states, which is NP-complete in recursion to the halting problem.

=== Error handling

One of the strong points of Rusts stance on a strong and flexible type system comes with its choice in error handling.
One common pitfall with C, that is the cause of many production bugs, is that C uses patterns to signal errors that are implicit,
usually reserving part of the range of the function for error codes, and sometimes storing additional info on the error in a global variable --- commonly `errno`.
This handling is implicit because, since the return type doesn't inherently encode the possibility of an error, manual checks by the programmer must be inserted for every potential source of errors, which increases cognitive load.
Forgetting to insert such a check almost always leads to unsoundness, since a potential error will be handled as some sort of valid success value.
Circumstances are even more difficult when dealing with `void` functions, that don't return a value but rely on side effects instead.
Since no return value handling is required for "normal", non-error code paths, the chance of forgetting to check for errors is increased again.
Although some C compilers define custom extension attributes that can annotate a function to emit a warning when the function's result is unused#footnote[https://gcc.gnu.org/onlinedocs/gcc/Common-Attributes.html], no standardized solution exists.
@tian2017automatically

Rust solves this issue by combining the strong type system guarantees with sum types, or tagged unions.
Unions, as they are used in C, are usually only useful in implementing low-level data structures or protocols where memory efficiency is of grand importance.
Since they require the programmer to keep track of which data type is stored inside them at any moment --- or, to manually track this state via extra variables --- variable accesses of invalid type are encouraged, often leading to undefined behaviour.
Rusts decision to introduce labelling leads to strongly-typed unions --- called `enum`s in Rust --- that are always checked, by nature of the type system.
The programmer is forced by the compiler to handle every occuring case explicitly, and where dynamic handling is required, runtime checks are emitted at the least.

Rust then introduces the "result type", ```rust enum Result<T, E> { Ok(T), Err(E) }```.
This represents a tagged union two type parameters: the success type `T` and the error type `E`.
With this, a function from ```rust A -> B``` can trivially be transformed into a fallible function ```rust A -> Result<T, E>``` with error type `E`.
```rust A -> Result<T, E>``` can never be accidentally be misused as `T`, nor `E`: the type system enforces the values be unpacked and every case handled accordingly.
Therefore, there is no need to encode error states in numeric return values, such as the Linux kernel using negative return values for error signaling.
This must be considered a hack, as it severely limits the design space of functions, and diverges program semantic from the specified data types.

Coupled with Rust's ```rust #[must_use]``` function annotation, which is set on the STD ```rust Result``` implementation, Rust prevents accidentally not handling error results, whether by ignoring a return value or by using a fallible result.

// - features // stefan: auf 3-5 beschränken, mit unterkapiteln
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

== FUSE <ch_background.fuse>
// - filesystem as process in userspace
// - don't have to build kernel modules (safer, easier dev workflow)
// - should be comparable though (why? give reasons)
// - architecture (/* TODO image */)
//   - fuse kernel module
//   - libfuse
//   - FS impl
//   - *=> our layer*

#align(center, [#image(
    "images/FUSE_structure.svg",
    alt: "User Application <-> glibc <-> (Kernel) VFS <-> (Kernel) Fuse Kernel Module <-> glibc <-> libfuse <-> FUSE User Level Daemon",
    width: 70%,
  )#footnote[https://commons.wikimedia.org/wiki/File:FUSE_structure.svg]])

FUSE (#strong[F]ilesystem in #strong[USE]rspace) is a mechanism for filesystem modules in the Linux kernel, introduced in `2.6.14` in 2005 @linuxkernel_changelog_2_6_14 @linuxkernel_fuse_docs.
It lifts the requirement of filesystems being kernel modules, which meant they run in kernel space and therefore have the highest priviledge level, which potentially impacts security and stability of the system.
Additionally, installing a new kernel module involves a great amount of additional work:
At best, the module has to be compiled via @DKMS against every kernel in use by target machines.
At worst, a copy of the kernel source code has to be maintained with the filesystem module added, and on every upstream kernel update the whole kernel has to be recompiled.
Kernel modules also operate under a strict subset of available tools and resources, and are more complex to program, which increases development costs @miller2021high.
Being able to write filesystems as generic userspace programs can therefore yield various benefits.

The FUSE project replaces the need for a distinct kernel module per filesystem by providing a general module, which the userspace daemon then communicates with.
The necessary kernel APIs can therefore be forwarded via a message socket, solving the need for elevating filesystem code to kernel mode.
A more familiar experience is provided through @libfuse, which is a C library presenting an array of functions and types with an API similar to that of the kernel.
This abstracts away the message passing style of the daemon, and enables users to simply implement the functions established in the @POSIX filesystem section --- `read`, `mkdir`, `ioctl` and similar.
This creates the illusion that implementing a filesystem is nothing more than providing a set of function bodys for the filesystem API inside `libc`, which takes away much of the complexity behind the scenes and enables creating simple filesystems with low development cost and entry barrier.



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

// TODO I talk about programming in general but clearly focus on an early machine-level language like C. state explicitly?


= Related work <ch_related>

== Bento

// - paper refs:
//   - fuse performance: 48, eval
//   - file system crash finder: CrashMonkey (37)

// - sandboxed Rust FSs in linux kernel
// - can be restarted/swapped/updated without interruption to userspace
// - eval: performance
//   - comparable to native ext4
//   - 7x faster than FUSE (on git clone)
// - ?? file provenance tracking ??
// @miller2021high

#cite(<miller2021high>, form: "prose") propose a problem space similar to our work: filesystem development is tedious, because kernel modules are hard to debug; a filesystem kernel module crashing the system through bugs is also suboptimal.
Having said that, in their evaluation FUSE falls short because of significant overhead introduced into metadata-heavy workloads --- such as `git clone`#footnote[https://git-scm.com/docs/git-clone] of big repositories --- which incentivized them to develop a novel solution.
Bento is a framework for developing Linux filesystems that plugs into the @VFS kernel component and provides a sandbox for filesystem implementations written in Rust.
Modules using this framework can be loaded, reloaded and updated without interrupting userspace work, and have their crashes isolated from the rest of the kernel, increasing resilience to filesystem bugs.
// FIXME not finished right?

== `rust-fatfs`

#cite(<Oikawa2023>, form: "prose") present a Rust reimplementation of the FAT filesystem family created by Microsoft.
FAT (File Allocation Table) was originally created in 1977, with the newest variant --- `FAT32` --- initially published 1996.
Despite that, it stays relevant until today, as it is often used in technically constrained environments, where it is preferred for its comparatively simple structure and implementation.
For this reason, it is relied upon by digital cameras for their dedicated storage cards, and as filesystem for the boot partition in the UEFI specification #cite(<uefi_spec_2_11_2024>, supplement: "p. 462") @microsoft_kb_q154997_fat32__mirror@ecma_107_1995_pdf.

`rust-fatfs` implements the `FAT12`, `FAT16` and `FAT32` members of the FAT family. It is implemented as a kernel module, whereas our library lives in userspace with the usage of FUSE. The authors were motivated by lack of existing filesystem kernel modules written in Rust, as well as a general interest in Rust given its recent rise in popularity regarding the linux kernel, and its promising safety features.
`rust-fatfs` was solely evaluated from a performance perspective, with the authors measuring the number of instructions executed during sample workloads, run inside a VM. These metrics are compared to the established C kernel module. We did not consider empirical performance analysis, and focus on which kinds of CVEs can be prevented.

== `fuser`

The `fuser` crate, maintained by GitHub user `cberner`, is currently the most used FUSE bindings crate on `crates.rs`, counting over 150k downloads per month, and over 1k stars on GitHub @fuser_docs.
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

= Concept <ch_concept>

// - read similar rust projects, get idea about how the structure and approach would look for the libfuse bindings
// - read up about `cbindgen` by mozilla (will def. need to use it)
// - read up about theoretical foundation of type systems and using them to encode programmer contracts

First, we study works that explore safety aspects of Rust features, especially regarding its type system.
We also study similar works to this thesis that leverage Rust to write safety-focused system code.
We extract principles and patterns, which can then be applied to constructs and invariants encountered when developing an API for filesystems.

// - for every libfuse API call:
//   - decide if in-scope
//   - enumerate a list of (sensible) contracts
//   - encode through type system
//     - if that fails or becomes too hard, skip them and document that

To limit the scope of this work, we filter the list of needed FUSE operations to provide an API for a minimal file system.
For each operation deemed necessary, we enumerate a list of contracts and invariants that are either explicitly or implictly expressed in code or documentation.
We then decide for each invariant, if and how it can be incorporated in our system of checks, prioritizing static analysis and compile-time correctness over automatically emitting runtime checks.
For each invariant that is regarded impossible to check in this sense, we document the shortcomings of our system and potential improvements for the future.

// - (if possible) collect filesystem related CVEs from databases
// - (else) CWEs allgemein sammeln
// - match CVEs/CWEs with libfuse calls, find potential weaknesses/threads
// - evaluate if my rust constructs can fix those weaknesses. if not, try to improve bindings.
// - create stats and tables (e.g. percentage CVEs prevented, taken from a) sub section X, b) time span Y, etc.)

The CVE (Common Vulnerabilities and Exposures) system is an internationally accepted, de-facto standard, cataloguing system for vulnerabilities FIXME. In colloquial terms, "a CVE" refers to an entry in the CVE database, managed by MITRE.
For evaluation, we collect a sample of recent recorded CVEs from the Linux kernel filesystem subsystem.
This e.g. includes the @VFS and several shipped filesystem implementations.
We utilize a search mask for the National Vulnerability Database#footnote[https://nvd.nist.gov/] for filtering the relevant data.
Each CVE from the sample is then analyzed and sorted into three categories:

#[
  #show table.cell: set text(size: 0.9em)
  #table(
    columns: 3,
    [🟢], [🟡], [🔴],
    [Could have been prevented using our method],
    [Could partially have been prevented / could have been prevented under certain circumstances],
    [Could not have been prevented],
  )
]
We include reasoning for every categorization, and if deemed non-preventable, we document what could be improved in our method, or why the problem is out-of-scope for our thesis.

// - write introduction with foundational concepts


= Implementation <ch_impl>
// diagram (petrinetz)
// describe every part
// describe design decisions
// tables with pro/cons, interactions of components

// FIXME @important: image rendering
//#align(center, [#image("images/architecture.png", width: 120%)])

== Basic C interop
// source: rust unsafe invariants
// - https://rust-lang.github.io/unsafe-code-guidelines/ => obsolete, out of date?
// - https://doc.rust-lang.org/nomicon/what-unsafe-does.html => too informal?

// FIXME bindgen

Excluding internal compiler errors, safe @Rust can never cause @UB in the resulting binary program. /* TODO quote */
In unsafe @Rust, this is not the case; the programmer now has to uphold several invariants to ensure @soundness. /* TODO quote */
Unlike in the C standard, where behavior in any situation not explicitly defined by the language standard is implicitly “undefined“, Rust limits these invariants to a set of specific, well-documented cases @c_standard #cite(<rust-reference-1.92>, supplement: "ch. 17.2").
This makes reviewing the @soundness property of unsafe code easier.

=== Pointers <ch_impl.pointers>

// TODO shorthand for u/i8, u/i16.
// EXTRA what are pointers? stefan "abstraktion über adressen? 'obermenge von references'"

Regarding use of raw pointers in unsafe Rust, the following invariants exist:

1. No dereferencing of @dangling or #gls("alignment", display: "unaligned") pointers.
  This is obvious, since these requirements stem from the underlying hardware, and C also declares them invalid @c_standard#cite(<rust-reference-1.92>, supplement: "ch. 17.2").
2. Respect aliasing rules: no pointer is allowed to point to memory that's also pointed-to by a mutable reference, since a mutable reference in Rust is guaranteed to be exclusive.
  This is needed to provide same of Rusts safety guarantees: data races, use-after-free errors and iterator invalidation are all inherently impossible without shared mutable state.
3. Respect immutability: no pointer is allowed to modify data that's also pointed-to by a shared reference, since a value behind a shared reference is guaranteed not to change.
  This also follows naturally from the basic type system axioms in Rust:
  if a reference pointing to a value is held, then by rule 2 it is guaranteed that no mutable reference to this value exist simultaneously.
  Therefore the value mustn't change.
4. Values in memory must be valid for their respective types: pointers must not be used to change the representation in memory of to a value --- or reference --- to a state which is not valid for the type this value --- or reference --- has.
  E.g. a `NonZeroU8`, represented in memory as a `u8`, will have one bit pattern that would correspond to a numeric zero and is therefore illegal.
  This rule is also emergent, following from the basic type system principle that variables of a type must hold values of exactly that type.
  Circumventing this would completely subdue the advantages arising from Rust's powerful type system.

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

=== Strings and Unicode <ch_impl.strings_unicode>

Rust's native string types (`str`, `String`) exclusively store UTF-8 #cite(<rust-book>, supplement: "ch. 8.2").
The main kind of strings this library needs to handle are the file paths that filesystem callbacks are called on.
The encoding of those is platform-dependent, usually being C-like ASCII strings on Unix-like systems and UTF-16 on newer Windows versions. /* TODO cite, stefan sagt "since nt und das ist != newer" */
Correctly detecting and handling string encodings is a hard problem  /* MAYBE cite? */, and since UTF-8 is a superset of ASCII, we chose to not handle UTF-16 or other cases and emit an error when encountering non-UTF-8 input. This limits the complexity of the prototype without limiting the scope of the reseach question.

/* TODO nul termination */

=== Unwinding across FFI boundaries <ch_impl.unwind>
// - => is UB
// - have to wrap every possible panic point inside ```rust catch_unwind()```
// - not provably panic-free with just compiler
//   - but there is an interesting crate: `https://github.com/dtolnay/no-panic` => *future work*
// EXTRA what about possible (hidden) panics in my own code? integer overflow, slice indexing etc.

When a Rust program is compiled with stack unwinding support and a @panic is triggered, the default unwind handler will walk up the stack in order to react to the panic, collecting debug information or cleaning up data #cite(<rust-reference-1.92>, supplement: "ch. 14").
In a program using FFI, this can lead to crossing into another language runtime while walking the stack.
Doing so correctly is a non-trivial task and can easily lead to @UB.
On the other hand, turning unwinding off causes helpful stack traces and debug information to be lost when a @panic occurs.
We therefore decided to keep unwinding behaviour while preventing any panic from propagating across an FFI boundary.

Every function that is visible to C can potentially be called from an environment where unwinding works differently --- or not at all.
Therefore each of those functions must be @panic-free.
As of now, there is no compiler flag or lint that detects or prevents use of panicking functions, operators or language keywords.
As a result, this requirement must be checked manually by reviewing the source code of the functions in question, and, recursively, the functions they call.
A convention exists to note possible panics in a section of the function documentation, but even the standard library doesn't consistenly follow it.
// MAYBE enumerate sources for panics

While preventing panics in self-maintained code requires careful manual analysis, this is not possible for user-provided functions.
For this, there exists a function ```rust panic::catch_unwind()``` @rust-std-1.92 that takes a closure and executes it, catching any unwind that would occur and returning an error instead.
Wrapping the call to user code inside this function ensures that no panic will be propagated up the call stack from this point on @catch_unwind.

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
If we can forgo modifying the state, and create a read-only filesystem, the number of required calls can be brought down to 3 #cite(<libfuse_docs>, supplement: "p. structfuse__operations.html") #cite(<libfuse_docs>, supplement: "p. example_2hello_8c.html").

Some of the operations which are superflous for our experiments include:
- `lock`/`flock`: These are used for file locking, enabling safe concurrent access, and locking primitives across processes. Since our filesystem is readonly, no locking is needed.
- `ioctl`: Needed for special I/O commands, when simple seeking to byte offsets, and reading/writing from them is not sufficient. Examples include ejecting CD-ROM or rewinding data tape. Not needed for our general-purpose minimal filesystem.
- `write`/`sync`/`fsync`: These are used for writing data out, and to force flushing buffers to the underlying storage. Irrelevant in a read-only filesystem.
- `mkdir`/`link`/`create`/`mknod`/`unlink`/`rmdir`: Creating and deleting of entries of various types. Not relevant for a read-only filesystem.

All implemented operations check their pointer arguments for validity, with the methods discussed earlier (@ch_impl.pointers).
The obligatory `path` argument, that identifies the entry to operate on, is converted from a C string into native Rust, and also checked for validity (@ch_impl.strings_unicode).
After basic correctness of inputs has been ensured, the code tries to load the filesystem object from the global registry.
This is done to minimize unneccessary work when some inputs are not sound.
The load could fail, e.g. in case the user code triggered a @panic earlier, or due to a bug in the wrapper library. This is also handled (@ch_impl.init).

After that, some operation-specific instructions are executed, and a context is set up to call into user code without triggering panic unwinding (@ch_impl.unwind).
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

This function's job is, given a directory as path, provide a list of child entries, enabling directory content listing (as e.g. in the `ls` command). An offset can be provided to support partial listings over multiple calls, however we chose to ignore this, as is allowed in the documentation #cite(<libfuse_docs>, supplement: "p. structfuse__operations.html").

There exists an alternative, more complex mode, which we could have chosen to support: Implement the additional `opendir` operation to open the directory to enumerate as a file descriptor. Then, `readdir` is called on the active file descriptor, providing a view of the directory that is guaranteed to be the same as when `opendir` was called. This was deemed unneccessary to explore the given research questions, and skipped subsequently.

The API is designed, so that the `readdir` implementation doesn't just return, or write into, an array of entries.
Instead, a function pointer to a "filler" function is provided.
Our operation has to call this function for every entry.
Some of the filler functions parameters correspond to entry metadata, others, like a pointer to an opaque data buffer, have to be forwarded @readdir_filler_fn#cite(<libfuse_docs>, supplement: "p. structfuse__operations.html").

#figure(
  ```rust
  // ...
  for entry in entries {
      let entry_as_c_string = try_errno!(CString::new(entry.clone()).map_err(|e| {
          // convert Rust string to C string
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
          // propagate errno
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
Further investigation showed that maximum read size is limited by the Linux kernel #cite(<read.2_manpage>), so the limitation in the API seems reasonable, assuming other operating systems impose similar limits.
We therefore have to carefully check if the input parameter is inside the allowed range, and convert between the respective integer types, in addition to the usual checks.
Furthermore, Rust does not provide a native method of specifying an upper bound for a vector length as part of the type signature, so manual checks are required after the user code returns the data.
Dependent types or refinement types would be a possible solution, but are not available in Rust aside from research projects @lehmann2023flux.

If the size checks pass, a pointer copy is issued, for which Rust STD provides a function.
Because we use `unsafe`, we documented the assumptions made and invariants we checked, as is common practice (@read_copy_nonoverlapping).

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

== Initialization and Global State Management <ch_impl.init>

The libfuse initialization routine takes a struct of callback function pointers (`fuse_ops`), which creates the following problem:
since the C signature is predetermined, user functions cannot be used, because that would force signatures of user functions to use the lower-level C types which we try to avoid.
That means, even though there is a one-to-one correspondence between FUSE operation callbacks and trait methods on the `Filesystem` trait, they are not compatible and cannot be used interchangably.
The obvious approach is to provide #glspl("trampoline_function"), which then wrap, transform and safety-check the C type values on call and dispatch into user code.
A non-trivial problem, one that is not obvious at first sight, is how the trampoline knows which filesystem implementation to dispatch to.
There are two basic options how to use the trampolines:

1. Use one global trampoline per callback, and somehow transport the choice on which filesystem to use inside the C arguments that @libfuse_wrapper gets passed by @libfuse.
2. Somehow generate a set of trampolines per user filesystem, which are then hard-coded towards the specific filesystem implementation.

A way to implement option 1 is provided in the form of a ```c void *private_data``` pointer that can be passed to @libfuse during filesystem registration. This pointer can contain arbitrary user-specified data, and is not used by @libfuse except for making it available to every fuse operation via the ```c fuse_get_context```#footnote[https://libfuse.github.io/doxygen/fuse_8h.html#a5fce94a5343884568736b6e0e2855b0e] function.

Since it is possible to store a Rust pointer inside a C void pointer, @libfuse_wrapper can submit a pointer to the user implementation as payload for `private_data`, then let each trampoline poll the FUSE context struct, cast the void pointer back to a trait object reference and dispatch into the corresponding trait method.
This has the following disadvantages:
- Decaying a managed Rust reference into a raw pointer loses the advantage of lifetime tracking that is one of Rusts fortes in the /* TODO kampf/anstrengung/undertaking */ undertaking of creating safe systems-level code. Manual care has to be taken not to invoke a use-after-free, accessing an uninitialized or unauthorized memory location or --- in the best case --- simply leaking memory. In fact, the safest option would be to initialize this data pointer once, and then never free it, since it is the dealloc part that introduces memory unsafety to a system /* TODO quote? */, and even if leaking memory (and not calling destructors) is acceptable, since @libfuse passes around non-const pointers to everything, bugs at any point of both our trampolines and @libfuse can easily lead to access of corrupted pointers and therefore to @UB. This is usually a tradeoff that must be accepted when dealing with FFI into unsafe languages, but should be mitigated whenever feasible.

// FIXME no second disadvantage?

Both disadvantages would in theory be prevented by a solution after option 2.
Fortunately, with the use of generics, Rust brings includes the tools to implement such a solution.
As seen in @trampoline_fn_signature, this exemplary trampoline function is generic over types implementing our `Filesystem` trait.
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
Otherwise, runtime checks are emitted to still provide correctness, but at the disadvantage of producing runtime errors instead of halting compilation, which increases development cost @boehm1984software.
It would be common practice in low-level Rust crates to provide ```rust *_unchecked()``` variants for these runtime-checked methods, to give users the choice of circumventing those checks and trading performance for possible @UB.
Due to the goals of this work, and time constraints, this was mostly skipped.

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
Methods on these concrete types, which after @monomorphization are the ```rust PointBuilder``` with a concrete state as type parameter, that return a ```rust PointBuilder``` with a different state type, represent transitions between those states.
This is intuitive because, as a transition can only be applied to the start state and results in the end state of that transition, methods on a type can only be run on an existing value of that type, and always produce the return value.

The implementation using generics has a few advantages:
Since all intermediate types are specializations of a general builder type, there can be methods on the general builder type, which correspond to transitions on any starting state. /* FIXME macht das hier sinn? überhaupt nochmal typestate<->builder überdenken */

While a typestate builder has many advantages in statical correctness, conditional branches can be difficult to handle.
That is because every state of the builder is effectively a different type, and Rust doesn't allow items to have different types depending on a branch.
This is encountered frequently when dealing with complex generics, and while staying inside this type abstraction, there is no solution besides avoiding conditionally setting fields, and instead executing the conditional code only while calculating the value/* FIXME example */.
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

Our attempt at modeling lead us to break down the struct into smaller parts, which require more attention: /* FIXME @ask stefan: noch notwendig? kurzes statement, warum die gut geeignet sind. bissi expliziter halt. zb: es gibt bestimmte komponenten, da macht es sinn die extra zu behandeln, weil gut zu prüfen bla etc…. eigl in extra absatz */
- `FileType`, which is an enum flag of several possible values that have to specifically match magic IDs from the corresponding C header.
- `FilePermissions`, which are stored as a positive integer and usually displayed as an octal number in the range of `0o000` to `0o777` and represent restrictions on reading, writing and executing the underlying entry.
- three bitflags (`setuid`, `setgid`, and `vtx_flag`), that are context-dependent and enable additional features. These are stored inside the permissions integer in the underlying Unix APIs.

Other fields, like file size and modification time, were not deemed as interesting, since it can be correct for them to assume every valid bit pattern the underlying C type can represent, and checking the correctness semantically would introduce significant runtime overhead. E.g. validating modification time would have to detect modification in arbitrary files, and file size is an attribute that the wrapper has no insight into. Further insight into this problem is provided in #ref(<ch_eval.prototype>).

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

= Evaluation <ch_eval>

To evaluate the effectiveness of our approach, we collected a sample of CVEs found in the filesystem modules of the Linux kernel in recent years.
We then categorized them based on whether the approach discussed here would have been effective in preventing them.
We also implemented a simple prototype filesystem using our wrapper, to provide a reference point for the ergonomy and expressiveness of the API.

== CVEs

// - why CVEs in general
TODO /* FIXME quote */

// what CVEs ? why filter

// evaluation strategy

// result

@cwe-top25-2025


#[
  #show table.cell: set text(size: 0.9em)
  #show figure: set block(breakable: true)
  #figure(
    [#table(
      columns: 4,
      table.header([*CVE ID*], [*Problem*], [*Solution*], [*Score*]),
      /*[2011-0699],
      [Unexpected signedness FIXME deutsch: unerwartete signed/unsignedness von operatoren führt zum overflow
        (und AFAICS zu negativen kmalloc sizes)],
      [ich habe wrapper `Wrapping<Num>` und `Saturating<Num>`,
        und ich kann trivialerweise zB noch `Checked<Num>` bauen.
        damit gebe ich gleichzeitig das verhalten des systems vor
        (kein surprise overflow) und habe zusätzlich eine klare
        annotation ggü der programmierperson, welches verhalten
        auftreten wird.],
      [🟡],*/

      [2025-21646],
      [@procfs expects maximum path length of 255, this was overseen by @afs implementors, leading to a runtime error],
      [if @procfs API were implemented per my concept, maximum path length could be encoded in the type, so compiler could warn/error on oversight],
      [🟢],

      [2024-55641],
      [When quota reservation on XFS fails due to IO errors shutting down the filesystem, inodes were mistakenly not unlocked during cleanup.],
      [Implementing inodes in Rust can make use of the `Drop` trait, automatically unlocking them as they go out of scope #footnote[see also _RAII_].],
      [🟢],

      [2024-45003],
      [Inside the @VFS layer, during inode eviction, a race condition can result in a deadlock when inodes that are marked for deletion get accessed by a filesystem.],
      [Rust provides no builtin solution to race conditions. While data races are automatically prevented in safe Rust, preventing deadlocks still lies in the hands of the programmer.],
      [🔴],

      [2022-48869],
      [A data race in the `gadgetfs` implementation can lead to use-after-free.],
      [This is a classic example of a multithreaded program not using the correct synchronization primitives for shared mutable state. As long as safe Rust is used for access of this state --- in a hypothetical Rust-only implementation ---, data races are guaranteed by the language to not occur. (However, using unsafe Rust could limit this guarantee.)],
      [🟢/🟡],

      [2024-42306],
      [In the `udf` kernel module, when a corrupted block bitmap is detected, allocation is aborted but subsequent allocations will still not check the fail state and instead blindly use the allocation buffer, leading to undefined state. The solution was to use a "verified" bit to check the bitmap for validity.],
      [This depends: if the "verified" bit existed before the issue was found, but was erroneously not checked, this can be prevented through stricter type modelling in Rust. However, if the case in question was simply not considered during implementation, and the mentioned bitflag was introduced as solution, then this constitutes a typical logic error where not all possible system states are considered, and cannot be prevented by our approach.],
      [🟡],

      [2024-46695],
      [A root user on an @NFS client can, under specific circumstances, change security labels on a mounted @NFS file system. This happens because a mandatory permission check was overlooked, which was documented in the contract of the function ```c __vfs_setxattr_noperm()```.],
      [Our approach would allow to enforce these permission checks as part of the type system, either by a type around ```c __vfs_setxattr_noperm()``` performing them itself, or by only yielding the correct marker types when the permissions are checked.],
      [🟢],

      [2025-38663],
      [A sanity check for invalid file types was missing from the `nilfs2` module.],
      [As concretely shown within the ```rust FileType``` enum in our wrapper library, construction of the enum from an invalid file type ID would have automatically resulted in an error.],
      [🟢],

      [2023-52590],
      [Due to an interaction with @VFS, renaming a directory on `ocfs2` could result in filesystem corruption, because a lock was not properly aquired.],
      [Although, in theory, this would be part of the @VFS contract that we could try to encode in the type system, this looks like a logic error as result of a complex interaction of modules. This kind bugs are notoriously hard to avoid completely by software tooling, because they require a detailed high-level understanding of components and contracts that is usually very hard to express in a machine-understandable way.],
      [🟡/🔴],

      [2024-50202],
      [In `nilfs2`, errors were ignored in a procedure searching for directory entries. This could lead to a hang later on when the error are rediscovered.],
      [Error handling is one of Rust's strengths, because they are wrapped into the return type and the language requires the programmer to give explicit instructions on how to react to the error case. This is different in C, where errors are usually hidden away in global state, or --- while part of return value --- there is no mechanism to force explicit handling.],
      [🟢],

      [2024-47699],
      [A potential null pointer dereference was found inside `nilfs` when dealing with a corrupted filesystem.],
      [While unsafe Rust does not prevent accidental null pointer /* FIXME NonNull? */ derefs, since we abstract away pointer access in our wrapper, and let the user deal only with native Rust owned values and references, this problem would be solved by @Libfuse_wrapper],
      [🟢],
    )],
    caption: "A listing of selected CVEs plus their assessment in terms of preventability",
  ) <tbl_cve_eval>
]


// hier CVEs auswerten, vlt oben in Methodology schon konkret auflisten
== A prototype filesystem: `hello2` <ch_eval.prototype>
// _ask geht das in die richtige richtung?
// - stefan: vlt noch mehr, alles was ich gemacht hab geht in die richtige richtung.

To test our wrapper library, we created a minimal filesystem using it.
It implements only three callbacks --- `getattr`, `read`, `open` --- as this is enough to provide a complete, usable filesystem #cite(<libfuse_docs>, supplement: "p. example_2hello_8c.html").

This filesystem is read-only, since that narrows down the functionality we have to implement.
Files are declared in a static global array, and are even associated with a closure object, to facilitate files with dynamic content.
The dynamic aspect was chosen deliberately, because it leaves less room for the wrapper to assume properties of the filesystem, which should lead to an increased ability to detect flaws.
The following example (@hello2_file_table) shows a global file table of two entries: `time.txt`, which always reads the current system date and time, and `pid.txt`, which always reads the ID of the filesystem process.
This dynamic property of our test filesystem allows us increase confidence in our abstractions, by providing less stability on which to accidentally depend.

Additional logic was deemed necessary to be able to build a hierarchical recursive directory data structure from the provided file table, which is needed for listing directory contents. Implementing this keeps the file table itself clean and readable, and accelerates development and testing.

Besides some boilerplate to iterate over files in a director, the only logic consists of the block ```rust impl Filesystem for Hello2```, where we implement methods on @libfuse_wrapper's filesystem trait.
The implementation was straight-forward and simple, which which was one of our design goals for @libfuse_wrapper.
Most low-level details and pitfalls were abstracted away.
One aspect that required a disproportionally high amount of SLoC was dealing with partial and offset reads, but offloading that to the wrapper would mean that the user has to provide an array with the full file content already contained, only for the wrapper to calculate the correct offsets.
This could be made possible as an additional opt-in API, but would almost certainly result in major inefficiencies, as the filesystem has to procure the whole file's content every time a partial read is requested.

// FIXME @ask more? - why not

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

= Conclusion <ch_conclusion>

In this thesis, we explored the benefits of a strong type system regarding safety in operating system programming, by the examples of Rust and filesystems.
This combination is of particular relevance, given the recent Linux kernel developments in that same direction @rustforlinux-website @linuxkernel-rust-docs, and the multitude of publications regarding safe system development in Rust @10.1145_3102980.3103006 @10592287 @jung2020safe @10.1145_3360573 @287352 @bugden2022rustprogramminglanguagesafety @Oikawa2023.
Strong type systems allow modeling contracts around APIs and data structures inside the code, which makes them automatically verifiable by static analysis.
This is an improvement over documenting these as text for programmers to read and uphold, which increases cognitive load, introduces error possibilities and increases training period.
We created an abstraction layer providing high-level Rust bindings to the `libfuse` C library, uplifting the types involved into carefully constructed Rust equivalents, where invariants and guarantees are compiler-verified, with a fallback on emitting automatic runtime checks where that isn't possible.
We collected design principles for safe system programming and methodically applied them to the chosen subset of filesystem operations necessary, while having a rich toolset  for a minimal filesystem implementation.
We then evaluated a sample of @CVE:pl from the linux kernel filesystem subsystems over the past five years, assessing if --- and to what degree --- these vulnerabilities would have been prevented with the method we described.
A minimal filesystem in Rust was created, both to test the practical viability and improve the development phase of our wrapper library, and to give a qualitative assessment of safety and ergonomy aspects of the API.

We found that our approach could in fact increase the safety of filesystems currently included in the Linux kernel.
Furthermore, since most improvements were implemented as compile-time verifications, it can be assumed that their runtime impact will be nonexisting, acknowledging the need for @OS routines to be maximally performant.
We estimate that a substantial amount of security and safety issues could be prevented in the future by gradually moving kernel subsystems and modules to languages with strong type system guarantees.

// FIXME:
// - ich merk grad, ich mach ja wirklich wenig zu memory safety. in erster linie gehe ich immer auf die tollen typsystem sachen ein. soll ich memory safety ejetz hier überhaupt erwähnen, oder insgesamt vlt mehr?
// - vlt sollte ich doch nen abschnitt machen, wo ich strong/strict type systems mal sauber definiere. *oder hab ich das schon? O_o*

== Limitations

// error reporting, impl Try<> for Errno
// (code example in https://play.rust-lang.org/?version=stable&mode=debug&edition=2024&gist=eb8d6f8b78056f69ae98f40cd555804f) - @ask stefan: noch reinpacken? impl Try wird das ganze allerding aufblähen
The current mechanism of handling errors and propagating them to @libfuse is not ideal.
Specifically, while we provide the API user with an idiomatic error type --- Rust's ```rust Result``` --- @libfuse still expects a raw `errno` be returned to signal the type of failure.
A way to work around this is provided with the ```rust Try``` trait, which, when implemented on a custom type, can override the way in which error propagation on the short-circuit `?` operator is handled @rust-std-1.92.
Implementing this trait for a custom ```rust enum ErrnoResult<T> { Ok(T), Err(Errno) }``` along with a proper conversion ```rust impl<T> From<ErrnoResult<T>> for i32 {}``` would, in theory, enable an automatic conversion, such that simply using the `?` operator on fallible fuctions inside the @trampoline_function:pl would correctly propagate an `i32`-encoded errno.
Unfortunately, the ```rust Try``` trait is still unstable, which means its interface could change any Rust release and it is not usable while staying on the stable toolchain.
Therefore, and due to time constraints, the macro solution was implemented instead.

// // memory unsafety of environment (<-> direct kernel module below)
Although one of our goals was to minimize the chance of memory faults, for which Rust brings an outstanding toolkit, the choice for using the FFI and interfacing into C code proved an obstacle to that.
User code gets handed exclusively Rust-owned objects and references, where the borrow checker guarantees no memory unsafety on successful compilation.
Our wrapper library, however, has to handle a large amount of pointer parameters directly from @libfuse, where not all criteria for safe, defined memory operations can be validated.
Our current model is therefore to trust @libfuse and the pointers we are passed.
Additionally, it has proven impossible to correctly generate references with appropriate lifetimes from raw pointers.
As a practical solution, and to reduce the number of bugs that could have been introduced through our wrapper in using this method, we opted instead to create owned Rust objects from C parameters through copying.
This introduces some overhead, although in practice the effect could be diminishingly small --- memory copies are usually very fast on modern machines --- and should be measured before taken into account.

= Future work <ch_future>

// FUSE LL-api, direct socket comm., direct kernel module

The beforementioned problem with memory safety and C inter-operation could have been circumvented --- or at least greatly reduced --- by choosing a different approach for our general architecture.
Rather than implementing a wrapper for the official C library, alternatives could have been talking to the FUSE socket directly through their message protocol, or implementing our own kernel module in Rust.
This was deemed out-of-scope, since the development efford would have been substantially increased.

// *bounded integer compile-time*
A significant portion of the modeled types involved bounded integers, or integers that can only lie in a specific range of values, known at compile time.
To this date, Rust does not include builtin types that allow such range constraints, much less some that can compile-time check their constraints.
Rust has limited support for "const generics", where the generics systems allows primitive values in addition to type parameters @rust-reference-1.92.
This can be used to create support for such bounded types.
#cite(<bounded_integer_docs>, form: "prose") have created such a crate.
A provisional inspection asserted that constant constructors for the types in question are being generated, thus it is assumed that this crate would in fact bring compile-time bounded integers to our API.
This could for example have been used to limit the ```rust struct FilePermission(u16)```, to form a ```rust struct FilePermission(BoundedU16<0, 0o777>)``` or a ```rust bounded_integer! { struct FilePermission(0, 0o777); }``` which could then be instanciated with ```rust FilePermission::new_const(0o42)```.
Failure to uphold the range limits would then result in a compiler error.

// maybe ein absatz über mehr CVEs evaluieren
Since the goal of this thesis was to evaluate the effect of modern languages with strong type systems on system programming, limiting our evaluation to filesystems creates a weak evidential basis.
A future project could broaden the filter mask for CVEs, and take into consideration both other @OS:pl and other subsystems of the Linux kernel.
Selecting a greater time span would also be possible.

// *panics*
@Panic:pl in Rust are unfortunately not part of the type system, and methods cannot be reliably checked for panics without complete code analysis.
Furthermore, while @panic:pl in general would be interesting for analyzing if a program can be crash-free, they gain significance in environments using FFI, where propagated panics can --- and often will --- result in @UB.
This lessens the protective effect of our API, since new sources of @UB can be introduced by overlooking potential panic sites.
For this problem, two solutions could be considered.

1. Complete manual analysis would be feasible in our case.
  Not many external dependencies are used, the ones that are used could be replaced, and the code footprint of our critical FFI functions is relatively small (`<100 SLoC`).
  A catalogue of possible panicking functions and operators would have to be compiled from #cite(<rust-reference-1.92>, form: "prose") and #cite(<rust-std-1.92>, form: "prose"), and necessary third-party crates would either have to be reviewed, or their documentation checked and trust assumptions documented.

2. One crate that tackles this problem is `no_panic` by David Tolnay, a prominent figure amongst the Rust community @no_panic_github.
  It provides the ability to annotate function declarations with an attribute macro, and promises to halt the compilation with an error if the function is not provably @panic-free.
  This implies that it is possible to write functions that would not panic, but would still not compile if the compiler is unable to prove that property.
  The crate thereby takes a stance typical of Rust philosophy: it is preferable to reject sound programs, than to accept unsound ones.
  Adoption through a future project should be possible with justifiable expenditure.

Static analyzers and sanitizers could be employed to increase security beyond what is possible in pure Rust code, especially regarding unsafe Rust and foreign libraries.
The unstable channel of the Rust toolchain contains options for using a variety of the renown LLVM sanitizers with Rust projects #footnote[https://doc.rust-lang.org/beta/unstable-book/compiler-flags/sanitizer.html].
This is made easy by the fact that Rust uses LLVM as compiler backend.
Alternatively, a popular tool in the Rust community is Miri#footnote[https://github.com/rust-lang/miri], which can execute Rust intermediate byte inside a sandbox to detect @UB.
Unfortunately, as of now, it is largely unable to work with code that uses FFI.
Further investigation into proper tooling is required, and could provide some potential benefits in reliability testing of our and similar solutions.

There exist concepts that extend those of Rusts typesystem and can potentially provide even more statically verified correctness, namely dependent/liquid/refinement types.
One of these projects is Flux @flux-rs_github @lehmann2023flux.
With refinement types, even more constraints could be put on function arguments and return values.
For example, with Flux's state today, it would be possible not only to limit integer parameters to a range, but to make this range dynamically depend on each other, and on other runtime values, while still maintaining compile-time correctness.
This is achieved via converting the annotated constraints into logical predicates, which can then be algorithmically solved.
Therefore, the logic solver can prove that our programs behaves correctly in every circumstance, even if the concrete runtime values are not known.

#bibliography("bibliography.bib", style: "ieee")

#pagebreak()
= Glossary
// Your document body
#print-glossary(
  glossary-list,
)
