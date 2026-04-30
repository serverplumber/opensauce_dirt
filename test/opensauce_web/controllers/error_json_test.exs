defmodule OpenSauceWeb.ErrorJSONTest do
  use OpenSauceWeb.ConnCase, async: true

  test "renders 404" do
    assert OpenSauceWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert OpenSauceWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
