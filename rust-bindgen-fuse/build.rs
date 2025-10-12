use std::env;
use std::path::PathBuf;

const LIBFUSE_NAME: &str = "fuse3";
const LIBFUSE_DIR: &str = "./libfuse/build/lib";

// wrap output cause cargo won't display raw stdout/err
// https://stackoverflow.com/a/75263349
macro_rules! p {
    ($($tokens: tt)*) => {
        println!("cargo::warning=INFO DUMP - {}", format!($($tokens)*))
    }
}

fn main() {
    // Tell cargo to look for shared libraries in the specified directory
    println!("cargo:rustc-link-search={LIBFUSE_DIR}");

    // Tell cargo to tell rustc to link the system FUSE
    // shared library.
    println!("cargo:rustc-link-lib={LIBFUSE_NAME}");

    // The bindgen::Builder is the main entry point
    // to bindgen, and lets you build up options for
    // the resulting bindings.
    let bindings = bindgen::Builder::default()
        // The input header we would like to generate
        // bindings for.
        .header("headers/fuse.h")
        // Tell cargo to invalidate the built crate whenever any of the
        // included header files changed.
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        // add `build/` dir to clang include path, so clang finds `libfuse_config.h`
        .clang_args(["-I", "./libfuse/build"])
        // Finish the builder and generate the bindings.
        .generate()
        // Unwrap the Result and panic on failure.
        .expect("Unable to generate bindings");

    // Write the bindings to the $OUT_DIR/bindings.rs file.
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    p!(
        "bindings path: `{out_path}/bindings.rs`",
        out_path = out_path.to_string_lossy()
    )
}
