use std::{env::args, path::Path};

use color_eyre::Result;
use rust_bindgen_fuse::{Filesystem, GetfattrRetVal, Stat};

pub struct HelloFS;

impl Filesystem for HelloFS {
    fn getattr(&self, path: &Path) -> Result<GetfattrRetVal, nix::Error> {
        if path == "/hello.txt" {
            Ok(GetfattrRetVal {
                stat: Stat(stat {
                    st_dev: (),
                    st_ino: (),
                    st_nlink: (),
                    st_mode: (),
                    st_uid: (),
                    st_gid: (),
                    __pad0: (),
                    st_rdev: (),
                    st_size: (),
                    st_blksize: (),
                    st_blocks: (),
                    st_atim: (),
                    st_mtim: (),
                    st_ctim: (),
                    __glibc_reserved: (),
                }),
                fuse_file_info: (),
            })
        }
    }

    fn readdir(&self, path: &Path) -> Result<ReaddirRetVal, nix::Error> {
        todo!()
    }

    fn open(&self) {
        todo!()
    }

    fn read(&self) {
        todo!()
    }
}

fn main() -> Result<()> {
    let args: Vec<_> = args().collect();
    let [_, mount_point] = args.as_slice() else {
        eprintln!("Usage: hello `mount_point`");
    };

    let fuse = rust_bindgen_fuse::fuse_init(fs, mount_point)?;
}
