# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.CalendarController do
  use OpenSauceWeb, :controller

  alias OpenSauce.Calendar.FeedGenerator

  def feed(conn, _params) do
    actor = conn.assigns[:current_user]
    ics = FeedGenerator.generate(actor)

    conn
    |> put_resp_content_type("text/calendar")
    |> put_resp_header("content-disposition", ~s(inline; filename="craftplan.ics"))
    |> send_resp(200, ics)
  end
end
