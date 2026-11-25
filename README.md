# utilities

Common base utilities shared between Veecle repositories, such as Nix packages and modules.

## Flake modules

The [flake-parts](https://flake.parts) modules are exposed as `flakeModules.<name>`.
The `default` module imports all the other modules, and is the recommended way to use them, so repositories pick up new modules when updating this input.
The individual modules can still be imported on their own to opt into only some of them.

Add this repository as a flake input and import the `default` module:

```nix
{
  inputs.make-shell = {
    url = "github:nicknovitski/make-shell";
    inputs.flake-compat.follows = "";
  };
  inputs.veecle-utilities = {
    url = "github:veecle/utilities";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-parts.follows = "flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.make-shell.flakeModules.default
        inputs.veecle-utilities.flakeModules.default
      ];

      _module.args.root = ./.;
    };
}
```

All modules may rely on the importing flake to:

- Import [`make-shell`](https://github.com/nicknovitski/make-shell)'s flake module, so they can add tools to `make-shells.default`.
- Set `_module.args.root` to the repository root (e.g. `_module.args.root = ./.;`), so they can construct sources, such as for checks, from the repository's files.

### `setup-jj-fix`

Adds a `jj-fix.tools.<name>` per-system option for modules to register their formatters (`command` and `patterns`, as in [`jj fix`'s config](https://jj-vcs.github.io/jj/latest/config/#code-formatting-and-other-file-content-transformations)).
It also adds a `setup-jj-fix` app that writes them into the repository's `jj` config, so `nix run .#setup-jj-fix` sets up `jj fix` to run the same formatters as the checks.
The tool commands are resolved from `PATH` when `jj fix` runs, so run `jj fix` inside the development shell.
The app only adds or overwrites `fix.tools.<name>` entries; if a tool is renamed or removed, delete its stale entry with `jj config unset --repo fix.tools.<name>`.

### `mdslw`

Enforces the "one sentence per line" style with [`mdslw`](https://github.com/razziel89/mdslw) (the MarkDown Sentence Line Wrapper) on Markdown files, and with `mdslw-rust` on Rust doc comments (`///` and `//!`).
`mdslw-rust` detects doc comments line by line, so it also formats lines starting with `///` or `//!` inside string literals and block comments.
It adds:

- `checks.mdslw` and `checks.mdslw-rust`, covering all `*.md` and `*.rs` files of the repository, each only added if the repository has such files.
- Both tools in `make-shells.default`, so `mdslw --mode=format .` and `mdslw-rust .` reformat from the devshell.
- Both tools as `jj-fix.tools`, importing `setup-jj-fix` as well.

Both tools default to the shared config in [`nix/mdslw/defaults.toml`](nix/mdslw/defaults.toml).
`.mdslw.toml` files in the repository are merged on top of it, so they only need the settings that differ.

The tools are also available as `packages.<system>.mdslw` and `packages.<system>.mdslw-rust`.

### `nix-lint`

Formats Nix files with [`alejandra`](https://github.com/kamadorueda/alejandra) and lints them for unused code with [`deadnix`](https://github.com/astro/deadnix).
It adds:

- `checks.alejandra` and `checks.deadnix`, covering all `*.nix` files of the repository, only added if the repository has such files.
- `formatter` as `alejandra`, where a bare `nix fmt` formats the whole repository.
  It is only a default, so the importing flake can define its own `formatter` instead, e.g. a multi-language one.
- Both tools in `make-shells.default`.
- `alejandra` as a `jj-fix.tools` entry, importing `setup-jj-fix` as well.

## Development

Enter the development shell with `nix develop`, and run all checks with `nix flake check`.

To configure `jj fix` with the same formatters the checks use, run `nix run .#setup-jj-fix`.
