defmodule OpenSauceWeb.JobLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Orders
  alias OpenSauceWeb.HtmlHelpers
  alias OpenSauceWeb.Navigation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    member = socket.assigns.current_member

    job =
      Orders.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :garden,
          engagement: [:customer],
          staff_assignments: [:member],
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]
        ]
      )

    {:noreply,
     socket
     |> assign(:job, job)
     |> assign(:page_title, page_title(job))
     |> assign(:materials_cost, materials_cost(job.materials))
     |> Navigation.assign(:jobs, [Navigation.root(:jobs)])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:100px;">
      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={~p"/manage/jobs"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M19 12H5M12 19l-7-7 7-7"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </button>
        </.link>
        <.link navigate={~p"/manage/jobs/#{@job.id}/edit"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="1" fill="currentColor" />
              <circle cx="19" cy="12" r="1" fill="currentColor" />
              <circle cx="5" cy="12" r="1" fill="currentColor" />
            </svg>
          </button>
        </.link>
      </div>

      <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:14px;">
        <%!-- job hero card --%>
        <div style="background:#211E16;border-radius:14px;border:1px solid rgba(52,48,37,0.58);padding:16px;">
          <%!-- name + status pill --%>
          <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
            <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;line-height:1.2;margin:0;min-width:0;flex:1;">
              {job_who(@job)}
            </h1>
            <span :if={@job.status == :in_progress} class="pill live" style="flex-shrink:0;">
              <span class="dot pulse"></span>On site
            </span>
            <span :if={@job.status == :scheduling} class="pill cancel" style="flex-shrink:0;">
              Place
            </span>
            <span :if={@job.status == :scheduled} class="pill sched" style="flex-shrink:0;">
              <span class="dot"></span>Scheduled
            </span>
            <span :if={@job.status == :completed} class="pill done" style="flex-shrink:0;">
              Done
            </span>
            <span :if={@job.status == :cancelled} class="pill cancel" style="flex-shrink:0;">
              Cancelled
            </span>
          </div>

          <%!-- garden location --%>
          <div
            :if={job_where_text(@job)}
            style="margin-top:6px;font-size:12.5px;color:#9A9384;display:flex;align-items:center;gap:5px;"
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style="flex:0 0 auto;">
              <path
                d="M12 21s7-5.5 7-11a7 7 0 1 0-14 0c0 5.5 7 11 7 11Z"
                stroke="#9A9384"
                stroke-width="1.6"
              />
              <circle cx="12" cy="10" r="2.4" stroke="#9A9384" stroke-width="1.6" />
            </svg>
            {job_where_text(@job)}
          </div>

          <%!-- engagement scope title --%>
          <div
            :if={@job.engagement && @job.engagement.scope_title}
            style="margin-top:10px;font-size:13px;font-weight:600;color:#9A9384;"
          >
            {@job.engagement.scope_title}
          </div>

          <%!-- service category + date --%>
          <div style="margin-top:10px;display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
            <span :if={@job.service_category} class="jcat">
              <span
                class="catdot"
                style={"background:#{category_color(@job.service_category)}"}
              >
              </span>
              {service_category_label(@job.service_category)}
            </span>
            <span :if={@job.scheduled_for} style="font-size:12.5px;color:#9A9384;">
              {Calendar.strftime(@job.scheduled_for, "%A %-d %B")}
              <span :if={@job.duration_estimate} style="color:#6E675A;">
                · {fmt_dur(@job.duration_estimate)}
              </span>
            </span>
          </div>

          <%!-- crew --%>
          <div
            :if={@job.staff_assignments != [] && @job.staff_assignments != nil}
            style="margin-top:10px;display:flex;gap:5px;align-items:center;"
          >
            <div
              :for={sa <- Enum.take(@job.staff_assignments, 6)}
              class="av"
              style={"background:#{crew_color(sa.member_id)}"}
            >
              {crew_initial(sa.member)}
            </div>
            <span :if={length(@job.staff_assignments) > 6} style="font-size:11px;color:#6E675A;">
              +{length(@job.staff_assignments) - 6}
            </span>
          </div>
        </div>

        <%!-- engagement scope description --%>
        <div
          :if={@job.engagement && @job.engagement.scope_description}
          style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px 14px;"
        >
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">
            Scope
          </p>
          <p style="font-size:13px;color:#F4EFE2;line-height:1.55;">
            {@job.engagement.scope_description}
          </p>
        </div>

        <%!-- stat boxes --%>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;">
          <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;">
            <p style="font-size:18px;font-weight:700;color:#F4EFE2;line-height:1.1;">—</p>
            <p style="font-size:10px;color:#6E675A;margin-top:3px;">supplies</p>
          </div>
          <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;">
            <p style="font-size:18px;font-weight:700;color:#F4EFE2;line-height:1.1;">—</p>
            <p style="font-size:10px;color:#6E675A;margin-top:3px;">plants</p>
          </div>
          <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;">
            <p style="font-size:18px;font-weight:700;color:#F4EFE2;line-height:1.1;">—</p>
            <p style="font-size:10px;color:#6E675A;margin-top:3px;">staff</p>
          </div>
        </div>

        <%!-- materials --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Materials</span>
            <.link navigate={~p"/manage/jobs/#{@job.id}/materials"}>
              <span style="font-size:12px;font-weight:700;color:#54B57E;">edit list</span>
            </.link>
          </div>
          <div
            :if={@job.materials == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;"
          >
            No materials yet
          </div>
          <.link :if={@job.materials != []} navigate={~p"/manage/jobs/#{@job.id}/materials"}>
            <div class="jcard" style="display:flex;align-items:center;justify-content:space-between;">
              <div>
                <p style="font-size:14px;font-weight:600;color:#F4EFE2;">
                  {length(@job.materials)} {if length(@job.materials) == 1,
                    do: "line item",
                    else: "line items"}
                </p>
                <p style="font-size:12px;color:#9A9384;margin-top:2px;">
                  est {HtmlHelpers.format_currency(@organisation.currency, @materials_cost)}
                </p>
              </div>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path
                  d="M9 18l6-6-6-6"
                  stroke="#6E675A"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp page_title(%{service_category: cat}) when not is_nil(cat), do: Phoenix.Naming.humanize(cat)

  defp page_title(%{type: :shift}), do: "Shift"
  defp page_title(_), do: "Job"

  defp job_who(%{engagement: %{customer: c}} = job) when not is_nil(c) do
    cond do
      c.company_name_nickname -> c.company_name_nickname
      c.first_name || c.last_name -> String.trim("#{c.first_name} #{c.last_name}")
      true -> garden_name(job)
    end
  end

  defp job_who(job), do: garden_name(job)

  defp garden_name(%{garden: %{name: n}}) when is_binary(n) and n != "", do: n
  defp garden_name(_), do: "Unnamed job"

  defp job_where_text(%{garden: nil}), do: nil

  defp job_where_text(%{garden: g}) do
    parts = [g.name, g.zip] |> Enum.reject(&is_nil/1) |> Enum.reject(&(&1 == ""))
    if parts == [], do: nil, else: Enum.join(parts, " · ")
  end

  defp crew_initial(%{display_title: dt}) when is_binary(dt) and dt != "" do
    dt |> String.trim() |> String.first() |> String.upcase()
  end

  defp crew_initial(_), do: "?"

  defp crew_color(member_id) do
    colors = ["#6BCB93", "#DB9258", "#5AB4D8", "#A87EDB", "#E87E7E"]
    Enum.at(colors, :erlang.phash2(member_id, length(colors)))
  end

  defp category_color(:installation), do: "#DB9258"
  defp category_color(:delivery), do: "#DB9258"
  defp category_color(:consultation), do: "#5AB4D8"
  defp category_color(:design), do: "#5AB4D8"
  defp category_color(_), do: "#54B57E"

  defp service_category_label(nil), do: "—"
  defp service_category_label(:installation), do: "Installation"
  defp service_category_label(:delivery), do: "Delivery"
  defp service_category_label(:pruning), do: "Pruning"
  defp service_category_label(:consultation), do: "Consultation"
  defp service_category_label(:design), do: "Design"
  defp service_category_label(:opening), do: "Opening"
  defp service_category_label(:winterization), do: "Winterization"
  defp service_category_label(:maintenance), do: "Maintenance"
  defp service_category_label(other), do: to_string(other)

  defp fmt_dur(minutes) when minutes < 60, do: "#{minutes}m"

  defp fmt_dur(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    if m == 0, do: "#{h}h", else: "#{h}h #{m}m"
  end

  defp materials_cost(materials) do
    Enum.reduce(materials, Decimal.new(0), fn jm, acc ->
      unit = jm.supplier_catalog_item.unit_price || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(jm.quantity, unit))
    end)
  end
end
