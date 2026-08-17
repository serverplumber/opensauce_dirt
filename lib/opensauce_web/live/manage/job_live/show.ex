defmodule OpenSauceWeb.JobLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts
  alias OpenSauce.Work
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:show_staff_sheet, false)
     |> assign(:show_delete_confirm, false)
     |> assign(:org_members, [])
     |> assign(:active_shift, nil)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    member = socket.assigns.current_member
    return_to = Map.get(params, "return_to", ~p"/manage/jobs")

    org_members =
      Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)

    active_shift = Work.find_active_shift!(actor: member, tenant: member.organisation_id)

    job =
      Work.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :garden,
          :staff_assignments,
          engagement: [:customer],
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]
        ]
      )

    events =
      if job.status == :in_progress do
        Work.list_job_events!(job.id, actor: member, tenant: member.organisation_id)
      else
        []
      end

    arrival =
      events |> Enum.filter(&match?(%{data: %Ash.Union{type: :arrival}}, &1)) |> List.last()

    {:noreply,
     socket
     |> assign(:org_members, org_members)
     |> assign(:active_shift, active_shift)
     |> assign(:job, job)
     |> assign(:return_to, return_to)
     |> assign(:page_title, page_title(job))
     |> assign(:materials_cost, materials_cost(job.materials))
     |> assign(:arrived_at, arrival && arrival.timestamp)
     |> assign(:arrival_odo, arrival && arrival.data.value.odometer_km)}
  end

  @impl true
  def handle_event("open_staff_sheet", _params, socket) do
    {:noreply, assign(socket, show_staff_sheet: true)}
  end

  @impl true
  def handle_event("close_staff_sheet", _params, socket) do
    {:noreply, assign(socket, show_staff_sheet: false)}
  end

  @impl true
  def handle_event("add_staff", %{"id" => member_id}, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.job

    Work.assign_job_staff(
      %{job_id: job.id, member_id: member_id, organisation_id: member.organisation_id},
      actor: member,
      tenant: member.organisation_id
    )

    {:noreply, socket |> assign(show_staff_sheet: false) |> reload_job()}
  end

  @impl true
  def handle_event("open_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, true)}
  end

  @impl true
  def handle_event("close_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.job
    return_to = socket.assigns.return_to

    Work.destroy_job(job, actor: member, tenant: member.organisation_id)

    {:noreply, push_navigate(socket, to: return_to, replace: true)}
  end

  @impl true
  def handle_event("remove_staff", %{"id" => job_staff_id}, socket) do
    member = socket.assigns.current_member
    sa = Enum.find(socket.assigns.job.staff_assignments, &(&1.id == job_staff_id))
    if sa, do: Work.unassign_job_staff(sa, actor: member, tenant: member.organisation_id)
    {:noreply, reload_job(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style={"font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:#{if @job.status == :in_progress, do: "150px", else: "100px"};"}>
      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={@return_to}>
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
        <div style="display:flex;align-items:center;gap:4px;">
          <button
            :if={@job.status in [:scheduling, :scheduled]}
            type="button"
            phx-click="open_delete_confirm"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M10 11v6M14 11v6"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
              />
            </svg>
          </button>
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
      </div>

      <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:14px;">
        <%!-- job hero card — tappable for :scheduling jobs (start or place) --%>
        <div
          style={"background:#211E16;border-radius:14px;border:1px solid rgba(52,48,37,0.58);padding:16px;#{if @job.status == :scheduling, do: "cursor:pointer;", else: ""}"}
          phx-click={scheduling_hero_click(@job, @active_shift)}
          ontouchstart=""
        >
          <%!-- title + status chip --%>
          <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
            <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;line-height:1.2;margin:0;min-width:0;flex:1;">
              {hero_title(@job)}
            </h1>
            <.job_status_chip
              status={@job.status}
              scheduling_label={if @active_shift, do: "Start", else: "Place"}
            />
          </div>

          <%!-- customer nickname · scope title --%>
          <% subtitle = hero_subtitle(@job) %>
          <div
            :if={subtitle != ""}
            style="margin-top:5px;font-size:13px;color:#9A9384;font-weight:500;"
          >
            {subtitle}
          </div>

          <%!-- long date · duration estimate --%>
          <div :if={@job.scheduled_for} style="margin-top:6px;font-size:12.5px;color:#6E675A;">
            {Calendar.strftime(@job.scheduled_for, "%A %-d %B")}
            <span :if={@job.duration_estimate}>· {fmt_dur(@job.duration_estimate)}</span>
          </div>

          <%!-- crew --%>
          <% assigned_ids = Enum.map(@job.staff_assignments || [], & &1.member_id) %>
          <div
            :if={assigned_ids != []}
            style="margin-top:10px;display:flex;gap:5px;align-items:center;"
          >
            <.member_avatar
              :for={m <- @org_members |> Enum.filter(&(&1.id in assigned_ids)) |> Enum.take(6)}
              member={m}
              size={26}
            />
            <span :if={length(assigned_ids) > 6} style="font-size:11px;color:#6E675A;">
              +{length(assigned_ids) - 6}
            </span>
          </div>
        </div>

        <%!-- B4 on-site hero --%>
        <div
          :if={@job.status == :in_progress}
          style="background:rgba(84,181,126,0.08);border-radius:12px;border:1.5px solid #54B57E;padding:12px 14px;"
        >
          <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;">
            <div style="min-width:0;flex:1;">
              <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#54B57E;">
                On site · {elapsed_label(@arrived_at)}
              </p>
              <p style="font-size:11px;color:#9A9384;margin-top:3px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {arrival_line(@arrived_at, @arrival_odo, @job, @org_members)}
              </p>
            </div>
            <.link navigate={~p"/manage/jobs/#{@job.id}/closeout"}>
              <button
                type="button"
                ontouchstart=""
                style="font-size:13px;font-weight:700;color:#0C1F15;background:#54B57E;border:none;border-radius:8px;padding:6px 14px;cursor:pointer;flex-shrink:0;"
              >
                leave →
              </button>
            </.link>
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

        <%!-- crew --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Crew</span>
            <button
              type="button"
              phx-click="open_staff_sheet"
              ontouchstart=""
              style="color:#54B57E;background:none;border:none;cursor:pointer;padding:4px;line-height:0;"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                <path
                  d="M12 5v14M5 12h14"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                />
              </svg>
            </button>
          </div>
          <div
            :if={@job.staff_assignments == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;"
          >
            No crew assigned
          </div>
          <% member_map = Map.new(@org_members, &{&1.id, &1}) %>
          <div
            :if={@job.staff_assignments != []}
            style="display:flex;flex-direction:column;gap:6px;"
          >
            <div
              :for={sa <- @job.staff_assignments}
              :if={Map.has_key?(member_map, sa.member_id)}
              style="background:#211E16;border-radius:12px;padding:10px 12px;border:1px solid rgba(52,48,37,0.58);display:flex;align-items:center;gap:10px;"
            >
              <.member_card member={member_map[sa.member_id]}>
                <:trailing>
                  <button
                    type="button"
                    phx-click="remove_staff"
                    phx-value-id={sa.id}
                    ontouchstart=""
                    style="background:none;border:none;color:#6E675A;cursor:pointer;padding:4px;line-height:0;"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                      <path
                        d="M18 6L6 18M6 6l12 12"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                      />
                    </svg>
                  </button>
                </:trailing>
              </.member_card>
            </div>
          </div>
        </div>

        <%!-- materials --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Materials</span>
            <.link navigate={~p"/manage/jobs/#{@job.id}/materials"}>
              <button
                type="button"
                ontouchstart=""
                style="color:#54B57E;background:none;border:none;cursor:pointer;padding:4px;line-height:0;"
              >
                <svg width="18" height="18" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                  />
                </svg>
              </button>
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

    <%!-- add crew bottom sheet --%>
    <div
      :if={@show_staff_sheet}
      style="position:fixed;inset:0;z-index:50;display:flex;flex-direction:column;justify-content:flex-end;"
    >
      <div
        phx-click="close_staff_sheet"
        style="position:absolute;inset:0;background:rgba(0,0,0,0.65);"
      >
      </div>
      <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:0 0 100px;max-height:80vh;display:flex;flex-direction:column;">
        <div style="padding:12px 16px 10px;border-bottom:1px solid rgba(52,48,37,0.58);flex-shrink:0;">
          <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 12px;">
          </div>
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Add crew</span>
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
        <div
          class="mobile-scroll"
          style="overflow-y:auto;padding:12px 16px 0;display:flex;flex-direction:column;gap:8px;"
        >
          <div
            :if={available_members(@org_members, @job) == []}
            style="font-size:13px;color:#6E675A;text-align:center;padding:24px 0;"
          >
            All org members already assigned
          </div>
          <div
            :for={m <- available_members(@org_members, @job)}
            phx-click="add_staff"
            phx-value-id={m.id}
            ontouchstart=""
            style="background:#2B2820;border-radius:12px;padding:10px 12px;border:1px solid rgba(52,48,37,0.58);display:flex;align-items:center;gap:10px;cursor:pointer;"
          >
            <.member_card member={m} />
          </div>
        </div>
      </div>
    </div>

    <%!-- delete confirmation sheet --%>
    <div
      :if={@show_delete_confirm}
      style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
    >
      <div
        phx-click="close_delete_confirm"
        style="position:absolute;inset:0;background:rgba(0,0,0,0.65);"
      >
      </div>
      <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:20px 16px 40px;">
        <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 20px;">
        </div>
        <p style="font-size:17px;font-weight:700;color:#F4EFE2;margin-bottom:6px;">
          Delete this job?
        </p>
        <p style="font-size:13px;color:#9A9384;margin-bottom:24px;line-height:1.5;">
          This permanently removes the job and cannot be undone.
        </p>
        <div style="display:flex;flex-direction:column;gap:10px;">
          <button
            type="button"
            phx-click="confirm_delete"
            ontouchstart=""
            style="width:100%;padding:14px;border-radius:12px;border:none;background:#E87E7E;color:#16140E;font-size:15px;font-weight:700;cursor:pointer;"
          >
            Delete job
          </button>
          <button
            type="button"
            phx-click="close_delete_confirm"
            ontouchstart=""
            style="width:100%;padding:14px;border-radius:12px;border:1px solid rgba(52,48,37,0.58);background:none;color:#9A9384;font-size:15px;font-weight:600;cursor:pointer;"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>

    <%!-- sticky leave CTA — only for in-progress jobs --%>
    <div
      :if={@job.status == :in_progress}
      style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;z-index:10;"
    >
      <.glow_button href={~p"/manage/jobs/#{@job.id}/closeout"} valid={true}>
        Leave job · log distance →
      </.glow_button>
    </div>
    """
  end

  defp scheduling_hero_click(%{status: :scheduling} = job, active_shift) do
    if active_shift do
      JS.navigate(~p"/manage/jobs/#{job.id}/arrive")
    else
      JS.navigate(~p"/manage/schedule?place_job_id=#{job.id}")
    end
  end

  defp scheduling_hero_click(_job, _shift), do: nil

  defp elapsed_label(nil), do: "—"

  defp elapsed_label(arrived_at) do
    secs = DateTime.diff(DateTime.utc_now(), arrived_at, :second)
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)

    cond do
      h == 0 -> "#{m}m"
      m == 0 -> "#{h}h"
      true -> "#{h}h #{m}m"
    end
  end

  defp arrival_line(nil, _odo, _job, _org_members), do: "—"

  defp arrival_line(arrived_at, odo, job, org_members) do
    member_map = Map.new(org_members, &{&1.id, &1})

    crew =
      (job.staff_assignments || [])
      |> Enum.take(3)
      |> Enum.map(fn sa -> staff_name(Map.get(member_map, sa.member_id)) end)
      |> Enum.reject(&(&1 == "?"))
      |> Enum.join(" + ")

    [
      "arrived #{Calendar.strftime(arrived_at, "%H:%M")}",
      odo && "odo #{odo} km",
      crew != "" && crew
    ]
    |> Enum.reject(&(is_nil(&1) or &1 == false))
    |> Enum.join(" · ")
  end

  defp page_title(%{service_category: cat}) when not is_nil(cat), do: Phoenix.Naming.humanize(cat)

  defp page_title(%{type: :shift}), do: "Shift"
  defp page_title(_), do: "Job"

  defp hero_title(%{service_category: cat, garden: %{name: n}}) when not is_nil(cat) and is_binary(n) and n != "",
    do: "#{service_category_label(cat)} at #{n}"

  defp hero_title(%{service_category: cat}) when not is_nil(cat), do: service_category_label(cat)

  defp hero_title(_), do: "Job"

  defp hero_subtitle(job) do
    nickname = customer_nickname(job)
    scope = job.engagement && job.engagement.scope_title
    [nickname, scope] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(" · ")
  end

  defp customer_nickname(%{engagement: %{customer: c}}) when not is_nil(c) do
    cond do
      c.company_name_nickname -> c.company_name_nickname
      c.first_name || c.last_name -> String.trim("#{c.first_name} #{c.last_name}")
      true -> nil
    end
  end

  defp customer_nickname(_), do: nil

  defp staff_name(%{user: %{email: e}}) when is_binary(e), do: e |> String.split("@") |> hd()
  defp staff_name(nil), do: "?"
  defp staff_name(_), do: "?"

  defp available_members(org_members, job) do
    assigned = MapSet.new(job.staff_assignments, & &1.member_id)
    Enum.reject(org_members, &MapSet.member?(assigned, &1.id))
  end

  defp reload_job(socket) do
    member = socket.assigns.current_member
    job = socket.assigns.job

    job =
      Work.get_job_by_id!(job.id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :garden,
          :staff_assignments,
          engagement: [:customer],
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]
        ]
      )

    events =
      if job.status == :in_progress do
        Work.list_job_events!(job.id, actor: member, tenant: member.organisation_id)
      else
        []
      end

    arrival =
      events |> Enum.filter(&match?(%{data: %Ash.Union{type: :arrival}}, &1)) |> List.last()

    socket
    |> assign(:job, job)
    |> assign(:materials_cost, materials_cost(job.materials))
    |> assign(:arrived_at, arrival && arrival.timestamp)
    |> assign(:arrival_odo, arrival && arrival.data.value.odometer_km)
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
