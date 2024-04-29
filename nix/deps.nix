{ pkgs, poetry2nix }:

with builtins;

let

  inherit (pkgs) stdenv lib poetry;
  python = pkgs.python311;
  # poetry = (pkgs.poetry.override { python3 = python; });

  overrides = poetry2nix.defaultPoetryOverrides.extend (
    self: super:
      let
        pythonBuildDepNameValuePair = deps: pname: {
          name = pname;
          value = super.${pname}.overridePythonAttrs (old: {
            buildInputs = old.buildInputs ++ deps;
          });
        };

        addPythonBuildDeps = deps: pnames:
          lib.listToAttrs
            (map
              (pythonBuildDepNameValuePair deps)
              pnames);
      in
      {
        cryptography = super.cryptography.overridePythonAttrs (old: rec {
          cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            inherit (old) src;
            name = "${old.pname}-${old.version}";
            sourceRoot = "${old.pname}-${old.version}/${cargoRoot}";
            sha256 = "sha256-Pw3ftpcDMfZr/w6US5fnnyPVsFSB9+BuIKazDocYjTU=";
          };
          cargoRoot = "src/rust";
        });

      } //
      (addPythonBuildDeps [ self.setuptools-scm self.setuptools self.greenlet ] [
        "pdbpp"
      ]) //
      (addPythonBuildDeps
        [ self.setuptools ]
        [
          "konch"
          "flask-resty"
          "flask-apscheduler"
          "probableparsing"
          "usaddress"
          "gspread-formatting"
        ]
      ) //
      (addPythonBuildDeps
        [ self.flit-core ] [
        "itsdangerous"
        "marshmallow"
        "flask-sqlalchemy"
        "marshmallow-sqlalchemy"
        "flask-marshmallow"
      ]
      ) //
      (addPythonBuildDeps
        [ self.poetry-core ] [
        "iso8601"
      ]) //
      (addPythonBuildDeps
        [ self.poetry-core self.greenlet ] [
        "alembic"
        "pytest-factoryboy"
        "sqlalchemy"
        "sqlalchemy-utils"
        "zope-sqlalchemy"
      ]) //
      (addPythonBuildDeps
        [ self.hatchling ] [
        "wtforms"
      ]) //
      (addPythonBuildDeps
        [ self.Babel ] [
        "wtforms"
      ])
  );

  mkPoetryApplication = args:
    poetry2nix.mkPoetryApplication (args // {
      inherit overrides;
      inherit python;
    });

  inherit (poetry2nix.mkPoetryPackages {
    projectDir = ../.;
    inherit python;
    inherit overrides;
  }) poetryPackages pyProject;

  poetryPackagesByName =
    lib.listToAttrs
      (map
        (p: { name = p.pname or "none"; value = p; })
        poetryPackages);

in
rec {
  inherit mkPoetryApplication pkgs poetryPackagesByName pyProject python;
  inherit (pkgs) glibcLocales;
  inherit (poetryPackagesByName) alembic deform babel gunicorn ipython;

  # Can be imported in Python code or run directly as debug tools
  debugLibsAndTools = with python.pkgs; [
    poetryPackagesByName.pdbpp
    poetryPackagesByName.ipython
  ];

  pythonDevTest = python.buildEnv.override {
    extraLibs = poetryPackages ++
      debugLibsAndTools;
    ignoreCollisions = true;
  };

  pythonTest = pythonDevTest;
  pythonDev = pythonDevTest;

  # Code style and security tools
  linters = with python.pkgs; let

    # Pylint needs to import the modules of our dependencies
    # but we don't want to override its own PYTHONPATH.
    setSysPath = ''
      import sys
      sys.path.append("${pythonDev}/${pythonDev.sitePackages}")
    '';

    pylintWrapper = with python.pkgs; pkgs.writeScriptBin "pylint" ''
      ${pylint}/bin/pylint --init-hook='${setSysPath}' "$@"
    '';

    isortWrapper = with python.pkgs; pkgs.writeScriptBin "isort" ''
      ${isort}/bin/isort --virtual-env=${pythonDev} "$@"
    '';

  in
  [
    # bandit
    #isortWrapper
    pkgs.nixpkgs-fmt
    #pylintWrapper
  ];

  # Various tools for log files, deps management, running scripts and so on
  shellTools =
    let
      console = pkgs.writeScriptBin "console" ''
        export PYTHONPATH=$PYTHONPATH:${pythonDev}/${pythonDev.sitePackages}
        ${ipython}/bin/ipython -i consoleenv.py "$@"
      '';
    in
    [
      console
      pkgs.postgresql_16
      poetryPackagesByName.pdbpp
      poetry
      poetryPackagesByName.gunicorn
    ];

  # Needed for a development nix shell
  shellInputs =
    linters ++
    shellTools ++ [
      pythonTest
    ];

  shellPath = lib.makeBinPath shellInputs;
}
