# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.BrandTheme do
  @moduledoc """
  Brand colours derived from an organisation's colour logo.

  The palette is extracted client-side (Material color utilities, HCT tonal
  palettes) when a colour logo is uploaded, then stored on
  `Organisation.brand_theme` as plain hexes:

      %{
        "source" => "#rrggbb",
        "light"  => %{"primary" => ..., "on_primary" => ..., "primary_container" => ..., "on_primary_container" => ...},
        "dark"   => %{...same roles...},
        "candidates" => [%{"source" => ..., "light" => ..., "dark" => ...}, ...]
      }

  `candidates` holds the ranked alternatives the extractor scored from the
  logo (active theme included). The org screen renders them as tappable
  swatches; `select_candidate/2` promotes one to the active theme without
  re-extracting. Each entry may also carry `"screen"` — light + dark surface
  sets (bg/paper/border/text/muted/dim) from the neutral tonal palettes.

  `"mode"` ("light" | "dark", default light) picks which scheme + surfaces
  `scheme/1` returns; it themes the org screen and all customer-facing
  documents. Emails always use the light roles (they sit on white).

  Every getter falls back to the soil/leaf (dark) or paper/deep-leaf (light)
  palette, and re-checks the hex format — these values end up inside inline
  styles and email HTML, so nothing that isn't `#rrggbb` ever gets through.
  """

  @hex ~r/^#[0-9A-Fa-f]{6}$/
  @roles ~w(primary on_primary primary_container on_primary_container)
  @screen_keys ~w(bg paper border text muted dim)
  @max_candidates 6

  @default_accent "#54B57E"
  @default_on_accent "#0C1F15"
  @default_container "#173A2B"
  @default_on_container "#6BCB93"

  # Soil palette — the dark-mode surface fallbacks when a theme has no
  # "screen" set (or no theme at all), so unthemed dark screens render
  # exactly as before.
  @default_screen_dark %{
    "bg" => "#16140E",
    "paper" => "#211E16",
    "border" => "#343025",
    "text" => "#F4EFE2",
    "muted" => "#9A9384",
    "dim" => "#6E675A"
  }

  # Light-mode counterparts: warm paper-white surfaces, deep leaf accent
  # (the bright leaf lacks contrast on white).
  @default_screen_light %{
    "bg" => "#F4F1E9",
    "paper" => "#FDFBF6",
    "border" => "#DCD6C6",
    "text" => "#211E16",
    "muted" => "#6E675A",
    "dim" => "#9A9384"
  }

  @default_light_accent "#2E6B4F"
  @default_light_on_accent "#FFFFFF"
  @default_light_container "#D5EDDF"
  @default_light_on_container "#0C2C1B"

  @doc """
  Validates and normalises a theme map; unknown keys and invalid candidates
  are dropped. A mode-only map (`%{"mode" => "light" | "dark"}`) is valid —
  orgs can pick a mode before ever uploading a logo.
  """
  def sanitize(%{} = theme) do
    core =
      case sanitize_core(theme) do
        {:ok, c} -> c
        :error -> nil
      end

    mode = sanitize_mode(Map.get(theme, "mode"))

    cond do
      core ->
        candidates = sanitize_candidates(Map.get(theme, "candidates"))

        {:ok,
         core
         |> maybe_put("candidates", candidates != [] && candidates)
         |> maybe_put("mode", mode)}

      mode ->
        {:ok, %{"mode" => mode}}

      true ->
        :error
    end
  end

  def sanitize(_), do: :error

  @doc ~s(The org's chosen document/screen mode — "light" unless stored otherwise.)
  def mode(org) do
    case Map.get(org, :brand_theme) do
      %{"mode" => "dark"} -> "dark"
      _ -> "light"
    end
  end

  @doc """
  Promotes the candidate at `index` to the active theme, keeping the
  candidate list (so the user can switch again) and the chosen mode.
  """
  def select_candidate(%{"candidates" => candidates} = theme, index)
      when is_list(candidates) and is_integer(index) and index >= 0 do
    case Enum.at(candidates, index) do
      %{} = candidate ->
        candidate
        |> Map.put("candidates", candidates)
        |> maybe_put("mode", sanitize_mode(Map.get(theme, "mode")))
        |> sanitize()

      _ ->
        :error
    end
  end

  def select_candidate(_, _), do: :error

  @doc """
  Candidate accents for the org screen swatch row, in the org's current mode.
  Returns `%{index: i, hex: primary, active: boolean}` maps; index is the
  position in the stored candidate list (pass back to `select_candidate/2`).
  """
  def candidates(org) do
    case Map.get(org, :brand_theme) do
      %{"candidates" => list} = theme when is_list(list) ->
        active_source = Map.get(theme, "source")
        scheme = mode(org)

        list
        |> Enum.with_index()
        |> Enum.flat_map(fn
          {%{} = candidate, index} ->
            hex = theme_value(candidate, scheme, "primary")

            if is_binary(hex) and hex?(hex),
              do: [
                %{index: index, hex: hex, active: Map.get(candidate, "source") == active_source}
              ],
              else: []

          _ ->
            []
        end)

      _ ->
        []
    end
  end

  defp sanitize_mode(mode) when mode in ["light", "dark"], do: mode
  defp sanitize_mode(_), do: nil

  defp maybe_put(map, _key, falsy) when falsy in [nil, false], do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp sanitize_core(%{"source" => source, "light" => light, "dark" => dark} = theme) do
    with true <- hex?(source),
         {:ok, l} <- take_roles(light),
         {:ok, d} <- take_roles(dark) do
      core = %{"source" => source, "light" => l, "dark" => d}

      case take_screen(Map.get(theme, "screen")) do
        {:ok, screen} -> {:ok, Map.put(core, "screen", screen)}
        :missing -> {:ok, core}
      end
    else
      _ -> :error
    end
  end

  defp sanitize_core(_), do: :error

  # "screen" is optional (themes stored before surface theming lack it), but
  # when present it must hold complete light + dark sets of valid hexes —
  # same injection rules as roles.
  defp take_screen(%{"light" => light, "dark" => dark}) do
    with {:ok, l} <- take_screen_set(light),
         {:ok, d} <- take_screen_set(dark) do
      {:ok, %{"light" => l, "dark" => d}}
    else
      _ -> :missing
    end
  end

  defp take_screen(_), do: :missing

  defp take_screen_set(%{} = map) do
    screen = Map.take(map, @screen_keys)

    if map_size(screen) == length(@screen_keys) and
         Enum.all?(screen, fn {_key, hex} -> hex?(hex) end) do
      {:ok, screen}
    else
      :error
    end
  end

  defp take_screen_set(_), do: :error

  defp sanitize_candidates(candidates) when is_list(candidates) do
    candidates
    |> Enum.take(@max_candidates)
    |> Enum.flat_map(fn candidate ->
      case sanitize_core(candidate) do
        {:ok, clean} -> [clean]
        :error -> []
      end
    end)
  end

  defp sanitize_candidates(_), do: []

  def dark_primary(org), do: get(org, "dark", "primary", @default_accent)
  def dark_on_primary(org), do: get(org, "dark", "on_primary", @default_on_accent)
  def light_primary(org), do: get(org, "light", "primary", @default_accent)
  def light_on_primary(org), do: get(org, "light", "on_primary", @default_on_accent)

  @doc """
  The org's full colour scheme (accent roles + screen surfaces) in its chosen
  mode, with soil/leaf (dark) or paper/deep-leaf (light) fallbacks — for
  theming the org screen and customer-facing documents.
  """
  def scheme(org) do
    case mode(org) do
      "dark" ->
        Map.merge(
          %{
            mode: "dark",
            primary: get(org, "dark", "primary", @default_accent),
            on_primary: get(org, "dark", "on_primary", @default_on_accent),
            primary_container: get(org, "dark", "primary_container", @default_container),
            on_primary_container: get(org, "dark", "on_primary_container", @default_on_container)
          },
          surfaces(org, "dark", @default_screen_dark)
        )

      "light" ->
        Map.merge(
          %{
            mode: "light",
            primary: get(org, "light", "primary", @default_light_accent),
            on_primary: get(org, "light", "on_primary", @default_light_on_accent),
            primary_container: get(org, "light", "primary_container", @default_light_container),
            on_primary_container: get(org, "light", "on_primary_container", @default_light_on_container)
          },
          surfaces(org, "light", @default_screen_light)
        )
    end
  end

  defp surfaces(org, mode, defaults) do
    %{
      bg: surface(org, mode, "bg", defaults),
      paper: surface(org, mode, "paper", defaults),
      border: surface(org, mode, "border", defaults),
      text: surface(org, mode, "text", defaults),
      muted: surface(org, mode, "muted", defaults),
      dim: surface(org, mode, "dim", defaults)
    }
  end

  defp surface(org, mode, key, defaults) do
    value = org |> Map.get(:brand_theme) |> screen_value(mode, key)
    if is_binary(value) and hex?(value), do: value, else: defaults[key]
  end

  defp screen_value(%{"screen" => %{} = screen}, mode, key), do: screen |> Map.get(mode, %{}) |> Map.get(key)

  defp screen_value(_, _, _), do: nil

  @doc ~s(Converts "#rrggbb" to an "r,g,b" triplet for CSS custom properties.)
  def rgb(<<"#", r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    "#{String.to_integer(r, 16)},#{String.to_integer(g, 16)},#{String.to_integer(b, 16)}"
  end

  @doc "Preview swatches for the org screen."
  def swatches(org) do
    Enum.reject(
      [
        get(org, "dark", "primary", nil),
        get(org, "light", "primary", nil),
        get(org, "dark", "primary_container", nil)
      ],
      &is_nil/1
    )
  end

  @doc ~s(Converts "#rrggbb" + alpha to an rgba\(\) string for tints and borders.)
  def rgba(<<"#", r::binary-size(2), g::binary-size(2), b::binary-size(2)>>, alpha) do
    "rgba(#{String.to_integer(r, 16)},#{String.to_integer(g, 16)},#{String.to_integer(b, 16)},#{alpha})"
  end

  defp get(org, scheme, role, default) do
    case org |> Map.get(:brand_theme) |> theme_value(scheme, role) do
      value when is_binary(value) -> if hex?(value), do: value, else: default
      _ -> default
    end
  end

  defp theme_value(%{} = theme, scheme, role), do: theme |> Map.get(scheme, %{}) |> Map.get(role)
  defp theme_value(_, _, _), do: nil

  defp take_roles(%{} = map) do
    roles = Map.take(map, @roles)

    if map_size(roles) == length(@roles) and Enum.all?(roles, fn {_role, hex} -> hex?(hex) end) do
      {:ok, roles}
    else
      :error
    end
  end

  defp take_roles(_), do: :error

  defp hex?(value), do: is_binary(value) and Regex.match?(@hex, value)
end
