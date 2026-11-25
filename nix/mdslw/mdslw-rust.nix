# mdslw-rust applies mdslw to the doc comments (`///` and `//!`) of Rust files.
{
  lib,
  stdenvNoCC,
  python3,
  mdslw,
}:
stdenvNoCC.mkDerivation {
  name = "mdslw-rust";
  src = ./mdslw-rust.py;
  dontUnpack = true;
  doCheck = true;
  nativeBuildInputs = [python3 python3.pkgs.flake8 python3.pkgs.mypy];
  checkPhase = ''
    # E501: comments are written one sentence per line.
    flake8 --show-source --extend-ignore=E501 "$src"
    mypy --strict "$src"
  '';
  installPhase = ''
    mkdir -p $out/bin
    echo "#!${python3}/bin/python" > $out/bin/mdslw-rust
    cat "$src" >> $out/bin/mdslw-rust
    chmod +x $out/bin/mdslw-rust
    substituteInPlace $out/bin/mdslw-rust --replace-fail '["mdslw",' '["${lib.getExe mdslw}",'
  '';
  meta.mainProgram = "mdslw-rust";
}
