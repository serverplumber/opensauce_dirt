{ pkgs, projectName }:

let
  beamPackages = pkgs.beamPackages;

  src = ../../.;

  mixDeps = beamPackages.fetchMixDeps {
    pname = "${projectName}-deps";
    inherit src;
    sha256 = pkgs.lib.fakeHash;
    MIX_ENV = "prod";
  };

  release = beamPackages.mixRelease {
    pname = projectName;
    version = "0.1.0";
    inherit src;
    mixNixDeps = mixDeps;
    MIX_ENV = "prod";

    nativeBuildInputs = [ pkgs.esbuild pkgs.tailwindcss pkgs.nodejs_22 ];

    preBuild = ''
      # Point hex asset packages at nix-provided binaries (no network in sandbox)
      echo 'import Config' > config/nix_assets.exs
      echo 'config :esbuild, :path, "${pkgs.esbuild}/bin/esbuild"' >> config/nix_assets.exs
      echo 'config :tailwind, :path, "${pkgs.tailwindcss}/bin/tailwind"' >> config/nix_assets.exs
      echo 'import_config "nix_assets.exs"' >> config/prod.exs

      mix assets.deploy
    '';
  };

  entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
    set -euo pipefail

    die() {
      echo ""
      echo "  ERROR: $1 is not set."
      echo "  $2"
      echo ""
      exit 1
    }

    [ -n "''${DATABASE_URL:-}"         ] || die "DATABASE_URL"         "e.g. ecto://postgres:password@localhost/opensauce_prod"
    [ -n "''${SECRET_KEY_BASE:-}"      ] || die "SECRET_KEY_BASE"      "Generate: openssl rand -base64 48"
    [ -n "''${TOKEN_SIGNING_SECRET:-}" ] || die "TOKEN_SIGNING_SECRET" "Generate: openssl rand -base64 32"
    [ -n "''${CLOAK_KEY:-}"            ] || die "CLOAK_KEY"            "Generate: openssl rand -base64 32 (must be exactly 32 bytes before encoding)"
    [ -n "''${HOST:-}"                 ] || die "HOST"                 "Public hostname, e.g. app.example.com"

    export PHX_SERVER=true

    exec ${release}/bin/opensauce start
  '';

in
{
  image = pkgs.dockerTools.streamLayeredImage {
    name = "${projectName}-prod";
    tag = "latest";

    contents = pkgs.buildEnv {
      name = "prod-root";
      paths = [
        release
        entrypoint
        pkgs.bash
        pkgs.coreutils
      ];
    };

    config = {
      Entrypoint = [ "${entrypoint}/bin/entrypoint" ];
      ExposedPorts = { "4000/tcp" = { }; };
    };
  };
}
