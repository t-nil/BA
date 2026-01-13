use std::env;
use std::path::PathBuf;
#[cfg(not(target_os = "windows"))]
use std::process::Command;

const INPUT_HEADER: &str = "headers/fuse.h";

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
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    let extern_c = out_dir.join("extern.c");
    let bindings_rs = out_dir.join("bindings.rs");

    // This is the path to the object file.
    let extern_o = out_dir.join("extern.o");
    // This is the path to the static library file.
    let libextern_a = out_dir.join("libextern.a");

    // The bindgen::Builder is the main entry point
    // to bindgen, and lets you build up options for
    // the resulting bindings.
    let bindings = bindgen::Builder::default()
        // The input header we would like to generate
        // bindings for.
        .header(INPUT_HEADER)
        // generate wrappers for `static inline` functions like `fuse_main_fn()`
        .wrap_static_fns(true)
        .wrap_static_fns_path(&extern_c)
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
    bindings
        .write_to_file(bindings_rs)
        .expect("Couldn't write bindings!");

    // https://github.com/rust-lang/rust-bindgen/discussions/2405
    // Compile the generated wrappers into an object file.
    {
        let clang_output = Command::new("clang")
            .arg("-O")
            .arg("-c")
            .arg("-o")
            .arg(&extern_o)
            .arg(&extern_c)
            .arg("-I")
            .arg("./libfuse/build")
            .arg("-I")
            .arg(".")
            .arg("-include")
            .arg(env::current_dir().unwrap().join(INPUT_HEADER))
            .output()
            .unwrap();
        if !clang_output.status.success() {
            panic!(
                "Could not compile object file:\n{}",
                String::from_utf8_lossy(&clang_output.stderr)
            );
        }

        // Turn the object file into a static library
        #[cfg(not(target_os = "windows"))]
        let lib_output = Command::new("ar")
            .arg("rcs")
            .arg(libextern_a)
            .arg(extern_o)
            .output()
            .unwrap();
        #[cfg(target_os = "windows")]
        let lib_output = Command::new("LIB")
            .arg(extern_o)
            .arg(format!(
                "/OUT:{}",
                out_dir_path.join("libextern.lib").display()
            ))
            .output()
            .unwrap();
        if !lib_output.status.success() {
            panic!(
                "Could not emit library file:\n{}",
                String::from_utf8_lossy(&lib_output.stderr)
            );
        }

        // Tell cargo to statically link against the `libextern` static library.
        println!(
            "cargo:rustc-link-search={out_dir}",
            out_dir = out_dir.to_str().unwrap()
        );
        println!("cargo:rustc-link-lib=static=extern");
    }
    // Tell cargo to tell rustc to look for shared libraries in the specified directory
    println!("cargo:rustc-link-search={LIBFUSE_DIR}");

    // Tell cargo to tell rustc to link the system FUSE
    // shared library.
    println!("cargo:rustc-link-lib={LIBFUSE_NAME}");

    p!(
        "bindings path: `{out_dir}/bindings.rs`",
        out_dir = out_dir.to_string_lossy()
    )
}
