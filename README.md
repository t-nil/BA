# bachelors-thesis

## Code

- look in `rust-bindgen-fuse`

Deps:
- standard linux build tools (gcc, make, etc.)
- Rust
- LLVM
- clang
- meson
- fuse3
- git

```bash
git clone https://github.com/t-nil/BA
cd BA

git clone --filter=blob:none https://github.com/libfuse/libfuse
cd libfuse

meson build/
cd build/
meson compile
cd ../..

cargo run --example hello2 -- <mount_path>
```

- `RUST_LOG=(info|debug)` for more logging
