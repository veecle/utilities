# Helpers shared by the modules, imported directly rather than passed as a module argument to keep them internal to this flake:
# `utilities = import ./utilities.nix {inherit lib pkgs root;};`
{
  lib,
  pkgs,
  root,
}: {
  # All files in the repository with the given extension.
  filesWithExtension = extension: lib.fileset.fileFilter (file: file.hasExt extension) root;

  # Whether a fileset contains any files, e.g. to only add checks with something to cover.
  hasFiles = fileset: lib.fileset.toList fileset != [];

  # A source of the given files, relative to the repository root.
  toSource = fileset: lib.fileset.toSource {inherit root fileset;};

  # A check succeeding if its `buildPhase` does, named `check-<name>`.
  mkCheck = name: attrs:
    pkgs.stdenvNoCC.mkDerivation ({
        name = "check-${name}";
        installPhase = "touch $out";
      }
      // attrs);
}
