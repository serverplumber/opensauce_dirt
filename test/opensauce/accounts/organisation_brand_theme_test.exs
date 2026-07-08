# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Accounts.OrganisationBrandThemeTest do
  use OpenSauce.DataCase, async: true

  alias Ash.Error.Invalid
  alias OpenSauce.Accounts.Organisation

  @valid %{
    "source" => "#1A6B3C",
    "light" => %{
      "primary" => "#2E6B4F",
      "on_primary" => "#FFFFFF",
      "primary_container" => "#B1F1C9",
      "on_primary_container" => "#00210F"
    },
    "dark" => %{
      "primary" => "#96D5AE",
      "on_primary" => "#003920",
      "primary_container" => "#0F5132",
      "on_primary_container" => "#B1F1C9"
    }
  }

  defp org do
    member = admin_actor()
    Ash.get!(Organisation, member.organisation_id, authorize?: false)
  end

  test "accepts a full theme of #rrggbb hexes" do
    assert {:ok, updated} =
             Ash.update(org(), %{brand_theme: @valid},
               action: :update_brand_theme,
               authorize?: false
             )

    assert updated.brand_theme == @valid
  end

  test "drops unknown keys instead of storing them" do
    theme = put_in(@valid, ["light", "sneaky"], "#123456")

    assert {:ok, updated} =
             Ash.update(org(), %{brand_theme: theme},
               action: :update_brand_theme,
               authorize?: false
             )

    refute get_in(updated.brand_theme, ["light", "sneaky"])
  end

  test "rejects values that are not #rrggbb — including CSS injection attempts" do
    for bad <- ["#54B57E;background:url(x)", "red", "#GGGGGG", "#54B57", nil, 42] do
      theme = put_in(@valid, ["dark", "primary"], bad)

      assert {:error, %Invalid{}} =
               Ash.update(org(), %{brand_theme: theme},
                 action: :update_brand_theme,
                 authorize?: false
               ),
             "expected #{inspect(bad)} to be rejected"
    end
  end

  test "keeps a valid screen set and drops one with a bad hex" do
    set = %{
      "bg" => "#121316",
      "paper" => "#1F1F23",
      "border" => "#373941",
      "text" => "#F2F0F4",
      "muted" => "#A9ABB4",
      "dim" => "#757780"
    }

    screen = %{"light" => set, "dark" => set}

    assert {:ok, updated} =
             Ash.update(org(), %{brand_theme: Map.put(@valid, "screen", screen)},
               action: :update_brand_theme,
               authorize?: false
             )

    assert updated.brand_theme["screen"] == screen

    bad =
      Map.put(@valid, "screen", %{screen | "dark" => %{set | "bg" => "#000;background:url(x)"}})

    assert {:ok, updated} =
             Ash.update(org(), %{brand_theme: bad},
               action: :update_brand_theme,
               authorize?: false
             )

    refute updated.brand_theme["screen"]
  end

  test "mode is stored, defaults light, and survives candidate selection" do
    assert {:ok, updated} =
             Ash.update(org(), %{brand_theme: %{"mode" => "dark"}},
               action: :update_brand_theme,
               authorize?: false
             )

    assert updated.brand_theme == %{"mode" => "dark"}
    assert OpenSauce.BrandTheme.mode(updated) == "dark"
    assert OpenSauce.BrandTheme.mode(%{brand_theme: nil}) == "light"

    theme = @valid |> Map.put("candidates", [@valid]) |> Map.put("mode", "dark")
    assert {:ok, selected} = OpenSauce.BrandTheme.select_candidate(theme, 0)
    assert selected["mode"] == "dark"

    assert :error =
             OpenSauce.BrandTheme.sanitize(%{"mode" => "dark;background:url(x)"})
  end

  test "keeps valid candidates and drops invalid ones" do
    bad = put_in(@valid, ["dark", "primary"], "#54B57E;background:url(x)")
    theme = Map.put(@valid, "candidates", [@valid, bad, "not a map"])

    assert {:ok, updated} =
             Ash.update(org(), %{brand_theme: theme},
               action: :update_brand_theme,
               authorize?: false
             )

    assert [only] = updated.brand_theme["candidates"]
    assert only["source"] == @valid["source"]
  end

  test "select_candidate promotes a stored candidate to the active theme" do
    other = %{@valid | "source" => "#AA3311"}
    theme = Map.put(@valid, "candidates", [@valid, other])

    assert {:ok, selected} = OpenSauce.BrandTheme.select_candidate(theme, 1)
    assert selected["source"] == "#AA3311"
    assert length(selected["candidates"]) == 2

    assert :error = OpenSauce.BrandTheme.select_candidate(theme, 5)
    assert :error = OpenSauce.BrandTheme.select_candidate(theme, -1)
    assert :error = OpenSauce.BrandTheme.select_candidate(@valid, 0)
  end

  test "rejects a theme missing a scheme or role" do
    assert {:error, %Invalid{}} =
             Ash.update(org(), %{brand_theme: Map.delete(@valid, "dark")},
               action: :update_brand_theme,
               authorize?: false
             )

    assert {:error, %Invalid{}} =
             Ash.update(
               org(),
               %{brand_theme: update_in(@valid, ["light"], &Map.delete(&1, "primary"))},
               action: :update_brand_theme,
               authorize?: false
             )
  end
end
