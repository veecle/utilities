# Enforces the "one sentence per line" style on Markdown files and Rust doc comments.
# Both tools default to the config in `./defaults.toml`, which `.mdslw.toml` files in the repository can extend and override.
{root, ...}: {
  imports = [../setup-jj-fix.nix];

  perSystem = {
    lib,
    pkgs,
    ...
  }: let
    utilities = import ../utilities.nix {inherit lib pkgs root;};
    mdslw = pkgs.callPackage ./mdslw.nix {};
    mdslw-rust = pkgs.callPackage ./mdslw-rust.nix {inherit mdslw;};

    sourceWithExtension = extension:
      utilities.toSource (lib.fileset.unions [
        (utilities.filesWithExtension extension)
        (lib.fileset.fileFilter (file: file.name == ".mdslw.toml") root)
      ]);
  in {
    make-shells.default.packages = [mdslw mdslw-rust];

    jj-fix.tools = {
      mdslw = {
        # `./` prefix: for directory-less paths such as `README.md`, `mdslw` fails to locate `.mdslw.toml` and silently falls back to its default config.
        command = ["mdslw" "--stdin-filepath=./$path"];
        patterns = ["glob:**/*.md"];
      };
      mdslw-rust = {
        command = ["mdslw-rust" "--stdin-filepath=$path"];
        patterns = ["glob:**/*.rs"];
      };
    };

    # Only add the checks if the repository has files for them to cover.
    checks =
      lib.optionalAttrs (utilities.hasFiles (utilities.filesWithExtension "md")) {
        mdslw = utilities.mkCheck "mdslw" {
          src = sourceWithExtension "md";
          nativeBuildInputs = [mdslw];
          buildPhase = "mdslw --mode=check --report=changed .";
        };
      }
      // lib.optionalAttrs (utilities.hasFiles (utilities.filesWithExtension "rs")) {
        mdslw-rust = utilities.mkCheck "mdslw-rust" {
          src = sourceWithExtension "rs";
          nativeBuildInputs = [mdslw-rust];
          buildPhase = "mdslw-rust --mode=check .";
        };
      };
  };
}
