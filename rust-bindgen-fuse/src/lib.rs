//! - nix::Error seems to wrapp errno compatibly
//! - FUSE callbacks seem to return `-errno` (https://libfuse.github.io/doxygen/structfuse__operations.html#Detailed%20Description)
//!
//! - big questions:
//!   - transparent "type checker"-only wrappers, or add one level of indirection?
//!   - how to store global data/how to give raw c callbacks access to the Filesystem impl'ing struct? `singleton-registry`?

use std::path::Path;

// TODO wrap for negative errnos
use nix::Error as Errno;

mod c_bindings;

pub struct Stat(c_bindings::stat);
pub struct FuseFileInfo(c_bindings::fuse_file_info);

trait GetattrCb {
    fn getattr(&self, path: &Path, stat: &mut Stat, fuse_file_info: &mut FuseFileInfo) -> Errno;
}

pub trait Filesystem {
    fn getattr(path: &Path);
    fn readdir();
    fn open();
    fn read();
}

pub struct FSImpl<FS: Filesystem> {
    fs: FS,
}

impl<FS: Filesystem> FSImpl<FS> {
    #[repr(C)]
    pub fn getfattr() -> Errno {}
}

pub fn fuse_init<FS: Filesystem>(fs: FS) {}
