defmodule OpenSauceWeb.Components do
  @moduledoc """
  Provides a unified interface for importing all UI components.

  This module re-exports components from specialized modules:
  - OpenSauceWeb.CoreComponents
  - OpenSauceWeb.FormComponents
  - OpenSauceWeb.NavigationComponents
  - OpenSauceWeb.DataDisplayComponents
  - OpenSauceWeb.ModalComponents
  """

  defmacro __using__(_opts) do
    quote do
      import OpenSauceWeb.Components.Core
      import OpenSauceWeb.Components.DataVis
      import OpenSauceWeb.Components.Forms
      import OpenSauceWeb.Components.Page

      # import OpenSauceWeb.Components.Modal
      # import OpenSauceWeb.Components.Navigation
    end
  end
end
