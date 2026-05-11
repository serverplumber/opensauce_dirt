defmodule OpenSauce.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OpenSauceWeb.Telemetry,
      OpenSauce.Vault,
      OpenSauce.Repo,
      {DNSCluster, query: Application.get_env(:opensauce, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OpenSauce.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: OpenSauce.Finch},
      # Start a worker by calling: OpenSauce.Worker.start_link(arg)
      # {OpenSauce.Worker, arg},
      # Start to serve requests, typically the last entry
      OpenSauceWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :opensauce]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpenSauce.Supervisor]
    result = Supervisor.start_link(children, opts)

    apply_smtp_from_settings()

    result
  end

  defp apply_smtp_from_settings do
    # Settings are now per-organisation — no single row to load at startup.
    :ok
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OpenSauceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
