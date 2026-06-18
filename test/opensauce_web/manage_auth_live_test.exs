# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.ManageAuthLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "manage products redirects unauthenticated to sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/manage/products")
  end
end
