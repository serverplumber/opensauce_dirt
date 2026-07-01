{ pkgs, projectName }:

let
  site = pkgs.buildNpmPackage {
    pname = "${projectName}-docs";
    version = "0.0.1";
    src = ../../docs;

    # Run `just docs` with a fake hash first — nix will error with the real one.
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

    contents = pkgs.buildEnv {
      name = "docs-root";
      paths = [ pkgs.darkhttpd ];
    };

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
