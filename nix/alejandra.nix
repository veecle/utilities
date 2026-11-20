{root, ...}: {
  perSystem = {pkgs, ...}: let
    nixSource = pkgs.lib.fileset.toSource {
      inherit root;
      fileset = pkgs.lib.fileset.fileFilter (file: file.hasExt "nix") root;
    };
  in {
    make-shells.default = {
      packages = [pkgs.alejandra];
    };

    formatter = pkgs.alejandra;

    jj-fix.tools.alejandra = {
      command = ["alejandra" "--quiet" "-"];
      patterns = ["glob:**/*.nix"];
    };

    checks.alejandra = pkgs.stdenvNoCC.mkDerivation {
      name = "alejandra-check";
      src = nixSource;
      nativeBuildInputs = [pkgs.alejandra];
      buildPhase = "alejandra --check .";
      installPhase = "touch $out";
    };
  };
}
