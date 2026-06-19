# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.LiveNav do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    if socket.router == nil do
      {:cont, assign(socket, :nav_section, nil)}
    else
      {:cont, attach_hook(socket, :assign_nav_section, :handle_params, &assign_nav_section/3)}
    end
  end

  defp assign_nav_section(_params, url, socket) do
    path = URI.parse(url).path || ""

    section =
      cond do
        String.starts_with?(path, "/manage/overview") -> :overview
        String.starts_with?(path, "/manage/production") -> :production
        String.starts_with?(path, "/manage/inventory") -> :inventory
        String.starts_with?(path, "/manage/purchasing") -> :purchasing
        String.starts_with?(path, "/manage/products") -> :products
        String.starts_with?(path, "/manage/jobs") -> :jobs
        String.starts_with?(path, "/manage/orders") -> :orders
        String.starts_with?(path, "/manage/shifts") -> :shifts
        String.starts_with?(path, "/manage/schedule") -> :schedule
        String.starts_with?(path, "/manage/engagements") -> :customers
        String.starts_with?(path, "/manage/customers") -> :customers
        String.starts_with?(path, "/manage/venues") -> :venues
        String.starts_with?(path, "/manage/settings") -> :settings
        true -> nil
      end

    {:cont, assign(socket, :nav_section, section)}
  end
end
