defmodule OpenSauceWeb.EngagementLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Storage
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"reference" => reference, "engagement_id" => engagement_id} = params, _uri, socket) do
    member = socket.assigns.current_member
    return_to = Map.get(params, "return_to", ~p"/manage/customers/#{reference}")

    engagement =
      Ash.get!(CRM.Engagement, engagement_id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :customer,
          :garden,
          :images,
          materials: [:supplier_catalog_item],
          jobs: [:garden]
        ]
      )

    images = Enum.sort_by(engagement.images, &if(&1.type == :painting, do: 0, else: 1))

    {:noreply,
     socket
     |> assign(:reference, reference)
     |> assign(:return_to, return_to)
     |> assign(:engagement, engagement)
     |> assign(:images, images)
     |> assign(:materials_cost, materials_cost(engagement.materials))
     |> assign(:show_job_sheet, false)
     |> assign(:page_title, engagement.scope_title || "Engagement")
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_event("open_job_sheet", _params, socket) do
    {:noreply, assign(socket, :show_job_sheet, true)}
  end

  def handle_event("close_job_sheet", _params, socket) do
    {:noreply, assign(socket, :show_job_sheet, false)}
  end

  @impl true
  def handle_info(
        {OpenSauceWeb.EngagementLive.ScheduleJobComponent, {:job_created, _job, count}},
        socket
      ) do
    member = socket.assigns.current_member
    reference = socket.assigns.reference
    engagement_id = socket.assigns.engagement.id

    engagement =
      Ash.get!(CRM.Engagement, engagement_id,
        actor: member,
        tenant: member.organisation_id,
        load: [:customer, :garden, :images, materials: [:supplier_catalog_item], jobs: [:garden]]
      )

    images = Enum.sort_by(engagement.images, &if(&1.type == :painting, do: 0, else: 1))

    {:noreply,
     socket
     |> assign(:engagement, engagement)
     |> assign(:images, images)
     |> assign(:materials_cost, materials_cost(engagement.materials))
     |> assign(:show_job_sheet, false)
     |> put_flash(:info, "Job created with #{count} plant#{if count == 1, do: "", else: "s"}.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:100px;">

      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={@return_to}>
          <button type="button" ontouchstart="" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        </.link>
        <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}/edit"}>
          <button type="button" ontouchstart="" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="1" fill="currentColor"/>
              <circle cx="19" cy="12" r="1" fill="currentColor"/>
              <circle cx="5" cy="12" r="1" fill="currentColor"/>
            </svg>
          </button>
        </.link>
      </div>

      <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:14px;">

        <%!-- header --%>
        <div>
          <p style="font-size:12px;color:#9A9384;margin-bottom:4px;">
            {customer_short_name(@engagement.customer)} · {if @engagement.garden, do: @engagement.garden.name, else: "—"}
          </p>
          <div style="display:flex;align-items:baseline;gap:8px;">
            <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0;line-height:1.2;">
              {@engagement.scope_title || "Engagement"}
            </h1>
            <span :if={@engagement.signature} title={"signed " <> signature_label(@engagement.signature)}
              style="flex-shrink:0;display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;border-radius:50%;border:1.5px solid #54B57E;color:#54B57E;font-size:11px;line-height:1;">
              ✓
            </span>
          </div>
          <div style="display:flex;gap:6px;margin-top:6px;align-items:center;flex-wrap:wrap;">
            <span class={"pill #{engagement_pill_class(@engagement.status)}"}>{Phoenix.Naming.humanize(@engagement.status)}</span>
            <span style="font-size:11px;color:#9A9384;">{term_label(@engagement)}</span>
            <span :if={@engagement.signature} style="font-size:11px;color:#9A9384;">
              · signed {signature_label(@engagement.signature)}
            </span>
          </div>
        </div>

        <%!-- gallery --%>
        <div>
          <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px;">
            <span class="dark-label" style="margin-bottom:0;">
              {gallery_heading(@images)}
            </span>
            <span :if={length(@images) > 3} style="font-size:11px;color:#54B57E;">
              view all {length(@images)}
            </span>
          </div>
          <div style="display:flex;gap:6px;overflow-x:auto;-webkit-overflow-scrolling:touch;padding-bottom:4px;">
            <div :for={img <- Enum.take(@images, 6)}
              style={"position:relative;border-radius:8px;overflow:hidden;background:#211E16;flex:0 0 auto;#{if img.type == :painting, do: "width:96px;height:96px;", else: "width:72px;height:96px;"}"}>
              <img src={Storage.url(img.storage_key)} style="width:100%;height:100%;object-fit:cover;" />
              <span :if={img.type == :painting}
                style="position:absolute;left:4px;top:4px;background:rgba(0,0,0,0.6);border-radius:4px;padding:2px 5px;font-size:10px;color:#F4EFE2;">
                painting
              </span>
            </div>
            <%!-- empty state or add button --%>
            <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}/edit"}>
              <div style="width:56px;height:96px;border-radius:8px;border:1.5px dashed rgba(52,48,37,0.58);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;flex:0 0 auto;">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" stroke="#6E675A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  <circle cx="12" cy="13" r="4" stroke="#6E675A" stroke-width="2"/>
                </svg>
                <span style="font-size:9px;color:#6E675A;text-align:center;line-height:1.2;">+ photo</span>
              </div>
            </.link>
          </div>
        </div>

        <%!-- scope --%>
        <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px 14px;">
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">Scope</p>
          <p style="font-size:13px;color:#F4EFE2;line-height:1.55;">
            {@engagement.scope_description || "—"}
          </p>
        </div>

        <%!-- pricing stats --%>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;">
          <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}/edit"}>
            <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;cursor:pointer;">
              <p style="font-size:18px;font-weight:700;color:#F4EFE2;line-height:1.1;">
                {price_display(@engagement.install_price, @organisation.currency)}
              </p>
              <p style="font-size:10px;color:#6E675A;margin-top:3px;">install ✎</p>
            </div>
          </.link>
          <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}/edit"}>
            <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;cursor:pointer;">
              <p style="font-size:18px;font-weight:700;color:#F4EFE2;line-height:1.1;">
                {price_display(@engagement.maintenance_price_annual, @organisation.currency)}
              </p>
              <p style="font-size:10px;color:#6E675A;margin-top:3px;">maint./yr ✎</p>
            </div>
          </.link>
          <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;">
            <p style="font-size:18px;font-weight:700;color:#F4EFE2;line-height:1.1;">
              {length(@engagement.materials)}
            </p>
            <p style="font-size:10px;color:#6E675A;margin-top:3px;">plants</p>
          </div>
        </div>

        <%!-- planned materials --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Planned materials</span>
            <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}/materials"}>
              <span style="font-size:12px;font-weight:700;color:#54B57E;">edit list</span>
            </.link>
          </div>
          <div :if={@engagement.materials == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No materials yet
          </div>
          <.link :if={@engagement.materials != []}
            navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}/materials"}>
            <div class="jcard" style="display:flex;align-items:center;justify-content:space-between;">
              <div>
                <p style="font-size:14px;font-weight:600;color:#F4EFE2;">
                  {length(@engagement.materials)} {if length(@engagement.materials) == 1, do: "line item", else: "line items"}
                </p>
                <p style="font-size:12px;color:#9A9384;margin-top:2px;">
                  est {HtmlHelpers.format_currency(@organisation.currency, @materials_cost)}
                </p>
              </div>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M9 18l6-6-6-6" stroke="#6E675A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
          </.link>
        </div>

        <%!-- jobs --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Jobs</span>
            <button type="button" phx-click="open_job_sheet" ontouchstart=""
              style="display:flex;align-items:center;gap:4px;font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
              Add
            </button>
          </div>
          <div :if={@engagement.jobs == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No jobs yet
          </div>
          <div :if={@engagement.jobs != []} style="display:flex;flex-direction:column;gap:8px;">
            <.link :for={job <- Enum.sort_by(@engagement.jobs, &{job_sort_order(&1.status), &1.scheduled_for})}
              navigate={~p"/manage/jobs/#{job.id}/materials"}
              style="text-decoration:none;">
              <div class="jcard">
                <div style="display:flex;align-items:center;gap:10px;">
                  <div style={"width:3px;border-radius:2px;align-self:stretch;background:#{job_accent(job.status)};flex-shrink:0;"}></div>
                  <div style="flex:1;min-width:0;">
                    <p style="font-size:14px;font-weight:600;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                      {job_title(job)}
                    </p>
                    <p style="font-size:12px;color:#9A9384;margin-top:2px;">
                      {job_meta(job)}
                    </p>
                  </div>
                  <span class={"pill #{job_pill_class(job.status)}"} style="flex-shrink:0;">
                    {job_status_label(job.status)}
                  </span>
                </div>
              </div>
            </.link>
          </div>
        </div>

      </div>

      <.modal
        :if={@show_job_sheet}
        id="new-job-modal"
        title="New Job"
        show
        on_cancel={JS.push("close_job_sheet")}
      >
        <.live_component
          module={OpenSauceWeb.EngagementLive.ScheduleJobComponent}
          id={"schedule-job-#{@engagement.id}"}
          engagement={@engagement}
          current_member={@current_member}
        />
      </.modal>
    </div>
    """
  end

  defp customer_short_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  defp customer_short_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"

  defp engagement_pill_class(:draft), do: "sched"
  defp engagement_pill_class(:proposed), do: "sched"
  defp engagement_pill_class(:signed), do: "sched"
  defp engagement_pill_class(:in_progress), do: "live"
  defp engagement_pill_class(:completed), do: "done"
  defp engagement_pill_class(:cancelled), do: "cancel"
  defp engagement_pill_class(_), do: "sched"

  defp term_label(%{term_start: nil, term_end: nil}), do: ""
  defp term_label(%{term_start: s, term_end: nil}), do: "from #{s}"
  defp term_label(%{term_start: nil, term_end: e}), do: "until #{e}"
  defp term_label(%{term_start: s, term_end: e}), do: "#{s} – #{e}"

  defp signature_label(%{signed_by_name: name, signed_at: at}) when is_binary(name) do
    date = if at, do: Calendar.strftime(at, "%d %b"), else: "?"
    "#{name} · #{date}"
  end

  defp signature_label(_), do: "signed"

  defp gallery_heading([]), do: "Photos"

  defp gallery_heading(images) do
    paintings = Enum.count(images, &(&1.type == :painting))
    if paintings > 0, do: "Garden as drawn · photos", else: "Photos"
  end

  defp price_display(nil, _currency), do: "—"
  defp price_display(price, currency), do: HtmlHelpers.format_currency(currency, price)

  defp materials_cost([]), do: Decimal.new(0)

  defp materials_cost(materials) do
    Enum.reduce(materials, Decimal.new(0), fn m, acc ->
      unit = m.supplier_catalog_item.unit_price || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(m.quantity, unit))
    end)
  end

  defp job_title(%{service_category: cat}) when not is_nil(cat) do
    Phoenix.Naming.humanize(cat)
  end

  defp job_title(%{type: :shift}), do: "Shift"
  defp job_title(%{type: :internal_work, account_code: code}) when not is_nil(code), do: Phoenix.Naming.humanize(code)
  defp job_title(_), do: "Job"

  defp job_meta(%{scheduled_for: nil, status: status}), do: Phoenix.Naming.humanize(status)

  defp job_meta(%{scheduled_for: date, duration_estimate: dur, status: _status}) do
    date_str = Calendar.strftime(date, "%a %d %b")
    dur_str = if dur, do: " · #{fmt_dur(dur)}", else: ""
    "#{date_str}#{dur_str}"
  end

  defp fmt_dur(minutes) when minutes < 60, do: "#{minutes}m"

  defp fmt_dur(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    if m == 0, do: "#{h}h", else: "#{h}h #{m}m"
  end

  defp job_sort_order(:in_progress), do: 0
  defp job_sort_order(:scheduling), do: 1
  defp job_sort_order(:scheduled), do: 2
  defp job_sort_order(:completed), do: 3
  defp job_sort_order(:cancelled), do: 4
  defp job_sort_order(_), do: 1

  defp job_accent(:in_progress), do: "#54B57E"
  defp job_accent(:scheduling), do: "#DB9258"
  defp job_accent(:completed), do: "#5AB4D8"
  defp job_accent(:cancelled), do: "#6E675A"
  defp job_accent(_), do: "#DB9258"

  defp job_pill_class(:in_progress), do: "live"
  defp job_pill_class(:scheduling), do: "cancel"
  defp job_pill_class(:scheduled), do: "sched"
  defp job_pill_class(:completed), do: "done"
  defp job_pill_class(:cancelled), do: "cancel"
  defp job_pill_class(_), do: "sched"

  defp job_status_label(:in_progress), do: "On site"
  defp job_status_label(:scheduling), do: "Place"
  defp job_status_label(:scheduled), do: "Scheduled"
  defp job_status_label(:completed), do: "Done"
  defp job_status_label(:cancelled), do: "Cancelled"
  defp job_status_label(s), do: Phoenix.Naming.humanize(s)
end
