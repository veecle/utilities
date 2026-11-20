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
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        make-shell.flakeModules.default
        ./nix/alejandra.nix
      ];

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
