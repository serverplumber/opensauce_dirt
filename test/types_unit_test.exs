# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Types.UnitTest do
  use ExUnit.Case, async: true

  alias OpenSauce.Types.Unit

  test "piece special cases" do
    assert Unit.abbreviation(:piece, 0) == "no pieces"
    assert Unit.abbreviation(:piece, 1) == "1 piece"
    assert Unit.abbreviation(:piece, -1) == "-1 piece"
    assert Unit.abbreviation(:piece, 3) == "3 pieces"
  end

  test "kilogram formatting" do
    assert Unit.abbreviation(:kilogram, 1) == "1 kilogram"
    assert Unit.abbreviation(:kilogram, 2) == "2 kilograms"
    assert Unit.abbreviation(:kilogram, 0.5) == "0.5 kilograms"
  end

  test "liter formatting" do
    assert Unit.abbreviation(:liter, 1) == "1 liter"
    assert Unit.abbreviation(:liter, 25) == "25 liters"
  end

  test "cubic_meter formatting" do
    assert Unit.abbreviation(:cubic_meter, 1) == "1 cubic meter"
    assert Unit.abbreviation(:cubic_meter, 4) == "4 cubic meters"
  end

  test "single-argument abbreviation returns the short unit symbol" do
    assert Unit.abbreviation(:piece) == "pc"
    assert Unit.abbreviation(:kilogram) == "kg"
    assert Unit.abbreviation(:liter) == "L"
    assert Unit.abbreviation(:cubic_meter) == "m³"
  end
end
