{ pkgs, projectName }:

let
  krump = import ../../krump { inherit pkgs; };
  beamPackages = krump.beam.packages;

  src = ../../.;

  version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ../../VERSION);

  mixDeps = beamPackages.fetchMixDeps {
    pname = "${projectName}-deps";
    inherit src version;
    hash = "sha256-01ri6usMjR5CpXpsWbOFK2s0O8eAxc9u5derH67M+TM=";
  };

  # Vendor cargo deps for imprintor's Rust NIF — no network access in nix sandbox.
  # runCommandLocal wraps the directory into a proper derivation so fetchCargoVendor
  # can unpack it (passing a string path directly fails stdenv's unpackPhase).
  imprintorNative = pkgs.runCommandLocal "imprintor-native" { } ''
    cp -r ${mixDeps}/imprintor/native/imprintor $out
  '';

  imprintorCargoVendor = pkgs.rustPlatform.fetchCargoVendor {
    pname = "imprintor-cargo-deps";
    version = "0.6.0";
    src = imprintorNative;
    hash = "sha256-UqZLWE5zsBZYpLyyqI9Ruzz5N2PiE0AvJrxpoJbIrH0=";
  };

  release = beamPackages.mixRelease {
    pname = projectName;
    inherit src version;
    mixFodDeps = mixDeps;
    elixir = krump.beam.elixir;

    nativeBuildInputs = [ pkgs.esbuild pkgs.tailwindcss_4 pkgs.nodejs_22 pkgs.rustc pkgs.cargo ];

    env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
    env.CARGO_NET_OFFLINE = "true";

    # Deps (including imprintor's Rust NIF) compile during configurePhase, so the
    # cargo vendor config must be in place before that phase runs — preBuild is too late.
    preConfigure = ''
      export CARGO_HOME="$(pwd)/.cargo-home"
      mkdir -p "$CARGO_HOME" .cargo
      for _dir in "$CARGO_HOME" ".cargo"; do
        cat > "$_dir/config.toml" << 'CARGO_EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "${imprintorCargoVendor}/source-registry-0"
CARGO_EOF
      done
    '';

    # Override buildPhase to run all mix tasks in a single invocation via `mix do`.
    # Mix.Task.run/2 tracks which tasks have already run in the current session;
    # once compile --no-deps-check finishes, any internal compile call from tailwind
    # or esbuild is a no-op, so the git dep check for heroicons never re-runs.
    buildPhase = ''
      runHook preBuild

      rm -rf deps
      cp --no-preserve=mode -r ${mixDeps} deps

      MIX_ENV=prod mix do compile --no-deps-check, assets.deploy, release --no-deps-check

      runHook postBuild
    '';

    preBuild = ''
      # Point hex asset packages at nix-provided binaries (no network in sandbox)
      echo 'import Config' > config/nix_assets.exs
      echo 'config :esbuild, :version_check, false' >> config/nix_assets.exs
      echo 'config :esbuild, :path, "${pkgs.esbuild}/bin/esbuild"' >> config/nix_assets.exs
      echo 'config :tailwind, :version_check, false' >> config/nix_assets.exs
      echo 'config :tailwind, :path, "${pkgs.tailwindcss_4}/bin/tailwindcss"' >> config/nix_assets.exs
      echo 'import_config "nix_assets.exs"' >> config/prod.exs
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

    echo "Running migrations..."
    ${release}/bin/opensauce eval "OpenSauce.Release.migrate()"

    exec ${release}/bin/opensauce start
  '';

in
{
  image = pkgs.dockerTools.streamLayeredImage {
    name = "${projectName}-prod";
    tag = version;

    contents = pkgs.buildEnv {
      name = "prod-root";
      paths = [
        release
        entrypoint
        pkgs.bash
        pkgs.coreutils
      ];
    };

    # OTP's :pubkey_os_cacerts only scans fixed OS paths, so outbound TLS that
    # relies on OS certs (e.g. SMTP mail) needs the bundle at the Debian path.
    fakeRootCommands = ''
      mkdir -p /etc/ssl/certs
      ln -sfn ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
    '';
    enableFakechroot = true;

    config = {
      Entrypoint = [ "${entrypoint}/bin/entrypoint" ];
      ExposedPorts = { "4000/tcp" = { }; };
    };
  };
}
