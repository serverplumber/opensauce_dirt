# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.ManageRoutesExistTest do
  use OpenSauceWeb.ConnCase, async: true

  test "/manage/overview exists and requires auth", %{conn: conn} do
    conn = get(conn, ~p"/manage/overview")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end

  test "/manage/purchasing exists and requires auth", %{conn: conn} do
    conn = get(conn, ~p"/manage/purchasing")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end

  test "/manage/purchasing/suppliers exists and requires auth", %{conn: conn} do
    conn = get(conn, ~p"/manage/purchasing/suppliers")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end

  test "/manage/purchasing/:po_ref exists and requires auth", %{conn: conn} do
    conn = get(conn, "/manage/purchasing/PO_XXXX_XX_XX_ABCDEF")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end
end
