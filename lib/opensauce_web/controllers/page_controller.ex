defmodule OpenSauceWeb.PageController do
  use OpenSauceWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/manage/jobs")
    else
      release_version =
        case Application.spec(:opensauce, :vsn) do
          nil -> "dev"
          version -> to_string(version)
        end

      conn
      |> assign(:current_path, "/")
      |> assign(:page_title, "OpenSauce")
      |> put_layout(false)
      |> render(:home, release_version: release_version)
    end
  end
end
