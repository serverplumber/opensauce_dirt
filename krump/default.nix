{ pkgs }:
let
  # Single source for BEAM versions — dev container, prod image, and nix devshells
  # all import this file and reference these attrs.
  beam = rec {
    packages = pkgs.beamPackages;
    elixir   = packages.elixir_1_20;
    erlang   = packages.erlang;
    hex      = packages.hex;
    rebar3   = packages.rebar3;
  };
in
{
  inherit beam;

  devTools =
    [ beam.elixir beam.erlang ]
    ++ (with pkgs; [
      nodejs_22
      postgresql_16 # client only — server runs in podman
      inotify-tools # file watching for Phoenix live reload
      gnumake
      gcc

      bat
      curl
      eza
      git
      glow
      gnugrep
      gnused
      harper
      helix
      jq
      just
      lowdown
      mdformat
      neovim
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nix
      starship
      vim
      wget
    ]);

  env = {
    NIXPKGS_ALLOW_UNFREE = "1";
    FONTCONFIG_PATH = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts";
    ELIXIR_ERL_OPTIONS = "+fnu";
    # Hex is a BEAM library, not a binary — mix discovers it on the code path
    # via MIX_PATH. This is the same mechanism mixRelease uses; without it mix
    # prompts to fetch hex from the network on first use.
    MIX_PATH = "${beam.hex}/lib/erlang/lib/hex/ebin";
    # Rebar3 is the other tool mix downloads on demand (needed for rebar3 deps
    # like telemetry). Point mix at the nix one so it never fetches.
    MIX_REBAR3 = "${beam.rebar3}/bin/rebar3";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  shellHook = shell: ''
    alias ls='${pkgs.eza}/bin/eza --icons'
    alias tree='${pkgs.eza}/bin/eza --tree --icons'
    eval "$(${pkgs.starship}/bin/starship init ${shell})"
  '';
}
