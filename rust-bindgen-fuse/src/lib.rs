//! - nix::Error seems to wrapp errno compatibly
//! - FUSE callbacks seem to return `-errno` (https://libfuse.github.io/doxygen/structfuse__operations.html#Detailed%20Description)
//!
//! - big questions:
//!   - transparent "type checker"-only wrappers, or add one level of indirection?
//!   - how to store global data/how to give raw c callbacks access to the Filesystem impl'ing struct? `singleton-registry`?
//!
//! - big interesting todos:
//!   - make c-compatible (i32) wrapper for Result<(), Errno>
//!     - either newtype struct that maintains ABI compatibility to C i32, or return i32 and overload `Try` operator
//!     - ADVANTAGE: could get rid of the big macro blocks (and the problem for nesting with these blocks adding at every layer)
//!   - find out how to apply sanitizers (especially if we apply them to both libfuse and our crate, linker params etc.)
//!
//!
//! # Tags
//! - TODO
//! - FIXME
//! - MAYBE
//! - OUTLOOK
//! - INVALID

use std::{
    ffi::{CStr, CString, c_char, c_void},
    path::{Path, PathBuf},
    ptr,
    sync::Arc,
};

use color_eyre::{
    Result,
    eyre::{Context, bail},
};
use derive_more::{Deref, Into};
use nix::{Error as Errno, libc::size_t};
use singleton_registry::define_registry;
use tracing::error;

mod libfuse;

macro_rules! ensure_errno {
    ($test:expr, $errno:expr) => {{
        let test = $test;
        if !(test) {
            bail_errno!(concat!("Assertion failed: ", stringify!($test)), $errno);
        }
    }};
}

macro_rules! bail_errno {
    ($error_str:expr, $errno:expr) => {{
        let error_str = $error_str;
        let errno = $errno;
        error!(
            // debug fmt errno for Err(Errno) case (wouldn't implement Display)
            "{}:{}: {}. (Returning {:?} - {})",
            file!(),
            line!(),
            error_str,
            errno.desc(),
            stringify!($errno)
        );
        return -(errno as i32);
    }};
}

macro_rules! try_errno {
    ($result:expr) => {{
        let result: Result<_, (String, Errno)> = $result;
        match result {
            Ok(x) => x,
            Err((e, errno)) => bail_errno!(e, errno),
        }
    }};
}

define_registry!(state);

// #[derive(Debug, Clone, Copy, PartialEq, Eq)]
// pub struct FuseErrno(pub Errno);

// impl Into<i32> for FuseErrno {
//     fn into(self) -> i32 {
//         -(self.0 as i32)
//     }
// }

// pub type ErrnoResult<T> = Result<T, Errno>;

// impl ErrnoResult {
//     pub fn into_fuse_errno(self) -> i32 {
//         match self {
//             Self::Success => 0,
//             Self::Failure(errno) => -(errno as i32),
//         }
//     }
// }

// impl From<ErrnoResult> for i32 {
//     fn from(value: ErrnoResult) -> Self {
//         value.into_fuse_errno()
//     }
// }

// TODO: builder pattern
#[derive(Into, Deref)]
pub struct Stat(libfuse::stat);

/// See https://libfuse.github.io/doxygen/example_2hello_8c.html for minimal set of values.
///
/// Refer to https://www.man7.org/linux/man-pages/man0/sys_stat.h.0p.html for infos about the underlying values.
impl Stat {}

impl Stat {
    pub unsafe fn new_unsafe(stat: libfuse::stat) -> Self {
        // assert!(is_valid(stat));
        Self(stat)
    }
    /// `mode` - bitmask for the typical modes/permission under *nix (ugw, director etc)
    pub fn new_file(mode: StatMode, mode_rest: u32, n_link: u64, size: i64) -> Result<Self> {
        Ok(Self(libfuse::stat {
            st_nlink: n_link,
            st_size: size,
            st_mode: match mode {
                StatMode::BlockDevice => libfuse::S_IFBLK,
                StatMode::CharacterDevice => libfuse::S_IFCHR,
                StatMode::Fifo => libfuse::S_IFIFO,
                StatMode::RegularFile => libfuse::S_IFREG,
                StatMode::Directory => libfuse::S_IFDIR,
                StatMode::SymbolicLink => libfuse::S_IFLNK,
                StatMode::Socket => libfuse::S_IFSOCK,
            } + mode_rest, // TODO (important) provide API for flags
            st_dev: 0,
            st_ino: 0,
            st_uid: 0,
            st_gid: 0,
            __pad0: Default::default(),

            st_rdev: 0,
            st_blksize: 0,
            st_blocks: 0,
            st_atim: libfuse::timespec {
                tv_sec: 0,
                tv_nsec: 0,
            },
            st_mtim: libfuse::timespec {
                tv_sec: 0,
                tv_nsec: 0,
            },
            st_ctim: libfuse::timespec {
                tv_sec: 0,
                tv_nsec: 0,
            },
            __glibc_reserved: Default::default(),
        }))
    }

    pub fn inner(&self) -> &libfuse::stat {
        &self.0
    }
}

// TODO encode bitflag values, and provide test functions (https://www.man7.org/linux/man-pages/man0/sys_stat.h.0p.html)
enum StatMode {
    BlockDevice,
    CharacterDevice,
    Fifo,
    RegularFile,
    Directory,
    SymbolicLink,
    Socket,
}

pub struct FuseFileInfo(libfuse::fuse_file_info);

type GetattrHook = fn(
    path: *const i8,
    stat_out: *mut libfuse::stat,
    fuse_file_info_out: *mut libfuse::fuse_file_info,
) -> i32;
type OpenHook = fn(path: *const c_char, fuse_file_info_out: *mut libfuse::fuse_file_info) -> i32;
type ReadHook = fn(
    path: *const c_char,
    buf_out: *mut c_char,
    n: size_t,
    offset: libfuse::off_t,
    fuse_file_info_out: *mut libfuse::fuse_file_info,
) -> i32;

///
///
/// * `buf` - (buffer to pass to filler fn?? TODO)
/// * `filler_fn` - function to call once per directory entry? TODO
/// * `offset` - should be ignorable since we only support complete dir listing in one go? TODO
type ReaddirHook = fn(
    path: *const c_char,
    data_ptr: *mut c_void,
    filler_fn: libfuse::fuse_fill_dir_t,
    offset: libfuse::off_t,
    fuse_file_info_out: *mut libfuse::fuse_file_info,
    readdir_flags: libfuse::fuse_readdir_flags,
) -> i32;

pub struct GetfattrRetVal {
    pub stat: Stat,
    pub fuse_file_info: FuseFileInfo,
}

pub struct ReaddirRetVal {
    pub entries: Vec<String>,
    pub fuse_file_info: FuseFileInfo,
}

pub trait Filesystem: Send + Sync + 'static {
    fn getattr(&self, path: &Path) -> Result<GetfattrRetVal, Errno>;
    fn readdir(&self) -> Result<ReaddirRetVal, Errno>;
    fn open(&self);
    fn read(&self);
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

// INVALID cannot coerce closure to c-style call? even if we could, there would be no state captured,
// so we're back to square one (just using static trampoline functions)
// #[allow(non_snake_case)]
// pub fn passthrough_getattr(fs: impl Filesystem) -> GettattrFuseFn {
//     |_, _, _| { /* fs.getattr(…) */ }
// }

// OUTLOOK pass global static pointer to `Filesystem` struct, instead of
// looking this up in a registry. Pro: multiple filesystem per impl allowed.
// Cons: since rust doesn't allow pointers as const generic, we have to (unsafely)
// cast between usize and pointer.
// has libfuse compatible signature, can be passed inside `fuse_operations`

///
pub unsafe extern "C" fn getattr<FS: Filesystem>(
    path: *const i8,
    stat_out: *mut libfuse::stat,
    fuse_file_info_out: *mut libfuse::fuse_file_info,
) -> i32 {
    // Safety
    ensure_errno!(!path.is_null(), Errno::EINVAL);
    ensure_errno!(!stat_out.is_null(), Errno::EINVAL);
    ensure_errno!(!fuse_file_info_out.is_null(), Errno::EINVAL);
    ensure_errno!(path.is_aligned(), Errno::EINVAL);
    ensure_errno!(stat_out.is_aligned(), Errno::EINVAL);
    ensure_errno!(fuse_file_info_out.is_aligned(), Errno::EINVAL);

    let fs = try_errno!(fetch_fs_from_registry::<FS>());

    // THESIS https://doc.rust-lang.org/edition-guide/rust-2024/unsafe-op-in-unsafe-fn.html
    // safe wrapping of params
    // SAFETY: we check invariants at the function start
    let path = try_errno!(unsafe { path_from_c_ptr(path) });

    let result = try_errno!(call_into_user_code::<FS, _>("getfattr", || fs.getattr(&path)));
    let GetfattrRetVal {
        stat,
        fuse_file_info,
    } = result;

    // SAFETY: we assume that the two outptrs received by libfuse are not dangling. We can check for alignment and
    // non-null-ity, but invalid memory addresses will not be catched.
    unsafe {
        *stat_out = *stat;
        *fuse_file_info_out = fuse_file_info.0;
        todo!("safety")
    }

    return 0;
}

//pub unsafe extern "C" fn readdir<FS: Filesystem>() {}
static readdir: ReaddirHook = |path, buf, filler_fn, _offset, fuse_file_info_out, readdir_flags| {
    let Some(filler_fn) = filler_fn else {
        bail_errno!("`filler_fn` must not be null", Errno::EINVAL);
    };

    ensure_errno!(!path.is_null(), Errno::EINVAL);
    ensure_errno!(!buf.is_null(), Errno::EINVAL);
    ensure_errno!(!fuse_file_info_out.is_null(), Errno::EINVAL);
    ensure_errno!(path.is_aligned(), Errno::EINVAL);
    ensure_errno!(buf.is_aligned(), Errno::EINVAL);
    ensure_errno!(fuse_file_info_out.is_aligned(), Errno::EINVAL);

    let fs = try_errno!(fetch_fs_from_registry::<FS>());

    // SAFETY: we check invariants at the function start
    let path = try_errno!(unsafe { path_from_c_ptr(path) });

    let result = try_errno!(call_into_user_code::<FS, _>("getfattr", || fs.getattr(&path)));
    let ReaddirRetVal {
        entries,
        fuse_file_info,
    } = result;

    for entry in entries {
        unsafe {
            todo!("filler_fn()");
        }
    }

    todo!()
};

fn fetch_fs_from_registry<FS: Filesystem>() -> Result<Arc<FS>, (String, Errno)> {
    state::get::<FS>().map_err(|e| {
        (
            format!(
                "State lookup for `{}` failed. Registry corrupted? ({e:#})",
                std::any::type_name::<FS>()
            ),
            Errno::ENOTRECOVERABLE,
        )
    })
}

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

/// # Safety
///
/// - `c_str` - is a valid pointer (non-dangling, aligned), is nul-terminated
///
/// Since we copy the string instead of referencing it, aliasing and mutation of the original c string
/// are not as important.
unsafe fn path_from_c_ptr(c_str: *const c_char) -> Result<PathBuf, (String, Errno)> {
    let path = unsafe { CStr::from_ptr(c_str) };
    let path_utf8: &str = match path.to_str() {
        Ok(path) => path,
        Err(utf8_error) => {
            return Err((
                format!("path is not valid UTF-8: {utf8_error:#}"),
                Errno::EINVAL,
            ));
        }
    };

    // TODO (maybe) copy path because what lifetime should this &Path have? we can't depend it on a ptr.
    let path_utf8 = PathBuf::from(path_utf8);
    Ok(path_utf8)
}

/*fn call_with_catch_unwind<FS: Filesystem, T>(
    fun: impl FnOnce() -> T,
    method: &'static str,
) -> Result<T, Errno> {
    use core::panic::AssertUnwindSafe;
    use std::panic::catch_unwind;

    result.map_err(|e| {
        error!(
            "PANIC on `{fs}::{method}`:\n\n{e:?}\n\nreturning ENOSYS\n",
            fs = std::any::type_name::<FS>()
        );
        Errno::ENOTRECOVERABLE
    })
}*/

// ALTERNATIVE: store filesystem handles inside a vector, and use some fuse field to smuggle a vector offset
//
//static STATE: Vec<Arc<&dyn Filesystem>> = Vec::new();

pub struct FuseHandle(i32);

pub fn fuse_init<FS: Filesystem>(fs: FS, mount_point: impl AsRef<Path>) -> Result<FuseHandle> {
    let Some(mount_point) = mount_point.as_ref().to_str() else {
        bail!(
            "mount point '{}' is not valid UTF-8",
            mount_point.as_ref().to_string_lossy()
        )
    };

    let mount_point_c_str = CString::new(mount_point)
        .wrap_err_with(|| format!("mount point '{mount_point}' is not a valid CString"))?;

    state::register(fs);

    let fuse_ops = libfuse::fuse_operations {
        // elementary
        getattr: Some(getattr::<FS>),
        open: todo!(),
        read: todo!(),
        readdir: todo!(),

        // rest
        readlink: None,
        mknod: None,
        mkdir: None,
        unlink: None,
        rmdir: None,
        symlink: None,
        rename: None,
        link: None,
        chmod: None,
        chown: None,
        truncate: None,
        write: None,
        statfs: None,
        flush: None,
        release: None,
        fsync: None,
        setxattr: None,
        getxattr: None,
        listxattr: None,
        removexattr: None,
        opendir: None,
        releasedir: None,
        fsyncdir: None,
        init: None,
        destroy: None,
        access: None,
        create: None,
        lock: None,
        utimens: None,
        bmap: None,
        ioctl: None,
        poll: None,
        write_buf: None,
        read_buf: None,
        flock: None,
        fallocate: None,
        copy_file_range: None,
        lseek: None,
    };

    let fuse = unsafe {
        libfuse::fuse_fs_new(&fuse_ops, std::mem::size_of_val(&fuse_ops), ptr::null_mut())
    };

    // SAFETY: use mut_ptr() to not trust the c code to not mutate?
    let fuse_handle = unsafe { libfuse::fuse_mount(todo!(), mount_point_c_str.as_ptr()) };

    Ok(FuseHandle(fuse_handle))
}
