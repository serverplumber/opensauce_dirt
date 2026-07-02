{ pkgs, projectName }:

let
  # Base image — darkhttpd only. Built once, cached in the nix store.
  # Rebuild only when nixpkgs changes darkhttpd.
  base = pkgs.dockerTools.buildImage {
    name = "docs-base";
    tag = "latest";
    contents = pkgs.buildEnv {
      name = "docs-base-root";
      paths = [ pkgs.darkhttpd ];
    };
  };

  # Astro site — rebuilt on every content change.
  site = pkgs.buildNpmPackage {
    pname = "${projectName}-docs";
    version = "0.0.1";
    src = ../../docs;

    npmDepsHash = "sha256-wNbMpikXJPbYa1x+jkNepSXL2Y0H1h8wYQKLd1LnWkk=";

    buildPhase = ''
      npm run build
    '';

    installPhase = ''
      cp -r dist $out
    '';
  };

in
{
  image = pkgs.dockerTools.streamLayeredImage {
    name = "${projectName}-docs";
    tag = "latest";
    fromImage = base;

    extraCommands = ''
      mkdir -p assets
      cp -r ${site}/. assets/
    '';

    config = {
      Cmd = [
        "${pkgs.darkhttpd}/bin/darkhttpd"
        "/assets"
        "--port"
        "8080"
        "--addr"
        "0.0.0.0"
      ];
      ExposedPorts = { "8080/tcp" = { }; };
      WorkingDir = "/assets";
    };
  };
}
