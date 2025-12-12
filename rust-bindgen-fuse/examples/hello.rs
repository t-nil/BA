use std::{env::args, path::Path};

use color_eyre::{Result, eyre::bail};
use itertools::Itertools as _;
use nix::errno::Errno;
use rust_bindgen_fuse::{
    FilePermissions, FileType, Filesystem, GetfattrRetVal, ReaddirRetVal, Stat, TypedModeBuilder,
};
use tracing::Level;
use tracing_subscriber::EnvFilter;

const HELLO_CONTENT: &str = "Hello world!\n";
const FILES: [&str; 1] = ["hello.txt"];

pub struct HelloFS;

impl Filesystem for HelloFS {
    fn getattr(&self, path: &Path) -> Result<GetfattrRetVal, nix::Error> {
        if path == "/hello.txt" {
            Ok(GetfattrRetVal {
                stat: Stat::new_simple(
                    TypedModeBuilder::builder()
                        .file_type(FileType::RegularFile)
                        .permissions(FilePermissions::new(0o444).unwrap())
                        .build(),
                    1,
                    HELLO_CONTENT.len() as i64,
                )
                .unwrap(),
            })
        } else {
            Err(Errno::ENOENT)
        }
    }

    fn readdir(&self, path: &Path) -> Result<ReaddirRetVal, nix::Error> {
        if path == "/" {
            Ok(ReaddirRetVal {
                entries: FILES.into_iter().map(|s| s.to_owned()).collect_vec(),
            })
        } else {
            Err(Errno::ENOENT)
        }
    }

    fn open(&self) {
        todo!()
    }

    fn read(&self) {
        todo!()
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
