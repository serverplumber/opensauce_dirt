defmodule OpenSauceWeb.PageController do
  use OpenSauceWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/manage/production/schedule")
    else
      if admin_exists?() do
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
      else
        redirect(conn, to: ~p"/setup")
      end
    end
  end

  defp admin_exists? do
    case OpenSauce.Accounts.list_organisations(authorize?: false) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
