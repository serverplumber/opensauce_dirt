defmodule OpenSauceWeb.ShiftLive.Summary do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts
  alias OpenSauce.Orders

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member
    active_shift = socket.assigns.active_shift

    if is_nil(active_shift) do
      {:ok, push_navigate(socket, to: ~p"/manage/today")}
    else
      shift =
        Orders.get_job_by_id!(active_shift.id,
          actor: member,
          tenant: member.organisation_id,
          load: [:events, :staff_assignments]
        )

      org_members =
        Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)
        |> Enum.reject(&(&1.status == :suspended))

      today_jobs =
        Orders.list_jobs!(
          actor: member,
          tenant: member.organisation_id,
          load: [:garden, engagement: [:customer]]
        )
        |> Enum.filter(fn j ->
          j.type == :client_work &&
            j.status in [:scheduled, :in_progress, :completed] &&
            j.scheduled_for == Date.utc_today()
        end)
        |> Enum.sort_by(fn j ->
          case j.start_time do
            nil -> {1, 0}
            t -> {0, t.hour * 60 + t.minute}
          end
        end)

      started_at = shift_started_at(shift)

      {:ok,
       socket
       |> assign(
         page_title: "Shift",
         main_bg: "bg-[#16140E]",
         shift: shift,
         org_members: org_members,
         today_jobs: today_jobs,
         started_at: started_at,
         staff_sheet_open: false,
         pending_action: nil
       )}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_staff_sheet", _params, socket) do
    {:noreply, assign(socket, staff_sheet_open: true)}
  end

  @impl true
  def handle_event("close_staff_sheet", _params, socket) do
    {:noreply, assign(socket, staff_sheet_open: false)}
  end

  @impl true
  def handle_event("request_add", %{"id" => member_id}, socket) do
    m = Enum.find(socket.assigns.org_members, &(&1.id == member_id))
    {:noreply, assign(socket, staff_sheet_open: false, pending_action: {:add, m})}
  end

  @impl true
  def handle_event("request_remove", %{"assignment_id" => sa_id, "member_id" => member_id}, socket) do
    m = Enum.find(socket.assigns.org_members, &(&1.id == member_id))
    {:noreply, assign(socket, staff_sheet_open: false, pending_action: {:remove, m, sa_id})}
  end

  @impl true
  def handle_event("request_end_shift", _params, socket) do
    {:noreply, assign(socket, pending_action: {:end_shift})}
  end

  @impl true
  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, pending_action: nil)}
  end

  @impl true
  def handle_event("confirm_action", _params, socket) do
    actor = socket.assigns.current_member
    shift = socket.assigns.shift
    now = DateTime.truncate(DateTime.utc_now(), :second)
    opts = [actor: actor, tenant: actor.organisation_id]

    case socket.assigns.pending_action do
      {:add, m} ->
        event =
          Orders.log_job_event!(
            %{
              job_id: shift.id,
              timestamp: now,
              data: %{type: :work_session_start},
              organisation_id: actor.organisation_id
            },
            opts
          )

        Orders.log_job_event_staff(
          %{
            job_event_id: event.id,
            member_id: m.id,
            man_hour_rate: m.labor_hourly_rate,
            organisation_id: actor.organisation_id
          },
          opts
        )

        Orders.assign_job_staff(
          %{job_id: shift.id, member_id: m.id, organisation_id: actor.organisation_id},
          opts
        )

      {:remove, m, sa_id} ->
        event =
          Orders.log_job_event!(
            %{
              job_id: shift.id,
              timestamp: now,
              data: %{type: :work_session_stop},
              organisation_id: actor.organisation_id
            },
            opts
          )

        Orders.log_job_event_staff(
          %{
            job_event_id: event.id,
            member_id: m.id,
            man_hour_rate: m.labor_hourly_rate,
            organisation_id: actor.organisation_id
          },
          opts
        )

        sa = Enum.find(shift.staff_assignments, &(&1.id == sa_id))
        if sa, do: Orders.unassign_job_staff(sa, opts)

      {:end_shift} ->
        Orders.log_job_event!(
          %{
            job_id: shift.id,
            timestamp: now,
            data: %{type: :shift_end},
            organisation_id: actor.organisation_id
          },
          opts
        )

        Orders.complete_job(shift, opts)
    end

    case socket.assigns.pending_action do
      {:end_shift} ->
        {:noreply, push_navigate(socket, to: ~p"/manage/today")}

      _ ->
        {:noreply, socket |> assign(pending_action: nil) |> reload_shift()}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:110px;">
      <%!-- Header --%>
      <div style="padding:14px 16px 10px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0 0 3px;">
          Shift
        </h1>
        <p :if={@started_at} style="font-size:12px;color:#6E675A;margin:0;">
          started {Calendar.strftime(@started_at, "%H:%M")} · {shift_duration(@started_at)}
        </p>
        <p :if={is_nil(@started_at)} style="font-size:12px;color:#6E675A;margin:0;">
          shift in progress
        </p>
      </div>

      <%!-- Stats --%>
      <div style="padding:0 16px 14px;display:flex;gap:10px;">
        <.shift_stat value={to_string(length(@today_jobs))} label="jobs today" />
        <.shift_stat value={jobs_done_count(@today_jobs)} label="done" />
        <.shift_stat value={if @started_at, do: shift_duration(@started_at), else: "—"} label="on shift" />
      </div>

      <%!-- Today's stops --%>
      <div style="padding:0 16px;">
        <div style="display:flex;align-items:center;gap:10px;padding:6px 2px 10px;">
          <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
            Today's stops
          </span>
          <div style="flex:1;height:1px;background:rgba(52,48,37,0.58);"></div>
        </div>

        <div
          :if={@today_jobs == []}
          style="text-align:center;color:#6E675A;font-size:13px;font-weight:500;padding:20px 0;"
        >
          No jobs scheduled today
        </div>

        <.stop_card :for={job <- @today_jobs} job={job} />
      </div>

      <%!-- Crew card (manager / owner only) --%>
      <div :if={@current_member.role in [:manager, :owner]} style="padding:16px 16px 0;">
        <div style="display:flex;align-items:center;gap:10px;padding:6px 2px 10px;">
          <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
            Crew
          </span>
          <div style="flex:1;height:1px;background:rgba(52,48,37,0.58);"></div>
        </div>

        <div
          phx-click="open_staff_sheet"
          ontouchstart=""
          style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:16px;padding:13px 14px;box-shadow:0 1px 2px rgba(0,0,0,0.4),0 12px 30px rgba(0,0,0,0.45);cursor:pointer;transition:transform .12s ease,border-color .12s ease;"
        >
          <div :if={@shift.staff_assignments == []} style="font-size:13px;color:#6E675A;">
            No crew yet — tap to add
          </div>

          <div :if={@shift.staff_assignments != []} style="display:flex;flex-wrap:wrap;gap:8px;">
            <% assigned_ids = MapSet.new(@shift.staff_assignments, & &1.member_id) %>
            <div
              :for={m <- Enum.filter(@org_members, &MapSet.member?(assigned_ids, &1.id))}
              style={"width:36px;height:36px;border-radius:10px;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:14px;color:#fff;#{member_gradient(m.role)}"}
            >
              {member_initial(m)}
            </div>
          </div>
        </div>
      </div>

      <%!-- Stop FAB --%>
      <button
        :if={!@staff_sheet_open && is_nil(@pending_action)}
        class="fab"
        type="button"
        phx-click="request_end_shift"
        ontouchstart=""
        title="End shift"
        style="background:#DB9258;box-shadow:0 6px 20px rgba(219,146,88,0.32);"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="#1A0F05">
          <rect x="5" y="5" width="14" height="14" rx="2" />
        </svg>
      </button>

      <%!-- Confirmation sheet --%>
      <div
        :if={@pending_action}
        class="fixed inset-0 z-[70] flex flex-col justify-end"
        role="dialog"
        aria-label="Confirm"
      >
        <div class="absolute inset-0 bg-black/65" phx-click="cancel_confirm" aria-hidden="true" />
        <div
          class="relative w-full bg-[#211E16]"
          style="border-radius:20px 20px 0 0;border-top:1.5px solid rgba(52,48,37,0.58);padding:20px 16px;padding-bottom:max(2rem,env(safe-area-inset-bottom));"
        >
          <% {action_type, cm} =
            case @pending_action do
              {:add, m} -> {:add, m}
              {:remove, m, _} -> {:remove, m}
              {:end_shift} -> {:end_shift, nil}
            end %>
          <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 20px;"></div>
          <div style="display:flex;flex-direction:column;align-items:center;gap:12px;margin-bottom:24px;">
            <div
              :if={cm}
              style={"width:48px;height:48px;border-radius:13px;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:18px;color:#fff;#{if cm, do: member_gradient(cm.role), else: ""}"}
            >
              {if cm, do: member_initial(cm)}
            </div>
            <div :if={action_type == :end_shift} style="width:48px;height:48px;border-radius:13px;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#DB9258,#7A4A1E);">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="#1A0F05">
                <rect x="5" y="5" width="14" height="14" rx="2" />
              </svg>
            </div>
            <div style="text-align:center;">
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:18px;font-weight:700;color:#F4EFE2;margin:0 0 4px;">
                {case action_type do
                  :add -> "Log #{member_display_name(cm)} arriving?"
                  :remove -> "Log #{member_display_name(cm)} leaving?"
                  :end_shift -> "End the shift?"
                end}
              </p>
              <p style="font-size:13px;color:#9A9384;margin:0;">This will be recorded as of now.</p>
            </div>
          </div>
          <button
            type="button"
            phx-click="confirm_action"
            ontouchstart=""
            style={
              case action_type do
                :add ->
                  "width:100%;padding:14px;border-radius:12px;border:none;font-family:'Hanken Grotesk',sans-serif;font-weight:700;font-size:15px;cursor:pointer;background:#54B57E;color:#0D2419;margin-bottom:10px;"

                :remove ->
                  "width:100%;padding:14px;border-radius:12px;border:none;font-family:'Hanken Grotesk',sans-serif;font-weight:700;font-size:15px;cursor:pointer;background:#E87E7E;color:#2A0D0D;margin-bottom:10px;"

                :end_shift ->
                  "width:100%;padding:14px;border-radius:12px;border:none;font-family:'Hanken Grotesk',sans-serif;font-weight:700;font-size:15px;cursor:pointer;background:#DB9258;color:#1A0F05;margin-bottom:10px;"
              end
            }
          >
            {case action_type do
              :add -> "Confirm arrival"
              :remove -> "Confirm departure"
              :end_shift -> "End shift"
            end}
          </button>
          <button
            type="button"
            phx-click="cancel_confirm"
            ontouchstart=""
            style="width:100%;padding:14px;border-radius:12px;background:transparent;border:1.5px dashed rgba(52,48,37,0.8);font-family:'Hanken Grotesk',sans-serif;font-weight:700;font-size:15px;color:#6E675A;cursor:pointer;"
          >
            Cancel
          </button>
        </div>
      </div>

      <%!-- Crew bottom sheet --%>
      <div
        :if={@staff_sheet_open}
        class="fixed inset-0 z-[60] flex flex-col justify-end"
        role="dialog"
        aria-label="Crew"
      >
        <div
          class="absolute inset-0 bg-black/65"
          phx-click="close_staff_sheet"
          aria-hidden="true"
        />
        <div
          class="relative w-full bg-[#211E16] mobile-scroll"
          style="border-radius:20px 20px 0 0;border-top:1.5px solid rgba(52,48,37,0.58);max-height:82vh;overflow-y:auto;padding-bottom:max(2rem,env(safe-area-inset-bottom));"
        >
          <%!-- Handle + header --%>
          <div style="padding:12px 16px 10px;border-bottom:1px solid rgba(52,48,37,0.58);position:sticky;top:0;background:#211E16;z-index:1;">
            <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 12px;"></div>
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <span style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;">
                Crew
              </span>
              <button
                type="button"
                phx-click="close_staff_sheet"
                ontouchstart=""
                style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
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
            </div>
          </div>

          <%!-- Member list --%>
          <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:8px;">
            <div
              :for={m <- @org_members}
              style={"background:#2B2820;border-radius:12px;padding:10px 12px;border:1px solid rgba(52,48,37,0.58);display:flex;align-items:center;gap:10px;"}
            >
              <%!-- Avatar --%>
              <div style={"width:36px;height:36px;border-radius:10px;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:14px;color:#fff;#{member_gradient(m.role)}"}>
                {member_initial(m)}
              </div>
              <%!-- Name + role --%>
              <div style="flex:1;min-width:0;">
                <p style="font-size:13px;font-weight:600;color:#F4EFE2;margin:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {member_display_name(m)}
                </p>
                <p style="font-size:11px;color:#6E675A;margin:2px 0 0;">
                  {if m.display_title, do: m.display_title, else: role_label(m.role)}
                </p>
              </div>
              <%!-- Add / remove toggle --%>
              <% assignment = Enum.find(@shift.staff_assignments, &(&1.member_id == m.id)) %>
              <button
                :if={assignment}
                type="button"
                phx-click="request_remove"
                phx-value-assignment_id={assignment.id}
                phx-value-member_id={m.id}
                ontouchstart=""
                style="background:rgba(232,126,126,0.12);border:1px solid rgba(232,126,126,0.25);border-radius:8px;color:#E87E7E;padding:6px 10px;cursor:pointer;font-size:12px;font-weight:700;line-height:1;flex-shrink:0;"
              >
                Remove
              </button>
              <button
                :if={is_nil(assignment)}
                type="button"
                phx-click="request_add"
                phx-value-id={m.id}
                ontouchstart=""
                style="background:rgba(84,181,126,0.12);border:1px solid rgba(84,181,126,0.25);border-radius:8px;color:#54B57E;padding:6px 10px;cursor:pointer;font-size:12px;font-weight:700;line-height:1;flex-shrink:0;"
              >
                Add
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, required: true

  defp shift_stat(assigns) do
    ~H"""
    <div style="flex:1;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:12px 10px;text-align:center;">
      <div style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;line-height:1.1;">
        {@value}
      </div>
      <div style="font-size:10.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-top:3px;">
        {@label}
      </div>
    </div>
    """
  end

  attr :job, :any, required: true

  defp stop_card(assigns) do
    ~H"""
    <div
      class="jcard"
      style="margin-bottom:8px;"
      phx-click={JS.navigate(~p"/manage/jobs/#{@job.id}?return_to=/manage/shifts/current")}
      ontouchstart=""
    >
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
        <div style="min-width:0;flex:1;">
          <div style="font-size:15px;font-weight:700;letter-spacing:-0.01em;line-height:1.25;color:#F4EFE2;">
            {job_name(@job)}
          </div>
          <div
            :if={job_where(@job)}
            style="margin-top:3px;font-size:12px;color:#9A9384;"
          >
            {job_where(@job)}
          </div>
        </div>
        <span style={"font-size:11px;font-weight:700;padding:3px 8px;border-radius:999px;flex-shrink:0;#{status_pill_style(@job.status)}"}>
          {status_label(@job.status)}
        </span>
      </div>
      <div :if={@job.service_category || @job.start_time} style="margin-top:9px;display:flex;align-items:center;gap:6px;">
        <span
          :if={@job.start_time}
          style="font-size:11px;font-weight:700;color:#6E675A;background:#16140E;border:1px solid rgba(52,48,37,0.5);border-radius:6px;padding:2px 6px;flex-shrink:0;"
        >
          {Calendar.strftime(@job.start_time, "%H:%M")}
        </span>
        <span :if={@job.service_category} class="jcat">
          {service_category_label(@job.service_category)}
        </span>
      </div>
    </div>
    """
  end

  defp reload_shift(socket) do
    member = socket.assigns.current_member

    shift =
      Orders.get_job_by_id!(socket.assigns.shift.id,
        actor: member,
        tenant: member.organisation_id,
        load: [:events, :staff_assignments]
      )

    assign(socket, shift: shift)
  end

  defp shift_started_at(%{events: events}) when is_list(events) do
    events
    |> Enum.find(fn e ->
      case e.data do
        %{type: :shift_start} -> true
        _ -> false
      end
    end)
    |> case do
      nil -> nil
      event -> event.timestamp
    end
  end

  defp shift_started_at(_), do: nil

  defp shift_duration(started_at) do
    seconds = DateTime.diff(DateTime.utc_now(), started_at)
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)

    cond do
      h > 0 and m > 0 -> "#{h}h #{m}m"
      h > 0 -> "#{h}h"
      true -> "#{m}m"
    end
  end

  defp jobs_done_count(jobs) do
    jobs |> Enum.count(&(&1.status == :completed)) |> to_string()
  end

  defp job_name(%{engagement: %{customer: %{company_name_nickname: nick}}}) when is_binary(nick), do: nick
  defp job_name(%{engagement: %{customer: %{first_name: f, last_name: l}}}), do: "#{f} #{l}"
  defp job_name(%{garden: %{name: name}}) when is_binary(name) and name != "", do: name
  defp job_name(_), do: "Job"

  defp job_where(%{garden: %{name: n, zip: z}}) do
    [n, z] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(" · ") |> then(&if &1 == "", do: nil, else: &1)
  end

  defp job_where(_), do: nil

  defp status_label(:scheduled), do: "Sched"
  defp status_label(:in_progress), do: "On site"
  defp status_label(:completed), do: "Done"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(other), do: to_string(other)

  defp status_pill_style(:in_progress), do: "background:rgba(84,181,126,0.14);color:#54B57E;"
  defp status_pill_style(:completed), do: "background:rgba(90,180,216,0.14);color:#5AB4D8;"
  defp status_pill_style(:cancelled), do: "background:rgba(232,126,126,0.14);color:#E87E7E;"
  defp status_pill_style(_), do: "background:rgba(110,103,90,0.14);color:#6E675A;"

  defp service_category_label(:installation), do: "Installation"
  defp service_category_label(:delivery), do: "Delivery"
  defp service_category_label(:pruning), do: "Pruning"
  defp service_category_label(:consultation), do: "Consultation"
  defp service_category_label(:design), do: "Design"
  defp service_category_label(:opening), do: "Opening"
  defp service_category_label(:winterization), do: "Winterization"
  defp service_category_label(:maintenance), do: "Maintenance"
  defp service_category_label(other), do: to_string(other)

  defp crew_color(member_id) do
    colors = ["#6BCB93", "#DB9258", "#5AB4D8", "#A87EDB", "#E87E7E"]
    Enum.at(colors, :erlang.phash2(member_id, length(colors)))
  end

  defp crew_initial(member) do
    n = staff_name(member)
    if n == "?", do: "?", else: n |> String.first() |> String.upcase()
  end

  defp staff_name(%{user: %{first_name: f}}) when is_binary(f) and f != "", do: f
  defp staff_name(%{user: %{email: e}}), do: e |> to_string() |> String.split("@") |> hd()
  defp staff_name(_), do: "?"

  defp member_display_name(%{user: %{first_name: f, last_name: l, email: email}}) do
    cond do
      f && l -> "#{f} #{l}"
      f -> f
      true -> to_string(email)
    end
  end

  defp member_display_name(%{user: %{email: email}}), do: to_string(email)
  defp member_display_name(_), do: "—"

  defp member_initial(%{user: %{first_name: f}}) when is_binary(f) and f != "",
    do: f |> String.first() |> String.upcase()

  defp member_initial(%{user: %{email: email}}),
    do: email |> to_string() |> String.split("@") |> hd() |> String.first() |> String.upcase()

  defp member_initial(_), do: "?"

  defp member_gradient(:owner), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp member_gradient(:manager), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp member_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"

  defp role_label(:owner), do: "Owner"
  defp role_label(:manager), do: "Manager"
  defp role_label(_), do: "Field crew"
end
