# Formats Nix files with `alejandra` and lints them for unused code with `deadnix`.
{root, ...}: {
  imports = [./setup-jj-fix.nix];

  perSystem = {
    lib,
    pkgs,
    ...
  }: let
    utilities = import ./utilities.nix {inherit lib pkgs root;};
    nixFiles = utilities.filesWithExtension "nix";
  in {
    make-shells.default.packages = [pkgs.alejandra pkgs.deadnix];

    jj-fix.tools.alejandra = {
      command = ["alejandra" "--quiet" "-"];
      patterns = ["glob:**/*.nix"];
    };

    # A default, so the importing flake can define its own `formatter` instead.
    formatter = lib.mkDefault (pkgs.writeShellApplication {
      name = "alejandra";
      runtimeInputs = [pkgs.alejandra];
      text = ''
        if [ $# -eq 0 ]
        then
          # Make bare `nix fmt` format the whole flake rather than read stdin.
          exec alejandra "$PRJ_ROOT"
        else
          exec alejandra "$@"
        fi
      '';
    });

    # Only add the checks if the repository has files for them to cover.
    checks = lib.optionalAttrs (utilities.hasFiles nixFiles) {
      alejandra = utilities.mkCheck "alejandra" {
        src = utilities.toSource nixFiles;
        nativeBuildInputs = [pkgs.alejandra];
        buildPhase = "alejandra --check .";
      };

      deadnix = utilities.mkCheck "deadnix" {
        src = utilities.toSource nixFiles;
        nativeBuildInputs = [pkgs.deadnix];
        buildPhase = "deadnix --fail";
      };
    };
  };
}
