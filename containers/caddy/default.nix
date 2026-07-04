{ pkgs, projectName }:

let
  # Digest-pinned upstream caddy image — regenerate with `just update-caddy`.
  # Don't override the pinned attrs here: pullImage's output hash covers the
  # repo-tag metadata, so any rename invalidates the prefetched hash. The
  # project-scoped rename happens via `podman tag` in `just deploy-caddy`.
  pulled = pkgs.dockerTools.pullImage (import ../base-image-caddy-2.nix);
in
{
  # Not a nix build of caddy — just streams the pinned upstream image
  # so `nix run .#caddy-image | podman load` works like the other images.
  image = pkgs.writeShellScript "stream-caddy-image" ''
    exec cat ${pulled}
  '';
}
