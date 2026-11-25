{
  description = "Common base utilities shared between Veecle repositories";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05-small";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    make-shell = {
      url = "github:nicknovitski/make-shell";
      inputs.flake-compat.follows = "";
    };
  };

  outputs = inputs @ {
    flake-parts,
    make-shell,
    ...
  }: let
    # Modules for other flake-parts based repositories to import.
    # They may all assume the importing flake imports `make-shell`'s flake module and sets `_module.args.root` (see the README).
    # Bound here rather than referenced via `self` so they can also be imported below, as `imports` can't depend on the flake's outputs.
    flakeModules = {
      setup-jj-fix = ./nix/setup-jj-fix.nix;
      mdslw = ./nix/mdslw;
      nix-lint = ./nix/nix-lint.nix;
      # Imports all the other modules. Also required because flake-parts aliases `flake.flakeModule` to this,
      # so evaluating all outputs (e.g. `nix flake show`) fails without it.
      default.imports = builtins.attrValues (builtins.removeAttrs flakeModules ["default"]);
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        flake-parts.flakeModules.flakeModules
        make-shell.flakeModules.default
        flakeModules.default
      ];

      flake = {inherit flakeModules;};

      perSystem = {pkgs, ...}: {
        packages = rec {
          mdslw = pkgs.callPackage ./nix/mdslw/mdslw.nix {};
          mdslw-rust = pkgs.callPackage ./nix/mdslw/mdslw-rust.nix {inherit mdslw;};
        };
      };

      # Instead of each module having to use some number of `../`'s to reference the repository root,
      # pass down a nix path they can construct sources from.
      _module.args.root = ./.;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };
}
