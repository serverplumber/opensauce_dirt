defmodule OpenSauce.Storage do
  @moduledoc """
  Pluggable file storage interface for OpenSauce.

  All file persistence goes through this module so that the backing store can be
  swapped without touching call-sites. The local adapter (`OpenSauce.Storage.Local`)
  writes to `priv/static/` and is served by Phoenix's static file plug. A future
  S3-compatible adapter needs only implement the three callbacks below.

  ## Configuration

      config :opensauce, :storage_adapter, OpenSauce.Storage.Local

  The adapter module must implement this behaviour. The default is `Local`.

  ## Storage keys

  A *storage key* is an opaque, adapter-defined string. Callers must treat it as a
  black box — do not parse or construct keys outside the adapter. Store the key on
  the resource (e.g. `EngagementImage.storage_key`) and pass it back verbatim to
  `url/1` or `delete/1`.

  ## Scope

  `put/4` accepts a `scope` prefix (e.g. `"engagements/abc-123"`) that adapters use
  to organise storage. In S3 this becomes part of the object key; locally it becomes
  a sub-directory under `uploads/`. Keep scopes stable — changing them won't move
  existing files.
  """

  @type storage_key :: String.t()

  @doc """
  Store `data` at `scope/filename`, returning an opaque storage key on success.

  `scope`    — organisational prefix, e.g. `"engagements/<id>"`. Must not start with `/`.
  `filename` — original filename; used as a hint; adapter may sanitise or prefix it.
  `content_type` — MIME type, e.g. `"image/jpeg"`. Passed through to adapters that
                   set response headers (S3 `Content-Type`).
  `data`     — raw binary content.
  """
  @callback put(scope :: String.t(), filename :: String.t(), content_type :: String.t(), data :: binary()) ::
              {:ok, storage_key()} | {:error, term()}

  @doc """
  Return a URL suitable for rendering `storage_key` in a browser.

  For the local adapter this is a root-relative path (`"/uploads/..."`).
  For S3-compatible adapters this is a full HTTPS URL, optionally pre-signed.
  """
  @callback url(storage_key :: storage_key()) :: {:ok, String.t()} | {:error, term()}

  @doc """
  Permanently delete the file at `storage_key`. Idempotent — missing keys return `:ok`.
  """
  @callback delete(storage_key :: storage_key()) :: :ok | {:error, term()}

  # ---------------------------------------------------------------------------
  # Delegating helpers — call-sites use these rather than the behaviour directly
  # ---------------------------------------------------------------------------

  def put(scope, filename, content_type, data), do: adapter().put(scope, filename, content_type, data)
  def url(storage_key), do: adapter().url(storage_key)
  def delete(storage_key), do: adapter().delete(storage_key)

  defp adapter, do: Application.get_env(:opensauce, :storage_adapter, OpenSauce.Storage.Local)
end
