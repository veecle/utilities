# Enforces the "one sentence per line" style on Markdown files and Rust doc comments.
#
# Requires the importing flake to set `_module.args.root` to its repository root,
# and to import `make-shell`'s flake module for the devshell packages.
# Both tools default to the config in `./defaults.toml`, which `.mdslw.toml` files in the repository can extend and override.
{root, ...}: {
  imports = [../setup-jj-fix.nix];

  perSystem = {
    lib,
    pkgs,
    ...
  }: let
    mdslw = pkgs.callPackage ./mdslw.nix {};
    mdslw-rust = pkgs.callPackage ./mdslw-rust.nix {inherit mdslw;};

    filesWith = ext: lib.fileset.fileFilter (f: f.hasExt ext) root;

    # Only add a check if the repository has files for it to cover.
    hasFilesWith = ext: lib.fileset.toList (filesWith ext) != [];

    sourceWith = ext:
      lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions [
          (filesWith ext)
          (lib.fileset.fileFilter (f: f.name == ".mdslw.toml") root)
        ];
      };

    mkCheck = name: attrs:
      pkgs.stdenvNoCC.mkDerivation ({
          name = "check-${name}";
          installPhase = "touch $out";
        }
        // attrs);
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

    checks =
      lib.optionalAttrs (hasFilesWith "md") {
        mdslw = mkCheck "mdslw" {
          src = sourceWith "md";
          nativeBuildInputs = [mdslw];
          buildPhase = "mdslw --mode=check --report=changed .";
        };
      }
      // lib.optionalAttrs (hasFilesWith "rs") {
        mdslw-rust = mkCheck "mdslw-rust" {
          src = sourceWith "rs";
          nativeBuildInputs = [mdslw-rust];
          buildPhase = "mdslw-rust --mode=check .";
        };
      };
  };
}
