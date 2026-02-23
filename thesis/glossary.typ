

#let glossary-list = (
  (
    key: "trampoline_function",
    long: "trampoline function",
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
