defmodule OpenSauceWeb.PageController do
  use OpenSauceWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/manage/jobs")
    else
      redirect(conn, to: ~p"/sign-in")
    end
  end
end
