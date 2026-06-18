# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.PageControllerTest do
  use OpenSauceWeb.ConnCase

  test "GET / redirects to /setup when no admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == "/setup"
  end

  test "GET / renders homepage when admin exists", %{conn: conn} do
    _admin = OpenSauce.DataCase.admin_actor()

    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "OpenSauce"
    assert body =~ "Log in to workspace"
  end
end
