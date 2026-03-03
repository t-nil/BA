

#let glossary-list = (
  (
    key: "OS",
    long: "Operating System",
  ),
  (
    key: "trampoline_function",
    short: "trampoline function",
    description: "A wrapper function which has the job of being a proxy for another, binary-incompatible function, setting up the correct environment and converting the call. In our case, trampoline functions are ones that have the correct ABI and signature to be passed as FUSE operations, and, when executed, redirect execution flow into Rust code providing the actual filesystem functionality.",
  ),
  (
    key: "libfuse_wrapper",
    short: "our `libfuse` wrapper",
  ),
  (
    key: "libfuse",
    short: "`libfuse`",
    long: "the `libfuse` C library",
  ),
  (
    key: "UB",
    long: "Undefined Behaviour",
    description: "TODO",
  ),
  (
    key: "panic",
    description: "A mechanism in Rust to abort the current execution of a program, often in case of an irrecoverable error. Normal control flow is interrupted and one of two behaviours can be specified: directly aborting the program, or @unwinding.",
  ),
  (
    key: "unwinding",
    description: "Reacting to a panic by walking up the stack, performing cleanup like calling `drop()` on `Drop` objects. Program state and normal execution is potentially recoverable.",
  ),
  (
    key: "panic-free",
    description: "A program/function/block of code that will not, under any circumstances, invoke a panic. If a block of code is panic-free, then the execution of the resulting instructions will always follow along the control flow of the written code.",
  ),
  (
    key: "alignment",
    description: "A property of values in memory, that specifies if their memory address is divisible by a certain power of two determined by their type's alignment requirement. It is usually a soundness violation in Rus to access unaligned values.",
  ),
  (
    key: "unaligned",
    description: "See alignment.",
  ),
  (
    key: "dangling",
    description: "A property of a pointer, meaning that it points to a memory address that is not accessible, or is not filled with a valid value of that pointers type.",
  ),
  (
    key: "newtype_struct",
    short: "newtype struct",
    description: "TODO",
  ),
  (
    key: "POSIX",
    long: "the POSIX standard",
  ),
  (
    key: "procfs",
    short: "`procfs`",
    long: "the `procfs` filesystem",
    description: "TODO",
  ),
  (
    key: "afs",
    short: "`afs`",
    long: "the `afs` filesystem",
    description: "TODO",
  ),
  (
    key: "Rust",
    short: "Rust",
    description: "TODO",
  ),
  (
    key: "soundness",
    short: "soundness",
    description: "TODO define & quote",
  ),
  (
    key: "VFS",
    long: "the Virtual File System layer",
    description: "the part of the Linux kernel that abstracts between filesystems and the rest of the system",
  ),
  (
    key: "NFS",
    long: "Network File System",
  ),
  // Add more terms
)
