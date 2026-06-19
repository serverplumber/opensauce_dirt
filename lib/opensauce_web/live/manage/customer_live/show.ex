defmodule OpenSauceWeb.CustomerLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts
  alias OpenSauce.CRM

  @empty_draft %{
    "name" => "",
    "street" => "",
    "city" => "",
    "province" => "",
    "zip" => "",
    "notes" => "",
    "is_billing" => "false"
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={~p"/manage/customers"}>
          <button type="button" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;" ontouchstart="">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        </.link>
        <.link patch={~p"/manage/customers/#{@customer.reference}/edit"}>
          <button type="button" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;" ontouchstart="">
            <svg width="18" height="18" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
          </button>
        </.link>
      </div>

      <%!-- name header --%>
      <div style="padding:14px 16px 16px;text-align:center;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;margin:0;">
          {@customer.company_name_nickname || @customer.full_name}
        </h1>
        <p :if={@customer.company_name_nickname} style="font-size:13px;color:#9A9384;margin-top:4px;">
          {@customer.full_name}
        </p>
      </div>

      <%!-- contact buttons --%>
      <div style="display:flex;gap:10px;padding:0 16px 20px;">
        <a :if={@customer.phone} href={"tel:#{@customer.phone}"} ontouchstart=""
          style="flex:1;display:flex;align-items:center;justify-content:center;gap:8px;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;padding:11px;font-size:13.5px;font-weight:700;color:#F4EFE2;text-decoration:none;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style="color:#54B57E;">
            <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07A19.5 19.5 0 013.07 9.8a19.79 19.79 0 01-3.07-8.68A2 2 0 012 .94h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L6.09 8.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 16.92z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          Call
        </a>
        <a :if={@customer.email} href={"mailto:#{@customer.email}"} ontouchstart=""
          style="flex:1;display:flex;align-items:center;justify-content:center;gap:8px;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;padding:11px;font-size:13.5px;font-weight:700;color:#F4EFE2;text-decoration:none;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style="color:#54B57E;">
            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <polyline points="22,6 12,13 2,6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          Email
        </a>
        <div :if={is_nil(@customer.phone) and is_nil(@customer.email)}
          style="flex:1;text-align:center;font-size:13px;color:#6E675A;padding:11px;">
          No contact info
        </div>
      </div>

      <%!-- 3 count squares --%>
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;padding:0 16px 24px;">
        <div style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 8px;text-align:center;">
          <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;color:#54B57E;line-height:1;">
            {length(@customer.garden_addresses)}
          </p>
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-top:4px;">Gardens</p>
        </div>
        <div style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 8px;text-align:center;">
          <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;color:#54B57E;line-height:1;">
            {length(@customer.engagements)}<span style="font-size:14px;color:#54B57E;">/{length(@all_jobs)}</span>
          </p>
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-top:4px;">Eng · Jobs</p>
        </div>
        <div style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 8px;text-align:center;">
          <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;color:#54B57E;line-height:1.2;">
            {format_due_billed(@customer.invoices)}
          </p>
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-top:4px;">Due · Billed</p>
        </div>
      </div>

      <div style="padding:0 16px 100px;display:flex;flex-direction:column;gap:24px;">

        <%!-- gardens --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <span class="dark-label" style="margin-bottom:0;">Gardens</span>
            <button type="button" phx-click="open_garden_sheet" ontouchstart=""
              style="display:flex;align-items:center;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
            </button>
          </div>
          <div :if={Enum.empty?(@customer.garden_addresses)}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No gardens yet
          </div>
          <div :if={not Enum.empty?(@customer.garden_addresses)} style="display:flex;flex-direction:column;gap:8px;">
            <div :for={addr <- @customer.garden_addresses} class="jcard">
              <div style="display:flex;align-items:flex-start;gap:10px;">
                <button type="button" phx-click="open_edit_garden_sheet" phx-value-id={addr.id} ontouchstart=""
                  style="flex:1;min-width:0;background:none;border:none;padding:0;cursor:pointer;text-align:left;">
                  <p style="font-size:14px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {addr.name || "Unnamed garden"}
                  </p>
                  <p style="font-size:11.5px;color:#6E675A;margin-top:2px;">
                    {if addr.is_indoor, do: "Indoor", else: "Outdoor"}
                  </p>
                  <p :if={addr.full_address} style="font-size:12px;color:#9A9384;margin-top:2px;display:flex;align-items:center;gap:4px;overflow:hidden;">
                    <svg :if={addr.is_billing} width="12" height="12" viewBox="0 0 24 24" fill="none" style="flex:0 0 auto;color:#54B57E;">
                      <rect x="1" y="4" width="22" height="16" rx="2" stroke="currentColor" stroke-width="2"/>
                      <line x1="1" y1="10" x2="23" y2="10" stroke="currentColor" stroke-width="2"/>
                    </svg>
                    <span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{addr.full_address}</span>
                  </p>
                  <p :if={addr.is_billing and is_nil(addr.full_address)} style="font-size:12px;color:#9A9384;margin-top:2px;display:flex;align-items:center;gap:4px;">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" style="flex:0 0 auto;color:#54B57E;">
                      <rect x="1" y="4" width="22" height="16" rx="2" stroke="currentColor" stroke-width="2"/>
                      <line x1="1" y1="10" x2="23" y2="10" stroke="currentColor" stroke-width="2"/>
                    </svg>
                    Billing address
                  </p>
                  <p :if={addr.notes} style="font-size:12px;color:#6E675A;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-style:italic;">
                    {addr.notes}
                  </p>
                </button>
                <div style="display:flex;flex-direction:column;align-items:flex-end;gap:8px;flex:0 0 auto;">
                  <span :if={Map.get(@open_jobs_by_garden, addr.id, 0) > 0} class="pill sched">
                    {Map.get(@open_jobs_by_garden, addr.id)} open
                  </span>
                  <.link navigate={~p"/manage/jobs/new?garden_id=#{addr.id}&customer_ref=#{@customer.reference}"} ontouchstart="" style="text-decoration:none;">
                    <div style="width:48px;border-radius:10px;background:#54B57E;padding:7px 4px 6px;display:flex;flex-direction:column;align-items:center;gap:3px;color:#0C1F15;">
                      <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                      <span style="font-size:10px;font-weight:700;letter-spacing:0.01em;">+ Job</span>
                    </div>
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- engagements --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <span class="dark-label" style="margin-bottom:0;">Engagements</span>
            <.link navigate={~p"/manage/customers/#{@customer.reference}/engagements/new"}>
              <button type="button" ontouchstart=""
                style="display:flex;align-items:center;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
              </button>
            </.link>
          </div>
          <div :if={Enum.empty?(@customer.engagements)}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No engagements yet
          </div>
          <div :if={not Enum.empty?(@customer.engagements)} style="display:flex;flex-direction:column;gap:8px;">
            <div :for={e <- @customer.engagements} class="jcard">
              <div style="display:flex;align-items:flex-start;gap:10px;">
                <.link navigate={~p"/manage/customers/#{@customer.reference}/engagements/#{e.id}"} style="flex:1;min-width:0;text-decoration:none;">
                  <p style="font-size:14px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {e.scope_title || (if e.garden, do: e.garden.name || "Unnamed site", else: "No site")}
                  </p>
                  <p style="font-size:12px;color:#9A9384;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {if e.garden, do: e.garden.name || "—", else: "—"}
                  </p>
                  <p :if={format_term(e.term_start, e.term_end) != "—"} style="font-size:12px;color:#9A9384;margin-top:1px;">
                    {format_term(e.term_start, e.term_end)}
                  </p>
                </.link>
                <div style="display:flex;flex-direction:column;align-items:flex-end;gap:8px;flex:0 0 auto;">
                  <div style="display:flex;align-items:center;gap:8px;">
                    <span class={"pill #{engagement_pill_class(e.status)}"}>{Phoenix.Naming.humanize(e.status)}</span>
                  </div>
                  <.link navigate={~p"/manage/jobs/new?engagement_id=#{e.id}&customer_ref=#{@customer.reference}"} ontouchstart="" style="text-decoration:none;">
                    <div style="width:48px;border-radius:10px;background:#54B57E;padding:7px 4px 6px;display:flex;flex-direction:column;align-items:center;gap:3px;color:#0C1F15;">
                      <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                      <span style="font-size:10px;font-weight:700;letter-spacing:0.01em;">+ Job</span>
                    </div>
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- jobs --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <span class="dark-label" style="margin-bottom:0;">Jobs</span>
            <.link navigate={~p"/manage/jobs/new?customer_ref=#{@customer.reference}"} ontouchstart="">
              <button type="button" style="display:flex;align-items:center;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
              </button>
            </.link>
          </div>
          <div :if={Enum.empty?(@all_jobs)}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No jobs yet
          </div>
          <div :if={not Enum.empty?(@all_jobs)} style="display:flex;flex-direction:column;gap:8px;">
            <.link :for={job <- @all_jobs} navigate={job_url(job.id, @customer.reference)} style="display:block;text-decoration:none;">
              <div class={"jcard#{if job.status == :in_progress, do: " live", else: ""}"}>
                <div style="display:flex;align-items:center;gap:10px;">
                  <div style="flex:1;min-width:0;">
                    <div class="jcat" style="margin-bottom:4px;">
                      <span class="catdot" style={"background:#{job_category_color(job.service_category)}"}></span>
                      <span style="font-size:12px;">{job_category_label(job.service_category)}</span>
                    </div>
                    <p :if={job.garden} style="font-size:13.5px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                      {job.garden.name || "Unnamed site"}
                    </p>
                    <p :if={job.scheduled_for} style="font-size:12px;color:#9A9384;margin-top:2px;">
                      {Calendar.strftime(job.scheduled_for, "%-d %B %Y")}
                    </p>
                  </div>
                  <span class={"pill #{job_pill_class(job.status)}"}>{job_status_label(job.status)}</span>
                </div>
              </div>
            </.link>
          </div>
        </div>

      </div>

      <%!-- add garden sheet --%>
      <div :if={@show_garden_sheet}
        id="garden-sheet"
        style="position:fixed;inset:0;z-index:60;"
        role="dialog" aria-modal="true" aria-label="Add garden">
        <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);" phx-click="close_garden_sheet"></div>
        <div style="position:absolute;bottom:0;left:0;right:0;background:#211E16;border-radius:20px 20px 0 0;max-height:90dvh;display:flex;flex-direction:column;">
          <div style="display:flex;align-items:center;justify-content:space-between;padding:16px 16px 12px;border-bottom:1px solid rgba(52,48,37,0.58);flex:0 0 auto;">
            <h3 style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;margin:0;">
              {if @editing_garden, do: "Edit garden", else: "Add garden"}
            </h3>
            <button type="button" phx-click="close_garden_sheet" ontouchstart=""
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
              </svg>
            </button>
          </div>
          <.form for={:garden} id="garden-draft-form" phx-submit="save_garden"
            style="flex:1;overflow-y:auto;padding:16px 16px max(24px,env(safe-area-inset-bottom));display:flex;flex-direction:column;gap:16px;">
            <div>
              <label class="dark-label" for="draft-name">Garden name</label>
              <input class="dark-input" type="text" name="garden[name]" id="draft-name" value={@draft["name"]} placeholder="e.g. North Field" />
            </div>
            <div>
              <label class="dark-label" for="draft-street">Street</label>
              <input class="dark-input" type="text" name="garden[street]" id="draft-street" value={@draft["street"]} />
            </div>
            <div>
              <label class="dark-label" for="draft-city">City</label>
              <input class="dark-input" type="text" name="garden[city]" id="draft-city" value={@draft["city"]} phx-hook="TitleCase" />
            </div>
            <div style="display:grid;grid-template-columns:7rem 1fr auto;gap:12px;align-items:end;">
              <div>
                <label class="dark-label" for="draft-zip">Postal code</label>
                <input class="dark-input" type="text" name="garden[zip]" id="draft-zip" value={@draft["zip"]} phx-hook="FormatPostal" placeholder="K1A 0A0" />
              </div>
              <div>
                <label class="dark-label" for="draft-province">Province</label>
                <input class="dark-input" type="text" name="garden[province]" id="draft-province" value={@draft["province"]} phx-hook="TitleCase" />
              </div>
              <div style="display:flex;flex-direction:column;align-items:center;gap:6px;padding-bottom:2px;">
                <span class="dark-label" style="margin:0;">Billing</span>
                <button type="button" phx-click="toggle_draft_billing" ontouchstart=""
                  style={"position:relative;display:inline-flex;height:24px;width:44px;align-items:center;border-radius:999px;border:none;cursor:pointer;transition:background .12s ease;#{if @draft["is_billing"] == "true", do: "background:#54B57E;", else: "background:rgba(52,48,37,0.8);"}"}
                  role="switch" aria-checked={@draft["is_billing"] == "true"}>
                  <span style={"position:absolute;height:18px;width:18px;border-radius:50%;background:#F4EFE2;transition:transform .12s ease;#{if @draft["is_billing"] == "true", do: "transform:translateX(22px);", else: "transform:translateX(3px);"}"}></span>
                </button>
                <input type="hidden" name="garden[is_billing]" value={@draft["is_billing"]} />
              </div>
            </div>
            <div>
              <label class="dark-label" for="draft-notes">Notes</label>
              <textarea class="dark-textarea" name="garden[notes]" id="draft-notes" rows="2" placeholder="Gate code, access info…"><%= @draft["notes"] %></textarea>
            </div>
            <button type="submit" ontouchstart=""
              style="width:100%;border-radius:12px;border:none;background:#54B57E;padding:13px;font-size:13.5px;font-weight:700;color:#0C1F15;cursor:pointer;">
              {if @editing_garden, do: "Save changes", else: "Add garden"}
            </button>
          </.form>
        </div>
      </div>

    <%!-- Edit customer sheet --%>
    <div :if={@live_action == :edit}
      style="position:fixed;inset:0;z-index:60;"
      role="dialog" aria-modal="true" aria-label="Edit customer">
      <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);"
        phx-click={JS.patch(~p"/manage/customers/#{@customer.reference}")}></div>
      <div style="position:absolute;bottom:0;left:0;right:0;background:#211E16;border-radius:20px 20px 0 0;max-height:90dvh;display:flex;flex-direction:column;">
        <div style="display:flex;align-items:center;justify-content:space-between;padding:16px 16px 12px;border-bottom:1px solid rgba(52,48,37,0.58);flex:0 0 auto;">
          <h3 style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;margin:0;">Edit Customer</h3>
          <button type="button" phx-click={JS.patch(~p"/manage/customers/#{@customer.reference}")} ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </button>
        </div>
        <div style="flex:1;overflow-y:auto;padding:16px 16px max(24px,env(safe-area-inset-bottom));">
          <.live_component
            module={OpenSauceWeb.CustomerLive.FormComponent}
            id={@customer.id}
            current_member={@current_member}
            action={@live_action}
            customer={@customer}
            patch={~p"/manage/customers/#{@customer.reference}"}
          />
        </div>
      </div>
    </div>

    <%!-- Engagement materials modal --%>
    <.modal
      :if={@live_action == :engagement_materials}
      id="engagement-materials-modal"
      title="Materials"
      max_width="max-w-3xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.MaterialsComponent}
        id={"materials-#{@engagement_id}"}
        engagement_id={@engagement_id}
        current_member={@current_member}
        currency={@organisation.currency}
      />
    </.modal>

    <%!-- Schedule job modal --%>
    <.modal
      :if={@schedule_job_engagement != nil}
      id="schedule-job-modal"
      title={"New job — #{schedule_job_title(@schedule_job_engagement)}"}
      max_width="max-w-xl"
      show
      on_cancel={JS.push("close_schedule_job")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.ScheduleJobComponent}
        id={"schedule-job-#{@schedule_job_engagement.id}"}
        engagement={@schedule_job_engagement}
        current_member={@current_member}
      />
    </.modal>

    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:engagement_id, nil)
     |> assign(:schedule_job_engagement, nil)
     |> assign(:show_garden_sheet, false)
     |> assign(:editing_garden, nil)
     |> assign(:draft, @empty_draft)
     |> assign(:open_jobs_by_garden, %{})}
  end

  @impl true
  def handle_params(%{"reference" => reference} = params, _, socket) do
    customer = load_customer(reference, socket)

    all_jobs =
      customer.engagements
      |> Enum.flat_map(& &1.jobs)
      |> Enum.sort_by(& &1.scheduled_for, {:desc, Date})

    socket =
      socket
      |> assign(:page_title, short_name(customer))
      |> assign(:main_bg, "bg-[#16140E]")
      |> assign(:customer, customer)
      |> assign(:engagement_id, params["engagement_id"])
      |> assign(:all_jobs, all_jobs)
      |> assign(:open_jobs_by_garden, open_jobs_by_garden(customer, socket))

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case CRM.destroy_customer(socket.assigns.customer,
           actor: socket.assigns.current_member,
           tenant: socket.assigns.current_member.organisation_id
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer deleted.")
         |> push_navigate(to: ~p"/manage/customers")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete customer.")}
    end
  end

  @impl true
  def handle_event("open_garden_sheet", _params, socket) do
    member = socket.assigns.current_member
    org = Accounts.get_organisation!(member.organisation_id, authorize?: false, load: [:address])

    draft = %{@empty_draft |
      "city" => (org.address && org.address.city) || "",
      "province" => (org.address && org.address.province) || ""
    }

    {:noreply, assign(socket, show_garden_sheet: true, editing_garden: nil, draft: draft)}
  end

  def handle_event("open_edit_garden_sheet", %{"id" => id}, socket) do
    addr = Enum.find(socket.assigns.customer.garden_addresses, &(&1.id == id))

    draft = %{
      "name" => addr.name || "",
      "street" => addr.street || "",
      "city" => addr.city || "",
      "province" => addr.province || "",
      "zip" => addr.zip || "",
      "notes" => addr.notes || "",
      "is_billing" => to_string(addr.is_billing)
    }

    {:noreply, assign(socket, show_garden_sheet: true, editing_garden: addr, draft: draft)}
  end

  def handle_event("close_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: false, editing_garden: nil)}
  end

  def handle_event("toggle_draft_billing", _params, socket) do
    new_val = if socket.assigns.draft["is_billing"] == "true", do: "false", else: "true"
    {:noreply, assign(socket, draft: Map.put(socket.assigns.draft, "is_billing", new_val))}
  end

  def handle_event("save_garden", %{"garden" => params}, socket) do
    member = socket.assigns.current_member
    customer = socket.assigns.customer
    editing = socket.assigns.editing_garden
    is_billing_new = params["is_billing"] == "true"

    updated_list =
      if editing do
        Enum.map(customer.garden_addresses, fn addr ->
          if addr.id == editing.id do
            %{
              "id" => addr.id,
              "name" => params["name"],
              "street" => params["street"],
              "city" => params["city"],
              "province" => params["province"],
              "zip" => params["zip"],
              "notes" => params["notes"],
              "is_garden" => "true",
              "is_billing" => params["is_billing"],
              "is_indoor" => to_string(addr.is_indoor)
            }
          else
            %{
              "id" => addr.id,
              "name" => addr.name || "",
              "street" => addr.street || "",
              "city" => addr.city || "",
              "province" => addr.province || "",
              "zip" => addr.zip || "",
              "notes" => addr.notes,
              "is_garden" => "true",
              "is_billing" => if(is_billing_new, do: "false", else: to_string(addr.is_billing)),
              "is_indoor" => to_string(addr.is_indoor)
            }
          end
        end)
      else
        existing =
          Enum.map(customer.garden_addresses, fn addr ->
            %{
              "id" => addr.id,
              "name" => addr.name || "",
              "street" => addr.street || "",
              "city" => addr.city || "",
              "province" => addr.province || "",
              "zip" => addr.zip || "",
              "notes" => addr.notes,
              "is_garden" => "true",
              "is_billing" => if(is_billing_new, do: "false", else: to_string(addr.is_billing)),
              "is_indoor" => to_string(addr.is_indoor)
            }
          end)

        existing ++ [Map.put(params, "is_garden", "true")]
      end

    updated_list = Enum.map(updated_list, &nilify_map_values/1)

    result =
      customer
      |> Ash.Changeset.for_update(:update, %{garden_addresses: updated_list},
        actor: member,
        tenant: member.organisation_id
      )
      |> Ash.update()

    case result do
      {:ok, _} ->
        updated_customer = load_customer(customer.reference, socket)

        {:noreply,
         socket
         |> assign(:customer, updated_customer)
         |> assign(:open_jobs_by_garden, open_jobs_by_garden(updated_customer, socket))
         |> assign(:show_garden_sheet, false)
         |> assign(:editing_garden, nil)
         |> assign(:draft, @empty_draft)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not save garden.")
         |> assign(:show_garden_sheet, false)
         |> assign(:editing_garden, nil)}
    end
  end

  @impl true
  def handle_event("open_schedule_job", %{"id" => id}, socket) do
    engagement = Enum.find(socket.assigns.customer.engagements, &(&1.id == id))
    {:noreply, assign(socket, :schedule_job_engagement, engagement)}
  end

  def handle_event("close_schedule_job", _params, socket) do
    {:noreply, assign(socket, :schedule_job_engagement, nil)}
  end

  @impl true
  def handle_info({OpenSauceWeb.CustomerLive.FormComponent, {:saved, customer}}, socket) do
    {:noreply, assign(socket, :customer, load_customer(customer.reference, socket))}
  end

  def handle_info(
        {OpenSauceWeb.EngagementLive.ScheduleJobComponent, {:job_created, _job, count}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:customer, load_customer(socket.assigns.customer.reference, socket))
     |> assign(:schedule_job_engagement, nil)
     |> put_flash(:info, "Job scheduled with #{count} plant#{if count == 1, do: "", else: "s"}.")}
  end

  defp load_customer(reference, socket) do
    CRM.get_customer_by_reference!(
      reference,
      actor: socket.assigns.current_member,
      tenant: socket.assigns.current_member.organisation_id,
      load: [
        :full_name,
        garden_addresses: [:name, :full_address, :is_billing, :notes, :is_indoor],
        invoices: [:amount, :status],
        engagements: [:total_quoted_value, :materials, garden: [:name], jobs: [garden: [:name]]]
      ]
    )
  end

  defp open_jobs_by_garden(customer, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    customer.garden_addresses
    |> Enum.map(fn addr ->
      count =
        case OpenSauce.Work.list_jobs_at_garden(addr.id, opts) do
          {:ok, jobs} -> length(jobs)
          _ -> 0
        end

      {addr.id, count}
    end)
    |> Enum.reject(fn {_, count} -> count == 0 end)
    |> Map.new()
  end

  defp short_name(customer) do
    customer.company_name_nickname || customer.first_name
  end

  defp schedule_job_title(engagement) do
    if engagement.garden, do: engagement.garden.name || "garden", else: "engagement"
  end

  defp format_due_billed(invoices) do
    zero = Decimal.new(0)
    billed = invoices |> Enum.map(& &1.amount) |> Enum.reject(&is_nil/1) |> Enum.reduce(zero, &Decimal.add/2)
    due = invoices |> Enum.filter(&(&1.status == :sent)) |> Enum.map(& &1.amount) |> Enum.reject(&is_nil/1) |> Enum.reduce(zero, &Decimal.add/2)
    "#{Decimal.to_string(due, :normal)} / #{Decimal.to_string(billed, :normal)}"
  end

  defp format_term(nil, nil), do: "—"
  defp format_term(start, nil), do: "From #{Date.to_iso8601(start)}"
  defp format_term(nil, end_date), do: "Until #{Date.to_iso8601(end_date)}"
  defp format_term(start, end_date), do: "#{Date.to_iso8601(start)} → #{Date.to_iso8601(end_date)}"

  defp engagement_pill_class(:signed), do: "live"
  defp engagement_pill_class(:in_progress), do: "live"
  defp engagement_pill_class(:completed), do: "done"
  defp engagement_pill_class(:cancelled), do: "cancel"
  defp engagement_pill_class(_), do: "sched"

  defp job_pill_class(:in_progress), do: "live"
  defp job_pill_class(:scheduling), do: "cancel"
  defp job_pill_class(:completed), do: "done"
  defp job_pill_class(:cancelled), do: "cancel"
  defp job_pill_class(_), do: "sched"

  defp job_status_label(:scheduling), do: "Place"
  defp job_status_label(:scheduled), do: "Scheduled"
  defp job_status_label(:in_progress), do: "Live"
  defp job_status_label(:completed), do: "Done"
  defp job_status_label(:cancelled), do: "Cancelled"
  defp job_status_label(_), do: "—"

  defp job_category_color(:installation), do: "#DB9258"
  defp job_category_color(:delivery), do: "#DB9258"
  defp job_category_color(:consultation), do: "#5AB4D8"
  defp job_category_color(:design), do: "#5AB4D8"
  defp job_category_color(_), do: "#54B57E"

  defp job_category_label(nil), do: "—"
  defp job_category_label(:installation), do: "Installation"
  defp job_category_label(:delivery), do: "Delivery"
  defp job_category_label(:pruning), do: "Pruning"
  defp job_category_label(:consultation), do: "Consultation"
  defp job_category_label(:design), do: "Design"
  defp job_category_label(:opening), do: "Opening"
  defp job_category_label(:winterization), do: "Winterization"
  defp job_category_label(:maintenance), do: "Maintenance"
  defp job_category_label(other), do: to_string(other)

  defp job_url(job_id, customer_ref) do
    return = URI.encode_www_form("/manage/customers/#{customer_ref}")
    "/manage/jobs/#{job_id}?return_to=#{return}"
  end

  defp nilify(""), do: nil
  defp nilify(s), do: s
  defp nilify_map_values(map), do: Map.new(map, fn {k, v} -> {k, nilify(v)} end)
end
