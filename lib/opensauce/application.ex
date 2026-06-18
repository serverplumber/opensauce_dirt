# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OpenSauce.Vault,
      OpenSauce.Repo,
      {DNSCluster, query: Application.get_env(:opensauce, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OpenSauce.PubSub},
      {Finch, name: OpenSauce.Finch},
      OpenSauceWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :opensauce]}
    ]

    opts = [strategy: :one_for_one, name: OpenSauce.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OpenSauceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
