# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.ManageCustomersInteractionsLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :staff
  test "new customer button opens modal and submits form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/customers")

    view
    |> element("a[href='/manage/customers/new']")
    |> render_click()

    assert_patch(view, ~p"/manage/customers/new")
    assert has_element?(view, "#customer-modal")

    unique = System.unique_integer()
    email = "test+#{unique}@example.com"

    params = %{
      "customer" => %{
        "type" => "individual",
        "first_name" => "Test",
        "last_name" => "Customer#{unique}",
        "email" => email,
        "phone" => "+1234567890",
        "billing_address" => %{
          "is_billing" => "true",
          "is_garden" => "false",
          "is_indoor" => "false",
          "street" => "123 Main St",
          "city" => "Springfield",
          "province" => "IL",
          "zip" => "62701",
          "country" => "US"
        },
        "garden_addresses" => %{
          "0" => %{
            "is_billing" => "false",
            "is_garden" => "true",
            "is_indoor" => "false",
            "street" => "456 Oak Ave",
            "city" => "Shelbyville",
            "province" => "IL",
            "zip" => "62565",
            "country" => "US"
          }
        }
      }
    }

    view
    |> element("#customer-form")
    |> render_submit(params)

    assert render(view) =~ "Customer created successfully"
    assert render(view) =~ email
  end

end
