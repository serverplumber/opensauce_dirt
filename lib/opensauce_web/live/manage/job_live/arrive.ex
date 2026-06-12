defmodule OpenSauceWeb.JobLive.Arrive do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Orders
  alias OpenSauceWeb.Navigation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:odometer, "")
     |> assign(:note, "")
     |> assign(:arrived_at, DateTime.utc_now())}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    member = socket.assigns.current_member

    job =
      Orders.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer], staff_assignments: [member: [:user]]]
      )

    {:noreply,
     socket
     |> assign(:job, job)
     |> assign(:note, (job.garden && job.garden.notes) || "")
     |> assign(:page_title, "Arrived")
     |> Navigation.assign(:jobs, [Navigation.root(:jobs)])}
  end

  @impl true
  def handle_event("update_fields", params, socket) do
    {:noreply,
     socket
     |> assign(:odometer, params["odometer"] || socket.assigns.odometer)
     |> assign(:note, params["note"] || socket.assigns.note)}
  end

  @impl true
  def handle_event("start_working", _params, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.job
    opts = [actor: member, tenant: member.organisation_id]
    now = socket.assigns.arrived_at

    odometer_km =
      case Integer.parse(socket.assigns.odometer) do
        {n, _} -> n
        :error -> nil
      end

    event =
      Orders.log_job_event!(
        %{
          job_id: job.id,
          timestamp: now,
          data: %{type: :arrival, odometer_km: odometer_km},
          organisation_id: member.organisation_id
        },
        opts
      )

    Enum.each(job.staff_assignments, fn sa ->
      Orders.log_job_event_staff(
        %{
          job_event_id: event.id,
          member_id: sa.member_id,
          man_hour_rate: sa.member.labor_hourly_rate,
          organisation_id: member.organisation_id
        },
        opts
      )
    end)

    if job.status in [:scheduling, :scheduled] do
      Orders.mark_job_in_progress(job, opts)
    end

    note = socket.assigns.note

    if job.garden && note != (job.garden.notes || "") do
      CRM.update_address!(job.garden, %{notes: note}, opts)
    end

    {:noreply, push_navigate(socket, to: ~p"/manage/jobs/#{job.id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:130px;">
      <%!-- top bar --%>
      <div style="display:flex;align-items:flex-start;justify-content:space-between;padding:14px 16px 0;">
        <div>
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0;line-height:1.1;">
            Arrived
          </h1>
          <p style="font-size:11px;color:#6E675A;margin-top:3px;">
            auto-logged at {Calendar.strftime(@arrived_at, "%H:%M")} · {garden_label(@job)}
          </p>
        </div>
        <.link navigate={~p"/manage/jobs/#{@job.id}"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:6px;cursor:pointer;line-height:0;margin-top:2px;"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path
                d="M18 6L6 18M6 6l12 12"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
            </svg>
          </button>
        </.link>
      </div>

      <form
        phx-change="update_fields"
        style="padding:16px 16px 0;display:flex;flex-direction:column;gap:14px;"
      >
        <%!-- job context --%>
        <div>
          <p style="font-size:17px;font-weight:700;color:#F4EFE2;line-height:1.25;">
            {job_site_name(@job)}
          </p>
          <p style="font-size:12px;color:#9A9384;margin-top:3px;">{job_context_line(@job)}</p>
        </div>

        <%!-- odometer --%>
        <div style="background:#211E16;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);padding:14px;">
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Odometer on arrival
          </p>
          <div style="display:flex;align-items:baseline;gap:8px;">
            <input
              type="number"
              name="odometer"
              value={@odometer}
              placeholder="—"
              min="0"
              step="1"
              style="background:none;border:none;outline:none;font-size:34px;font-weight:700;color:#F4EFE2;width:100%;max-width:180px;font-family:'Bricolage Grotesque',sans-serif;letter-spacing:-0.02em;"
            />
            <span style="font-size:14px;color:#9A9384;">km</span>
          </div>
          <p style="font-size:11px;color:#6E675A;margin-top:4px;">tap to edit</p>
        </div>

        <%!-- staff card (placeholder) --%>
        <div>
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Staff
          </p>
          <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px 14px;">
            <div
              :if={@job.staff_assignments && @job.staff_assignments != []}
              style="display:flex;flex-direction:column;gap:10px;"
            >
              <div
                :for={sa <- @job.staff_assignments}
                style="display:flex;align-items:center;gap:10px;"
              >
                <div class="av" style={"background:#{crew_color(sa.member_id)}"}>
                  {crew_initial(sa.member)}
                </div>
                <span style="font-size:13px;font-weight:600;color:#F4EFE2;">
                  {member_name(sa.member)}
                </span>
              </div>
            </div>
            <p
              :if={!@job.staff_assignments || @job.staff_assignments == []}
              style="font-size:13px;color:#6E675A;"
            >
              No crew assigned
            </p>
            <p style="font-size:11px;color:#6E675A;margin-top:10px;padding-top:10px;border-top:1px solid rgba(52,48,37,0.58);">
              Staff check-in coming soon
            </p>
          </div>
        </div>

        <%!-- note from garden --%>
        <div>
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Note — gate code, where to park…
          </p>
          <textarea
            name="note"
            class="dark-textarea"
            rows="4"
            placeholder="Access notes for this site…"
            phx-debounce="blur"
          >{@note}</textarea>
        </div>
      </form>

      <%!-- sticky CTAs --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;display:flex;gap:10px;z-index:10;">
        <.link navigate={~p"/manage/jobs/#{@job.id}"} style="flex:1;display:block;">
          <button
            type="button"
            ontouchstart=""
            style="width:100%;height:56px;border-radius:14px;background:#211E16;border:1px solid rgba(52,48,37,0.58);color:#9A9384;font-size:15px;font-weight:700;cursor:pointer;"
          >
            ← back
          </button>
        </.link>
        <div style="flex:2;">
          <.glow_button phx-click="start_working" valid={true}>
            Start working →
          </.glow_button>
        </div>
      </div>
    </div>
    """
  end

  defp garden_label(%{garden: %{name: n}}) when is_binary(n) and n != "", do: n
  defp garden_label(_), do: "No site"

  defp job_site_name(%{garden: %{name: n}}) when is_binary(n) and n != "", do: n

  defp job_site_name(%{engagement: %{customer: c}}) when not is_nil(c) do
    c.company_name_nickname || String.trim("#{c.first_name} #{c.last_name}")
  end

  defp job_site_name(_), do: "Job"

  defp job_context_line(job) do
    parts =
      Enum.reject(
        [
          job.service_category && Phoenix.Naming.humanize(job.service_category),
          job.scheduled_for && Calendar.strftime(job.scheduled_for, "%a %-d %b"),
          job.duration_estimate && fmt_dur(job.duration_estimate)
        ],
        &is_nil/1
      )

    Enum.join(parts, " · ")
  end

  defp staff_name(%{user: %{email: e}}) when is_binary(e), do: e |> String.split("@") |> hd()
  defp staff_name(_), do: "?"

  defp crew_initial(member) do
    n = staff_name(member)
    if n == "?", do: "?", else: n |> String.first() |> String.upcase()
  end

  defp crew_color(member_id) do
    colors = ["#6BCB93", "#DB9258", "#5AB4D8", "#A87EDB", "#E87E7E"]
    Enum.at(colors, :erlang.phash2(member_id, length(colors)))
  end

  defp member_name(member), do: staff_name(member)

  defp fmt_dur(minutes) when minutes < 60, do: "#{minutes}m"

  defp fmt_dur(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    if m == 0, do: "#{h}h", else: "#{h}h #{m}m"
  end
end
