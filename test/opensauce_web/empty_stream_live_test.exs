# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.EmptyStreamLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # phx-update="stream" requires every direct child to carry an id attribute.
  # An empty-state element inside the stream div (without an id) crashes the
  # LiveView client when the list is empty. These tests mount each stream screen
  # with no data so the regression is caught immediately if the pattern re-appears.

  @tag role: :staff
  test "customer index mounts cleanly with no customers", %{conn: conn} do
    {:ok, _view, _html} = live(conn, ~p"/manage/customers")
  end

  @tag role: :staff
  test "inventory index mounts cleanly with no materials", %{conn: conn} do
    {:ok, _view, _html} = live(conn, ~p"/manage/inventory")
  end
end
