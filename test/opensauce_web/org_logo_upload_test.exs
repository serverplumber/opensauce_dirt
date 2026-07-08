# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.OrgLogoUploadTest do
  use OpenSauceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # Structural guard for the logo auto-upload pipeline: allow_upload config,
  # the progress callback wiring, consume_uploaded_entries, storage write, and
  # the org update all have to line up for the upload to land. Each has broken
  # silently before (upload stuck at "Uploading…" with no error).

  # 1x1 PNG — square, so it passes the dimension check.
  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "logo_test_#{System.unique_integer([:positive])}")
    old = Application.get_env(:opensauce, :upload_dir)
    Application.put_env(:opensauce, :upload_dir, dir)

    on_exit(fn ->
      Application.put_env(:opensauce, :upload_dir, old)
      File.rm_rf!(dir)
    end)

    :ok
  end

  @tag role: :owner
  test "colour logo auto-upload consumes and saves", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/org")

    input =
      file_input(view, "#org-form", :logo_colour, [
        %{name: "logo.png", content: @png, type: "image/png"}
      ])

    render_upload(input, "logo.png")

    assert render(view) =~ "/uploads/orgs/"
  end

  @tag role: :owner
  test "greyscale logo auto-upload consumes and saves", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/org")

    input =
      file_input(view, "#org-form", :logo_greyscale, [
        %{name: "logo.png", content: @png, type: "image/png"}
      ])

    render_upload(input, "logo.png")

    assert render(view) =~ "/uploads/orgs/"
  end
end
