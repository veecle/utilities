# utilities

Common base utilities shared between Veecle repositories, such as Nix packages and modules.

## Flake modules

The [flake-parts](https://flake.parts) modules are exposed as `flakeModules.<name>`.
Add this repository as a flake input and import them:

```nix
{
  inputs.veecle-utilities = {
    url = "github:veecle/utilities";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-parts.follows = "flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.veecle-utilities.flakeModules.setup-jj-fix
      ];
    };
}
```

### `setup-jj-fix`

Adds a `jj-fix.tools.<name>` per-system option for modules to register their formatters (`command` and `patterns`, as in [`jj fix`'s config](https://jj-vcs.github.io/jj/latest/config/#code-formatting-and-other-file-content-transformations)).
It also adds a `setup-jj-fix` app that writes them into the repository's `jj` config, so `nix run .#setup-jj-fix` sets up `jj fix` to run the same formatters as the checks.
The tool commands are resolved from `PATH` when `jj fix` runs, so run `jj fix` inside the development shell.
The app only adds or overwrites `fix.tools.<name>` entries; if a tool is renamed or removed, delete its stale entry with `jj config unset --repo fix.tools.<name>`.

## Development

Enter the development shell with `nix develop`, and run all checks with `nix flake check`.

To configure `jj fix` with the same formatters the checks use, run `nix run .#setup-jj-fix`.
