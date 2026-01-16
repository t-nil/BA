use std::{
    borrow::Cow,
    collections::HashSet,
    env::args,
    iter::{self, Peekable},
    path::{Components, Path, PathBuf},
    sync::LazyLock,
};

use color_eyre::{
    Result,
    eyre::{bail, ensure},
};
use itertools::Itertools as _;
use nix::errno::Errno;
use rust_bindgen_fuse::{
    FilePermissions, FileType, Filesystem, GetfattrRetVal, OpenFlags, OpenRetVal, ReadRetVal,
    ReaddirRetVal, Stat, TypedModeBuilder,
};
use tracing::{Level, debug, error, instrument, trace};
use tracing_subscriber::EnvFilter;

type FileEntry = (
    &'static str,
    Box<dyn Send + Sync + 'static + Fn() -> String>,
);

static FILES: LazyLock<[FileEntry; 6]> = LazyLock::new(|| {
    [
        ("/hello.txt", Box::new(|| "Hello world!".into())),
        ("/pid", Box::new(|| std::process::id().to_string())),
        (
            "/time",
            Box::new(|| format!("{}", chrono::Local::now().format("%c"))),
        ),
        ("/foo/bar/baz", Box::new(|| "blub".into())),
        ("/foo/bar/qux", Box::new(|| "blub".into())),
        ("/foo/fux", Box::new(|| "blub".into())),
    ]
});

#[derive(Debug, Clone)]
struct Dir {
    name: String,
    files: HashSet<String>,
    subdirs: Vec<Dir>,
}

impl Dir {
    fn new(name: &str) -> Dir {
        Dir {
            name: name.to_owned(),
            files: HashSet::new(),
            subdirs: vec![],
        }
    }
}

static ROOT: LazyLock<Dir> = LazyLock::new(|| {
    use std::path::Component;
    fn populate<'a>(mut components: Peekable<impl Iterator<Item = Component<'a>>>, dir: &mut Dir) {
        let Some(component) = components.next() else {
            trace!("finished(?)");
            return;
        };

        match component {
            Component::Prefix(_) => populate(components, dir), // does not occur on unix
            Component::RootDir => populate(components, dir),   // we do nothing with the root
            Component::CurDir => populate(components, dir),    // we also ignore any `./`s
            Component::ParentDir => (), // FIXME we handle this at the bottom, with Components iter creation.
            Component::Normal(current_entry) => {
                let current_entry = current_entry.to_str().expect("we only operate on unicode");
                if let Some(_) = components.peek() {
                    if !dir.subdirs.iter().any(|d| d.name == current_entry) {
                        trace!("inserting new dir '{current_entry}'");
                        dir.subdirs.push(Dir::new(current_entry));
                    }
                    let mut subdir = dir
                        .subdirs
                        .iter_mut()
                        .find(|d| d.name == current_entry)
                        .expect("we just checked and inserted");

                    trace!("populating '{current_entry}'");
                    populate(components, &mut subdir);
                } else {
                    trace!("inserting into existing dir '{current_entry}'");
                    dir.files.insert(current_entry.to_owned());
                }
            }
        }
    }

    let mut root = Dir {
        name: "".to_owned(),
        files: HashSet::new(),
        subdirs: vec![],
    };

    for (path, _) in FILES.iter() {
        let path = if !path.starts_with('/') {
            String::from("/") + path
        } else {
            (*path).to_owned()
        };
        let path_obj = Path::new(&path);
        let components = path_obj
            .components()
            .chain(iter::once(Component::CurDir)) // `tuple_windows` returns an iter of `n-1` windows, so artificially "bloat" our iter.
            .tuple_windows::<(_, _)>()
            .filter_map(|(a, b)| {
                if matches!(a, Component::ParentDir) || matches!(b, Component::ParentDir) {
                    None
                } else {
                    Some(a)
                }
            });

        populate(components.peekable(), &mut root);
    }

    debug!("{root:#?}");
    root
});

fn gen_file_entry(path: &str, content: &str) -> Result<GetfattrRetVal, Errno> {
    let stat = Stat::new_simple(
        TypedModeBuilder::builder()
            .file_type(FileType::RegularFile)
            .permissions(FilePermissions::new(0o444).unwrap())
            .build(),
        1,
        content.len() as i64,
    );

    let stat = match stat {
        Ok(stat) => stat,
        Err(e) => {
            error!("Creating `stat` struct for file '{path}': {e:#}");
            return Err(Errno::ENOSYS);
        }
    };

    Ok(GetfattrRetVal { stat })
}

fn gen_dir_entry(path: &str, dir: &Dir) -> Result<GetfattrRetVal, Errno> {
    let stat = Stat::new_simple(
        TypedModeBuilder::builder()
            .file_type(FileType::Directory)
            .permissions(FilePermissions::new(0o555).unwrap())
            .build(),
        2 + dir.subdirs.len() as u64, // the entry itself, "/."; and "/.." for every subdir
        0,                            // size seems irrelevant for filesystems.
    );

    let stat = match stat {
        Ok(stat) => stat,
        Err(e) => {
            error!("Creating `stat` struct for dir '{path}': {e:#}");
            return Err(Errno::ENOSYS);
        }
    };

    Ok(GetfattrRetVal { stat })
}

fn find_dir<'a>(path: &Path, root: &'a Dir) -> Result<&'a Dir, Errno> {
    let path_str = path.to_str().expect("always unicode");
    let mut components = path.components().peekable();
    let mut last_dirs = vec![];
    let mut current_dir = &*ROOT;
    loop {
        let Some(current_entry) = components.next() else {
            error!("'{path_str}': empty Components iterator. This should NEVER happen!");
            return Err(Errno::ENOSYS);
        };

        match current_entry {
            std::path::Component::Prefix(_) => (),
            std::path::Component::RootDir => (),
            std::path::Component::CurDir => (),
            std::path::Component::ParentDir => {
                if let Some(last_dir) = last_dirs.pop() {
                    current_dir = last_dir;
                } else {
                    error!("{path:?}: End of chain (too many '..' encountered)");
                    return Err(Errno::ENOSYS);
                }
            }
            std::path::Component::Normal(current_entry) => {
                last_dirs.push(current_dir);
                current_dir = if let Some(subdir) = current_dir
                    .subdirs
                    .iter()
                    .find(|d| d.name == current_entry.to_str().expect("unicode…"))
                {
                    trace!("found subdir '{}'", subdir.name);
                    subdir
                } else {
                    error!("{path:?}: '{current_entry:?}' is not a subdirectory");
                    return Err(Errno::ENOENT);
                };
            }
        }
        if components.peek().is_none() {
            break;
        }
    }
    Ok(current_dir)
}

#[derive(Debug)]
pub struct HelloFS;

impl Filesystem for HelloFS {
    #[instrument]
    fn getattr(&self, path: &Path) -> Result<GetfattrRetVal, nix::Error> {
        let path_str = path.to_str().expect("always unicode");

        if let Some((_, content_fn)) = FILES.iter().find(|(path_, _)| path == *path_) {
            debug!("found path inside FILES array");
            let content = content_fn();
            return gen_file_entry(path_str, &content);
        };

        // otherwise this must be a directory (or non-existent)
        let dir = find_dir(path, &*ROOT)?;
        gen_dir_entry(path_str, dir)
    }

    fn readdir(&self, path: &Path) -> Result<ReaddirRetVal, nix::Error> {
        let dir = find_dir(path, &*ROOT)?;
        Ok(ReaddirRetVal {
            entries: dir
                .subdirs
                .iter()
                .map(|d| d.name.clone())
                .chain(dir.files.clone().into_iter())
                .collect(),
        })
    }

    fn open(&self, _path: &Path, _flags: OpenFlags) -> Result<OpenRetVal, nix::Error> {
        todo!("currently unused in API")
    }

    fn read(&self, path: &Path, n: u32, offset: isize) -> Result<ReadRetVal, nix::Error> {
        let path = path.to_str().expect("unicode…");
        if let Some((_, content_fn)) = FILES.iter().find(|(p, _)| *p == path) {
            let content = content_fn();
            Ok(ReadRetVal {
                content: if let Ok(offset) = usize::try_from(offset) {
                    if offset >= content.len() {
                        error!("offset out of bounds, returning 0 bytes read");
                        vec![]
                    } else {
                        let content = &content.as_bytes()[offset..];
                        // truncate to return a maximum of `n` bytes, to not overflow the user buffer
                        content[..(content.len() - 1).min(n as usize)].to_owned()
                    }
                } else {
                    error!("negative offset is not supported");
                    Err(Errno::ENOENT)?
                },
            })
        } else {
            Err(Errno::ENOENT)
        }
    }
}

fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::builder()
                .with_default_directive(Level::INFO.into())
                .from_env()?,
        )
        .init();

    let args: Vec<_> = args().collect();
    let [_, mount_point] = args.as_slice() else {
        eprintln!("Usage: hello `mount_point`");
        bail!("invalid args")
    };

    let fs = HelloFS;

    let _fuse = rust_bindgen_fuse::fuse_main(fs, mount_point, std::env::args())?;
    Ok(())
}
