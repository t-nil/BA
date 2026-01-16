//! ### Insights
//!
//! - `nix::Error` seems to wrapp errno compatibly
//! - FUSE callbacks seem to return `-errno` (<https://libfuse.github.io/doxygen/structfuse__operations.html#Detailed%20Description>)
//! - three categories of bug/vuln sources:
//!   - unsafe constraints
//!   - (esp.) panics across boundaries
//!   - subtle logic errors (looking at you `as` >_>)
//!   - (checking user code?)
//!
//! ### big questions
//! - transparent "type checker"-only wrappers, or add one level of indirection?
//! - how to store global data/how to give raw c callbacks access to the Filesystem impl'ing struct? `singleton-registry`?
//! - make everything (even my code) panic-safe by wrapping in catch_unwind preemtively? maybe with macros?
//!   - https://github.com/dtolnay/no-panic
//! - rethink error reporting TODO
//! - **check `as` rules**
//!
//! ### big interesting todos
//! - make c-compatible (i32) wrapper for Result<(), Errno>
//!   - either newtype struct that maintains ABI compatibility to C i32, or return i32 and overload `Try` operator
//!   - ADVANTAGE: could get rid of the big macro blocks (and the problem for nesting with these blocks adding at every layer)
//! - find out how to apply sanitizers (especially if we apply them to both libfuse and our crate, linker params etc.)
//!
//!
//! # Tags
//! - TODO
//! - FIXME
//! - MAYBE
//! - OUTLOOK
//! - INVALID
//!

// TODO (quick) replace `&Path` with `&str` since we enforce unicode anyways

#![warn(clippy::pedantic)]

use std::{
    ffi::{CStr, CString, c_char, c_void},
    fmt,
    mem::ManuallyDrop,
    ops::Range,
    path::{Path, PathBuf},
    ptr,
    sync::Arc,
};

use color_eyre::{
    Report, Result,
    eyre::{Context, bail},
};
use derive_builder::Builder;
use derive_more::{Deref, Display, Into};
use itertools::Itertools as _;
use nix::{Error as Errno, libc};
use singleton_registry::define_registry;
use thiserror::Error;
use tracing::{debug, error, info, instrument};
use typed_builder::TypedBuilder;

#[allow(clippy::all)]
#[allow(clippy::pedantic)]
mod libfuse;

type FileModeRepr = u32;

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
        eprintln!(
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

macro_rules! bitflag_accessor {
    ($inner_type:ty, $name:ident, $val:path) => {
        fn $name(&self) -> bool {
            self.0 & $val as $inner_type != 0
        }
    };
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

/// See <https://libfuse.github.io/doxygen/example_2hello_8c.html> for minimal set of values.
///
/// Refer to <https://www.man7.org/linux/man-pages/man0/sys_stat.h.0p.html> for infos about the underlying values.
///
// TODO: builder pattern
#[derive(Debug, Clone, Copy, Into, Deref)]
pub struct Stat(libfuse::stat);
impl Stat {
    #[must_use]
    pub unsafe fn new_unchecked(stat: libfuse::stat) -> Self {
        // debug_assert!(is_valid(stat));
        Self(stat)
    }
    /// `mode` - bitmask for the typical modes/permission under *nix (ugw, director etc)
    pub fn new_simple(mode: FileMode, n_link: u64, size: i64) -> Result<Self> {
        Ok(Self(libfuse::stat {
            st_nlink: n_link,
            st_size: size,
            st_mode: mode.0, // TODO (important) provide API for flags
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

    #[must_use]
    pub fn inner(&self) -> &libfuse::stat {
        &self.0
    }
}

// TODO encode bitflag values, and provide test functions (https://www.man7.org/linux/man-pages/man0/sys_stat.h.0p.html)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum FileType {
    BlockDevice = libfuse::S_IFBLK,
    CharacterDevice = libfuse::S_IFCHR,
    Fifo = libfuse::S_IFIFO,
    RegularFile = libfuse::S_IFREG,
    Directory = libfuse::S_IFDIR,
    SymbolicLink = libfuse::S_IFLNK,
    Socket = libfuse::S_IFSOCK,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FileMode(FileModeRepr);

#[derive(Debug, Builder)]
pub struct RuntimeModeBuilder {
    file_type: FileType,

    permissions: FilePermissions,

    #[builder(default = false)]
    setuid: bool,
    #[builder(default = false)]
    setgid: bool,
    #[builder(default = false)]
    vtx_flag: bool,
}

#[derive(TypedBuilder)]
#[builder(build_method(into = FileMode))]
pub struct TypedModeBuilder {
    file_type: FileType,

    //#[builder(setter(transform = |x: FilePermissions| x.0 ))]
    permissions: FilePermissions,

    // `default = false` is implied by fallbac
    #[builder(setter(strip_bool(fallback = toggle_setuid)))]
    setuid: bool,
    #[builder(setter(strip_bool(fallback = toggle_setgid)))]
    setgid: bool,
    #[builder(setter(strip_bool(fallback = toggle_vtx)))]
    vtx_flag: bool,
}

#[derive(Debug, Clone, Display, Copy, Into, Deref)]
pub struct FilePermissions(u16);

impl FilePermissions {
    pub fn new(value: u16) -> Result<Self, OutOfRangeError<u16>> {
        if value > 0o777 {
            return Err(OutOfRangeError {
                range: 0..0o777,
                value,
            });
        }
        Ok(Self(value))
    }
}

#[derive(Debug, Error)]
#[error("Argument out of range: '{value}'. Must be between '{}' and '{}'", range.start, range.end)]
pub struct OutOfRangeError<T: fmt::Display> {
    range: Range<T>,
    value: T,
}

impl From<TypedModeBuilder> for FileMode {
    fn from(
        TypedModeBuilder {
            file_type,
            permissions,
            setuid,
            setgid,
            vtx_flag,
        }: TypedModeBuilder,
    ) -> Self {
        Self(
            file_type as u32
                + permissions.0 as u32
                + if setuid { libfuse::S_ISUID } else { 0 }
                + if setgid { libfuse::S_ISGID } else { 0 }
                + if vtx_flag { libfuse::S_ISVTX } else { 0 },
        )
    }
}

impl From<RuntimeModeBuilder> for FileMode {
    fn from(
        RuntimeModeBuilder {
            file_type,
            permissions,
            setuid,
            setgid,
            vtx_flag,
        }: RuntimeModeBuilder,
    ) -> Self {
        Self(
            file_type as u32
                + permissions.0 as u32
                + if setuid { libfuse::S_ISUID } else { 0 }
                + if setgid { libfuse::S_ISGID } else { 0 }
                + if vtx_flag { libfuse::S_ISVTX } else { 0 },
        )
    }
}

pub struct FuseFileInfo(libfuse::fuse_file_info);

pub struct OpenFlags(i32);

impl OpenFlags {
    bitflag_accessor!(i32, append, OpenFlag::Append);
    bitflag_accessor!(i32, readonly, OpenFlag::Readonly);
    bitflag_accessor!(i32, writeonly, OpenFlag::Writeonly);
    bitflag_accessor!(i32, read_plus_write, OpenFlag::ReadPlusWrite);
    bitflag_accessor!(i32, truncate, OpenFlag::Truncate);
}

/// This is repr(i32) because the target bitset (fuse_file_info::flags) and the `libc` constants are also i32.
#[repr(i32)]
enum OpenFlag {
    Append = libc::O_APPEND,
    Readonly = libc::O_RDONLY,
    Writeonly = libc::O_WRONLY,
    ReadPlusWrite = libc::O_RDWR,
    Truncate = libc::O_TRUNC,
    // TODO (maybe) exhaust
}

// type GetattrHook = fn(
//     path: *const i8,
//     stat_out: *mut libfuse::stat,
//     fuse_file_info_out: *mut libfuse::fuse_file_info,
// ) -> i32;
// type OpenHook = fn(path: *const c_char, fuse_file_info_out: *mut libfuse::fuse_file_info) -> i32;
// type ReadHook = fn(
//     path: *const c_char,
//     buf_out: *mut c_char,
//     n: size_t,
//     offset: libfuse::off_t,
//     fuse_file_info_out: *mut libfuse::fuse_file_info,
// ) -> i32;

// ///
// ///
// type ReaddirHook = fn(
//     path: *const c_char,
//     data_ptr: *mut c_void,
//     filler_fn: libfuse::fuse_fill_dir_t,
//     offset: libfuse::off_t,
//     fuse_file_info_out: *mut libfuse::fuse_file_info,
//     readdir_flags: libfuse::fuse_readdir_flags,
// ) -> i32;

pub struct GetfattrRetVal {
    pub stat: Stat,
}

// TODO (maybe) use Cow and <T: AsRef<str>> params to let user choose wether to pass owned Strings or references.
pub struct ReaddirRetVal {
    pub entries: Vec<String>,
    // seems to only be set from `open`, `opendir`, `create` - https://libfuse.github.io/doxygen/structfuse__file__info.html#afcff4109f1c8fb7ff51f18500496271d
    //pub fuse_file_info: Option<FuseFileInfo>,
}

pub struct OpenRetVal {
    pub fuse_file_info: Option<FuseFileInfo>,
}

pub struct ReadRetVal {
    pub content: Vec<u8>,
}

pub trait Filesystem: Send + Sync + 'static {
    fn getattr(&self, path: &Path) -> Result<GetfattrRetVal, Errno>;
    fn readdir(&self, path: &Path) -> Result<ReaddirRetVal, Errno>;
    fn open(&self, path: &Path, flags: OpenFlags) -> Result<OpenRetVal, Errno>;
    fn read(&self, path: &Path, size: u32, offset: isize) -> Result<ReadRetVal, Errno>;
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
    _fuse_file_info_out: *mut libfuse::fuse_file_info,
) -> i32 {
    // Safety
    ensure_errno!(!path.is_null(), Errno::EINVAL);
    ensure_errno!(!stat_out.is_null(), Errno::EINVAL);
    //   ensure_errno!(!_fuse_file_info_out.is_null(), Errno::EINVAL);
    ensure_errno!(path.is_aligned(), Errno::EINVAL);
    ensure_errno!(stat_out.is_aligned(), Errno::EINVAL);
    //    ensure_errno!(_fuse_file_info_out.is_aligned(), Errno::EINVAL);

    let fs = try_errno!(fetch_fs_from_registry::<FS>());

    // THESIS https://doc.rust-lang.org/edition-guide/rust-2024/unsafe-op-in-unsafe-fn.html
    // safe wrapping of params
    // SAFETY: we check invariants at the function start
    let path = try_errno!(unsafe { path_from_c_ptr(path) });

    debug!("enter: getfattr('{}')", path.to_string_lossy());
    let result = try_errno!(call_into_user_code::<FS, _>("getfattr", || fs.getattr(&path)));
    let GetfattrRetVal { stat } = result;
    debug!("return: getfattr => {}", path.to_string_lossy());

    // SAFETY: we assume that the two outptrs received by libfuse are not dangling. We can check for alignment and
    // non-null-ity, but invalid memory addresses will not be catched.
    unsafe {
        *stat_out = *stat;
    }

    return 0;
}

/// * `buf` - (buffer to pass to filler fn?? TODO)
/// * `filler_fn` - function to call once per directory entry? TODO
/// * `offset` - should be ignorable since we only support complete dir listing in one go? TODO
#[tracing::instrument]
pub unsafe extern "C" fn readdir<FS: Filesystem>(
    path: *const c_char,
    data_ptr: *mut c_void,
    filler_fn: libfuse::fuse_fill_dir_t,
    _offset: libfuse::off_t,
    fuse_file_info_out: *mut libfuse::fuse_file_info,
    _readdir_flags: libfuse::fuse_readdir_flags,
) -> i32 {
    let Some(filler_fn) = filler_fn else {
        bail_errno!("`filler_fn` must not be null", Errno::EINVAL);
    };

    ensure_errno!(!path.is_null(), Errno::EINVAL);
    ensure_errno!(!fuse_file_info_out.is_null(), Errno::EINVAL);
    ensure_errno!(path.is_aligned(), Errno::EINVAL);
    ensure_errno!(fuse_file_info_out.is_aligned(), Errno::EINVAL);

    // since we don't use `data_ptr` besides passing it to `filler_fn`, we can ignore invariants.
    //ensure_errno!(data_ptr.is_aligned(), Errno::EINVAL);
    //ensure_errno!(!data_ptr.is_null(), Errno::EINVAL);

    let fs = try_errno!(fetch_fs_from_registry::<FS>());

    // SAFETY: we check invariants at the function start
    let path = try_errno!(unsafe { path_from_c_ptr(path) });

    debug!("enter: readdir('{}')", path.to_string_lossy());
    let result = try_errno!(call_into_user_code::<FS, _>("readdir", || fs.readdir(&path)));
    let ReaddirRetVal { entries } = result;
    debug!("return: readdir => {entries:?}");

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
                // …_PLUS => let kernel fill inode cache by announcing that the stat param is fully set
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

    return 0;
}

/// FUSE docs:
///
/// ```quote
///
/// Open a file
///
/// Open flags are available in fi->flags. The following rules apply.
///
/// - Creation (O_CREAT, O_EXCL, O_NOCTTY) flags will be filtered out / handled by the kernel.
/// - Access modes (O_RDONLY, O_WRONLY, O_RDWR, O_EXEC, O_SEARCH) should be used by the filesystem to check if the operation is permitted. If the -o default_permissions mount option is given, this check is already done by the kernel before calling open() and may thus be omitted by the filesystem.
/// - When writeback caching is enabled, the kernel may send read requests even for files opened with O_WRONLY. The filesystem should be prepared to handle this.
/// - When writeback caching is disabled, the filesystem is expected to properly handle the O_APPEND flag and ensure that each write is appending to the end of the file.
/// - When writeback caching is enabled, the kernel will handle O_APPEND. However, unless all changes to the file come through the kernel this will not work reliably. The filesystem should thus either ignore the O_APPEND flag (and let the kernel handle it), or return an error (indicating that reliably O_APPEND is not available).
///
/// Filesystem may store an arbitrary file handle (pointer, index, etc) in fi->fh, and use this in other all other file operations (read, write, flush, release, fsync).
///
/// Filesystem may also implement stateless file I/O and not store anything in fi->fh.
///
/// There are also some flags (direct_io, keep_cache) which the filesystem may set in fi, to change the way the file is opened. See fuse_file_info structure in <fuse_common.h> for more details.
///
/// If this request is answered with an error code of ENOSYS and FUSE_CAP_NO_OPEN_SUPPORT is set in fuse_conn_info.capable, this is treated as success and future calls to open will also succeed without being sent to the filesystem process.
///
/// Definition at line 486 of file fuse.h.
///
/// ```
#[instrument]
pub unsafe extern "C" fn open<FS: Filesystem>(
    path: *const i8,
    fuse_file_info: *mut libfuse::fuse_file_info,
) -> i32 {
    ensure_errno!(!path.is_null(), Errno::EINVAL);
    ensure_errno!(!fuse_file_info.is_null(), Errno::EINVAL);
    ensure_errno!(path.is_aligned(), Errno::EINVAL);
    ensure_errno!(fuse_file_info.is_aligned(), Errno::EINVAL);

    let flags = unsafe { OpenFlags((*fuse_file_info).flags) };

    // we only support readonly access
    ensure_errno!(!flags.readonly(), Errno::EACCES);

    let path = try_errno!(unsafe { path_from_c_ptr(path) });

    // currently this is a NOOP
    debug!("enter: open('{}') // NOOP", path.to_string_lossy());
    return 0;
}

pub unsafe extern "C" fn read<FS: Filesystem>(
    path: *const i8,
    buf: *mut i8,
    size: usize,
    offset: libc::off_t,
    fuse_file_info: *mut libfuse::fuse_file_info,
) -> i32 {
    ensure_errno!(!path.is_null(), Errno::EINVAL);
    ensure_errno!(!buf.is_null(), Errno::EINVAL);
    ensure_errno!(!fuse_file_info.is_null(), Errno::EINVAL);
    ensure_errno!(path.is_aligned(), Errno::EINVAL);
    ensure_errno!(buf.is_aligned(), Errno::EINVAL);
    ensure_errno!(fuse_file_info.is_aligned(), Errno::EINVAL);

    let size: u32 = if size == 0 {
        // nothing to do, no space left in buffer
        return 0;
    } else {
        ensure_errno!(size <= i32::MAX as usize, Errno::EDOM);
        size as u32
    };

    let fs = try_errno!(fetch_fs_from_registry::<FS>());

    // SAFETY: we check invariants at the function start
    let path = try_errno!(unsafe { path_from_c_ptr(path) });

    debug!(
        "enter: read('{}', buf=0x{buf:x}, size={size}, offset=0x{offset:x})",
        path.to_string_lossy(),
        buf = buf.addr()
    );
    let result = try_errno!(call_into_user_code::<FS, _>("read", || fs.read(
        &path,
        size,
        offset as isize
    )));
    let n_bytes = result.content.len();
    // if `n_bytes` is smaller than `size`, it _will_ fit inside i32. see checks at the top.
    ensure_errno!(n_bytes <= size as usize, Errno::ENOSYS); // FIXME don't error if user code returns too much data. just truncate it.
    let n_bytes = n_bytes as i32;
    {
        let content_as_string = String::from_utf8_lossy(
            &result
                .content
                .get(0..50.min(result.content.len()))
                .unwrap_or("<not found>".as_bytes()),
        );
        let char_count = content_as_string.chars().count();
        debug!(
            "return: read => ({n_bytes}):'{}'",
            content_as_string + if char_count > 50 { "…" } else { "" }
        );
    }

    // Safety: we checked that the buffer is big enough to hold the returned data (if `size` argument was correct).
    //         Also we checked that the pointer is aligned and non-null.
    unsafe {
        ptr::copy_nonoverlapping(
            result.content.as_ptr(),
            buf as *mut u8,
            result.content.len(),
        );
    }

    return n_bytes;
}

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

// ALTERNATIVE: manually spawn fuse workers. Store handle like this:
// pub struct FuseHandle(i32);

/// usage: /home/ra1n/.cache/cargo_target/debug/examples/hello [options] <mountpoint>
///
/// FUSE options:
///     -h   --help            print help
///     -V   --version         print version
///     -d   -o debug          enable debug output (implies -f)
///     -f                     foreground operation
///     -s                     disable multi-threaded operation
///     -o clone_fd            use separate fuse device fd for each thread
///                            (may improve performance)
///     -o max_idle_threads    the maximum number of idle worker threads
///                            allowed (default: -1)
///     -o max_threads         the maximum number of worker threads
///                            allowed (default: 10)
///     -o kernel_cache        cache files in kernel
///     -o [no]auto_cache      enable caching based on modification times (off)
///     -o no_rofd_flush       disable flushing of read-only fd on close (off)
///     -o umask=M             set file permissions (octal)
///     -o fmask=M             set file permissions (octal)
///     -o dmask=M             set dir  permissions (octal)
///     -o uid=N               set file owner
///     -o gid=N               set file group
///     -o entry_timeout=T     cache timeout for names (1.0s)
///     -o negative_timeout=T  cache timeout for deleted names (0.0s)
///     -o attr_timeout=T      cache timeout for attributes (1.0s)
///     -o ac_attr_timeout=T   auto cache timeout for attributes (attr_timeout)
///     -o noforget            never forget cached inodes
///     -o remember=T          remember cached inodes for T seconds (0s)
///     -o modules=M1[:M2...]  names of modules to push onto filesystem stack
///     -o allow_other         allow access by all users
///     -o allow_root          allow access by root
///     -o auto_unmount        auto unmount on process termination
///
/// Options for subdir module:
///     -o subdir=DIR           prepend this directory to all paths (mandatory)
///     -o [no]rellinks         transform absolute symlinks to relative
///
/// Options for iconv module:
///     -o from_code=CHARSET   original encoding of file names (default: UTF-8)
///     -o to_code=CHARSET     new encoding of the file names (default: UTF-8)
///
pub fn fuse_main<FS: Filesystem>(
    fs: FS,
    mount_point: impl AsRef<Path>,
    args: impl Iterator<Item = impl AsRef<str>>,
) -> Result<()> {
    let Some(mount_point) = mount_point.as_ref().to_str() else {
        bail!(
            "mount point '{}' is not valid UTF-8",
            mount_point.as_ref().to_string_lossy()
        )
    };

    // we always run single-threaded, and in the foreground.
    let mut args = args.map(|s| s.as_ref().to_owned()).collect_vec();
    args.push("-f".into());
    args.push("-s".into());
    args.append(&mut vec!["-o".into(), "auto_unmount".into()]);

    let mut args = obtain_argv_as_mut_array(args.iter())
        .wrap_err("converting `env::args()` to a mutable C string array `(*mut *mut c_char)`")?;
    //let arg_ptrs = args.iter().map(|c_str| c_str.as_mut()).collect_vec();

    //let (argc, argv): (c_int, *mut *mut c_char) = { (args.len() as c_int, nix::libc::mall) };

    let mount_point_c_str = CString::new(mount_point)
        .wrap_err_with(|| format!("mount point '{mount_point}' is not a valid CString"))?;

    state::register(fs);

    let fuse_ops = libfuse::fuse_operations {
        // elementary
        getattr: Some(getattr::<FS>),
        open: Some(open::<FS>),
        read: Some(read::<FS>),
        readdir: Some(readdir::<FS>),

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

    unsafe {
        // fuse_main_fn(argc: ::std::os::raw::c_int, argv: *mut *mut ::std::os::raw::c_char,
        //              op: *const fuse_operations, user_data: *mut ::std::os::raw::c_void) -> ::std::os::raw::c_int
        let errno = libfuse::fuse_main_fn(
            args.len()
                .try_into()
                .unwrap_or_else(|_| panic!("more than {} args are not supported", i32::MAX)),
            args.as_mut_ptr(),
            &fuse_ops as *const libfuse::fuse_operations,
            ptr::null_mut(),
        );
        if errno != 0 {
            bail!("`libfuse::fuse_main_fn()` returned non-zero status ({errno})");
        }
    }

    // let _fuse_args = libfuse::fuse_args {
    //     argc: todo!(),
    //     argv: todo!(),
    //     allocated: todo!(),
    // };

    // let _fuse_fs = unsafe {
    //     libfuse::fuse_fs_new(&fuse_ops, std::mem::size_of_val(&fuse_ops), ptr::null_mut())
    // };
    //let fuse = unsafe { libfuse::_fuse_new_31(args, op, op_size, version, user_data) };

    // SAFETY: use mut_ptr() to not trust the c code to not mutate?
    //let fuse_handle = unsafe { libfuse::fuse_mount(fuse_fs, mount_point_c_str.as_ptr()) };

    Ok(())
}

fn obtain_argv_as_mut_array(
    args: impl Iterator<Item = impl AsRef<str>>,
) -> Result<ManuallyDrop<Box<[*mut c_char]>>> {
    let c_string_vec = args
        .map(|s| {
            let s = s.as_ref();
            CString::new(s)
                .map_err(Report::new)
                .wrap_err_with(|| format!("Parsing arg '{s}'"))
        })
        .collect::<Result<Vec<_>>>()
        .wrap_err("converting args to CStrings")?;

    // we leak this memory, usually this should only be called once and leaking S(args) should not be considered relevant.
    // On the other hand, this way C code can do almost anything to this data and we won't UB.
    let ptr_vec = c_string_vec
        .into_iter()
        .map(|cstr| cstr.into_raw())
        .collect_vec();

    Ok(ManuallyDrop::new(ptr_vec.into_boxed_slice()))
}

#[cfg(test)]
mod tests {
    #![allow(non_snake_case)]
    use super::*;

    #[test]
    fn FileMode() {
        assert_eq!(
            TypedModeBuilder::builder()
                .file_type(FileType::RegularFile)
                .permissions(FilePermissions::new(0o775).unwrap())
                .setuid()
                .build()
                .0,
            libfuse::S_IFREG
                + libfuse::S_IRWXU
                + libfuse::S_IRWXG
                + libfuse::S_IROTH
                + libfuse::S_IXOTH
        )
    }
}
