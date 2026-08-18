# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Types.Unit do
  @moduledoc """
  Measurement units for inventory materials. Countable plants (seeds, bulbs,
  cuttings, divisions, specimens — anything you either have or don't) are
  `:piece`. Bulk goods are `:kilogram` (ground cover, weighed amendments) or
  `:liter` / `:cubic_meter` (soil, mulch, compost sold by volume).
  """
  use Ash.Type.Enum, values: [:piece, :kilogram, :liter, :cubic_meter]

  @singular_names %{
    piece: "piece",
    kilogram: "kilogram",
    liter: "liter",
    cubic_meter: "cubic meter"
  }

  @plural_names %{
    piece: "pieces",
    kilogram: "kilograms",
    liter: "liters",
    cubic_meter: "cubic meters"
  }

  @abbreviations %{
    piece: "pc",
    kilogram: "kg",
    liter: "L",
    cubic_meter: "m³"
  }

  @doc """
  Formats a unit and a quantity for display, e.g. `"3 kilograms"`, `"1 piece"`,
  `"no pieces"`.
  """
  def abbreviation(:piece, 0), do: "no pieces"
  def abbreviation(:piece, 1), do: "1 piece"
  def abbreviation(:piece, -1), do: "-1 piece"
  def abbreviation(:piece, value) when is_integer(value), do: "#{value} pieces"
  def abbreviation(:piece, value), do: "#{:erlang.float_to_binary(value, decimals: 0)} pieces"

  def abbreviation(unit, value) do
    name = if abs(value) == 1, do: @singular_names[unit], else: @plural_names[unit]
    "#{format_number(value)} #{name}"
  end

  @doc "Returns just the short abbreviation for a unit, e.g. `\"kg\"`."
  def abbreviation(unit), do: @abbreviations[unit]

  defp format_number(value) when is_integer(value), do: "#{value}"
  defp format_number(value) when value == trunc(value), do: "#{trunc(value)}"

  defp format_number(value) do
    value
    |> :erlang.float_to_binary(decimals: 3)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end
end
