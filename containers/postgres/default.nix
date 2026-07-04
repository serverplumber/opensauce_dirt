{ pkgs, projectName }:

let
  # Digest-pinned upstream postgres image — regenerate with `just update-postgres`.
  # Don't override the pinned attrs here: pullImage's output hash covers the
  # repo-tag metadata, so any rename invalidates the prefetched hash. The
  # project-scoped rename happens via `podman tag` in `just deploy-db`.
  pulled = pkgs.dockerTools.pullImage (import ../base-image-postgres-18.nix);
in
{
  # Not a nix build of postgres — just streams the pinned upstream image
  # so `nix run .#postgres-image | podman load` works like the other images.
  image = pkgs.writeShellScript "stream-postgres-image" ''
    exec cat ${pulled}
  '';
}
