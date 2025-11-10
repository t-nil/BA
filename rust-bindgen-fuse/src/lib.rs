//! - nix::Error seems to wrapp errno compatibly
//! - FUSE callbacks seem to return `-errno` (https://libfuse.github.io/doxygen/structfuse__operations.html#Detailed%20Description)
//!
//! - big questions:
//!   - transparent "type checker"-only wrappers, or add one level of indirection?
//!   - how to store global data/how to give raw c callbacks access to the Filesystem impl'ing struct? `singleton-registry`?

use std::{any::type_name, ffi::CStr, fs, path::Path, sync::Arc};

use derive_more::{Deref, Into};
// TODO wrap for negative errnos
use nix::{
    Error as Errno,
    errno::Errno,
    libc::{EFAULT, ENOTRECOVERABLE},
};
use singleton_registry::define_registry;
use tracing::error;
use tracing_subscriber::reload::Handle;

mod c_bindings;

define_registry!(state);

#[derive(Into, Deref)]
pub struct Stat(c_bindings::stat);

impl Stat {
    pub fn new(stat: c_bindings::stat) -> Self {
        // assert!(is_valid(stat));
        Self(stat)
    }

    pub fn inner(&self) -> &c_bindings::stat {
        &self.0
    }
}

pub struct FuseFileInfo(c_bindings::fuse_file_info);

type GettattrFuseFn = fn(path: &Path, stat: &mut Stat, fuse_file_info: &mut FuseFileInfo) -> Errno;
/*trait GetattrCb {
    fn getattr(&self, path: &Path, stat: &mut Stat, fuse_file_info: &mut FuseFileInfo) -> Errno;
}*/

pub trait Filesystem: Send + Sync + 'static {
    fn getattr(&self, path: &Path) -> Errno;
    fn readdir(&self);
    fn open(&self);
    fn read(&self);
}

pub struct FSImplForC<FS> {
    fs: FS,
}

/*unsafe extern "C" {
impl<FS: Filesystem> FSImplForC<FS> {
    pub fn getfattr(path: &Path, stat: &mut Stat, fuse_file_info: &mut FuseFileInfo) -> i32 {
        let fs = match state::get::<FS>() {
            Ok(fs) => fs,
            Err(e) => {
                error!("registry error on `{}`: {e:#}", type_name::<FS>());
                return -EFAULT;
            }
        };

        return -(fs.getattr(path) as i32);
    }
    Option<
}
    }
*/

pub fn passthrough_getattr(fs: impl Filesystem) -> GettattrFuseFn {
    |_, _, _| { /* fs.getattr(…) */ }
}

// TODO (outlook) pass global static pointer to `Filesystem` struct, instead of
// looking this up in a registry. Pro: multiple filesystem per impl allowed.
// Cons: since rust doesn't allow pointers as const generic, we have to (unsafely)
// cast between usize and pointer.
// has libfuse compatible signature, can be passed inside `fuse_operations`
pub unsafe extern "C" fn getattr<FS: Filesystem>(
    path: *const i8, /*&Path*/
    stat: *mut c_bindings::stat,
    fuse_file_info: *mut c_bindings::fuse_file_info,
) -> i32 {
    let fs_handle = match state::get::<FS>() {
        Ok(handle) => handle,
        Err(e) => {
            eprintln!(
                "State lookup for `{}` failed. Registry corrupted? ({e:#})",
                std::any::type_name::<FS>()
            );
            return -ENOTRECOVERABLE;
            // TODO can I log? maybe requrire `log()` interface for FS trait
        }
    };
    let (stat_, fuse_file_info_): (Stat, FuseFileInfo) = todo!()/*fs_handle.getattr(path)*/;
    *stat = *stat_;
    *fuse_file_info = fuse_file_info_.0;
    todo!("unwind safety")
}

static STATE: Vec<Arc<&dyn Filesystem>> = Vec::new();

pub fn fuse_init<FS: Filesystem>(fs: FS) {
    state::register(fs);

    let fuse_struct = c_bindings::fuse_operations {
        getattr: Some(getattr::<FS>),
        readlink: todo!(),
        mknod: todo!(),
        mkdir: todo!(),
        unlink: todo!(),
        rmdir: todo!(),
        symlink: todo!(),
        rename: todo!(),
        link: todo!(),
        chmod: todo!(),
        chown: todo!(),
        truncate: todo!(),
        open: todo!(),
        read: todo!(),
        write: todo!(),
        statfs: todo!(),
        flush: todo!(),
        release: todo!(),
        fsync: todo!(),
        setxattr: todo!(),
        getxattr: todo!(),
        listxattr: todo!(),
        removexattr: todo!(),
        opendir: todo!(),
        readdir: todo!(),
        releasedir: todo!(),
        fsyncdir: todo!(),
        init: todo!(),
        destroy: todo!(),
        access: todo!(),
        create: todo!(),
        lock: todo!(),
        utimens: todo!(),
        bmap: todo!(),
        ioctl: todo!(),
        poll: todo!(),
        write_buf: todo!(),
        read_buf: todo!(),
        flock: todo!(),
        fallocate: todo!(),
        copy_file_range: todo!(),
        lseek: todo!(),
    };
}
