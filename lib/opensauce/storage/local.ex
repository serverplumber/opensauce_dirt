defmodule OpenSauce.Storage.Local do
  @moduledoc """
  Local-disk storage adapter. Files are written to the configured `upload_dir` and
  served by Phoenix's static file plug.

  ## Configuration

      # dev.exs — files land in priv/static/uploads, served at /uploads/...
      config :opensauce,
        storage_adapter: OpenSauce.Storage.Local,
        upload_dir: Path.join([File.cwd!(), "priv", "static", "uploads"])

      # runtime.exs — separate volume mount in production
      config :opensauce,
        storage_adapter: OpenSauce.Storage.Local,
        upload_dir: System.get_env("UPLOAD_DIR") || "/var/lib/opensauce/uploads"

  In development the upload_dir sits inside `priv/static/` so Phoenix serves the
  files automatically. In production, configure a reverse-proxy alias or mount the
  directory under the static root as appropriate.

  For production at scale, swap to an S3-compatible adapter:

      config :opensauce, storage_adapter: OpenSauce.Storage.S3  # (not yet implemented)

  ## Storage key format

  Keys are relative paths within the upload_dir, e.g.:

      "engagements/abc-123/8f3d-photo.jpg"

  The URL returned by `url/1` prepends `/uploads/` — this assumes the upload_dir
  is mounted or served at that path. Adjust if your deployment differs.

  ## Directory creation

  `put/4` creates intermediate directories as needed. No pre-provisioning required.
  """

  @behaviour OpenSauce.Storage

  @impl true
  def put(scope, filename, _content_type, data) do
    safe_name = filename |> Path.basename() |> String.replace(~r/[^\w.\-]/, "_")

    unique_name =
      "#{6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)}-#{safe_name}"

    key = Path.join([scope, unique_name])
    abs_path = Path.join(upload_dir(), key)

    with :ok <- File.mkdir_p(Path.dirname(abs_path)),
         :ok <- File.write(abs_path, data) do
      {:ok, key}
    end
  end

  @impl true
  def url(storage_key) do
    # Assumes upload_dir is served at /uploads/ by Phoenix or a reverse proxy.
    {:ok, "/uploads/" <> storage_key}
  end

  @impl true
  def delete(storage_key) do
    path = Path.join(upload_dir(), storage_key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp upload_dir do
    Application.get_env(:opensauce, :upload_dir) ||
      Path.join([File.cwd!(), "priv", "static", "uploads"])
  end
end
