# mdslw (MarkDown Sentence Line Wrapper) enforces the "one sentence per line" Markdown style.
#
# The binary is wrapped to use `defaults` (by default `./defaults.toml`) as its default config,
# which `.mdslw.toml` files in the repository then extend and override.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  writeText,
  makeBinaryWrapper,
  defaults ? lib.importTOML ./defaults.toml,
}: let
  version = "0.17.2";

  # mdslw treats every `MDSLW_*` environment variable as taking precedence over config files,
  # except for values ending in a zero-width space: it uses that internally to mark built-in defaults.
  # See `ValueWOrigin` in `src/cfg.rs`.
  # The install check below verifies this keeps working.
  zeroWidthSpace = builtins.fromJSON ''"\u200b"'';
  wrapperArgs = lib.concatLists (lib.mapAttrsToList (key: value: [
      "--set-default"
      "MDSLW_${lib.toUpper (builtins.replaceStrings ["-"] ["_"] key)}"
      "${toString value}${zeroWidthSpace}"
    ])
    defaults);
  # Network-free replacement for upstream build.rs:
  # it only stages the bundled "ac" language spec and points the crate at it, skipping the per-language CLDR downloads.
  buildRs = writeText "build.rs" ''
    use std::env;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::str::FromStr;

    fn main() {
        println!("cargo::rerun-if-changed=src/lang/ac");
        println!("cargo::rerun-if-changed=src/cfg.rs");
        let base_path = Path::new(
            &env::var_os("OUT_DIR").expect("OUT_DIR env var must be set"),
        )
        .join("lang");
        if let Ok(true) = fs::exists(&base_path) {
            fs::remove_dir_all(&base_path).expect("failed to remove outdated lang spec dir");
        }
        fs::create_dir(&base_path).expect("failed to create lang spec dir");
        let ac_path =
            PathBuf::from_str("src/lang/ac").expect("failed to build path to lang spec ac");
        fs::copy(ac_path, base_path.join("ac")).expect("failed to copy ac lang specs");
        println!(
            "cargo::rustc-env=MDSLW_LANG_DIR={}",
            base_path.to_string_lossy()
        );
    }
  '';
in
  rustPlatform.buildRustPackage {
    pname = "mdslw";
    inherit version;
    src = fetchFromGitHub {
      owner = "razziel89";
      repo = "mdslw";
      tag = version;
      hash = "sha256-4iSQS13tMglOV8nWBw7Zxi8+DcKHKGl99cuHKvOIE7s=";
    };
    cargoHash = "sha256-emaBv9b9WjFKbyN5V0A5N8NHea8YMBvj256gv9P116E=";
    postPatch = ''
      cp ${buildRs} build.rs
      substituteInPlace Cargo.toml --replace-fail '[build-dependencies]
      reqwest = {version = "0.13", features = ["default", "json", "blocking"]}
      serde_json = { version = "1" }' ""
      # `read_stdin` joins lines with `\n`, dropping the file's trailing newline and never restoring it (unlike file mode).
      # Read stdin verbatim so `jj fix` keeps the newline.
      substituteInPlace src/fs.rs --replace-fail 'std::io::stdin()
              .lines()
              // Interrupt as soon as one line could not be read.
              .map_while(Result::ok)
              .collect::<Vec<_>>()
              .join("\n")' 'std::io::read_to_string(std::io::stdin()).expect("failed to read stdin")'
    '';
    # Tests require the build-time downloaded language files we skip.
    doCheck = false;

    nativeBuildInputs = [makeBinaryWrapper];
    postInstall = "wrapProgram $out/bin/mdslw ${lib.escapeShellArgs wrapperArgs}";

    # Checks that the wrapped defaults apply, and that `.mdslw.toml` files still override and extend them.
    # Assumes the repository's default config, so it is skipped when `defaults` is overridden.
    doInstallCheck = defaults == lib.importTOML ./defaults.toml;
    installCheckPhase = ''
      runHook preInstallCheck
      cd "$(mktemp -d)"

      assert_formats() {
        local result
        result=$(printf '%s\n' "$1" | "$out/bin/mdslw" --stdin-filepath=./test.md)
        if [ "$result" != "$2" ]; then
          printf 'mdslw formatted\n%s\ninto\n%s\ninstead of\n%s\n' "$1" "$result" "$2" >&2
          exit 1
        fi
      }

      input="Note: see Art. 5 for the details of this sentence, which is longer than eighty characters."

      # Defaults: no wrapping (`max-width`), no break at `:` (`end-markers`) or after `Art.` (`suppressions`).
      assert_formats "$input" "$input"

      # A config file overrides `end-markers`, while the other defaults still apply.
      echo 'end-markers = ":"' > .mdslw.toml
      assert_formats "$input" "Note:
      see Art. 5 for the details of this sentence, which is longer than eighty characters."

      runHook postInstallCheck
    '';
    meta.mainProgram = "mdslw";
  }
