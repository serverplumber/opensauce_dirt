defmodule OpenSauceWeb.ShiftLive.Start do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Operations
  alias OpenSauce.Work

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member

    venues = Operations.list_venues!(actor: member, tenant: member.organisation_id)

    all_jobs =
      Work.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer]]
      )

    active_shift = Enum.find(all_jobs, &(&1.type == :shift && &1.status == :in_progress))

    today_client_jobs =
      Enum.filter(all_jobs, fn j ->
        j.type == :client_work &&
          j.status in [:scheduled, :in_progress] &&
          j.scheduled_for == Date.utc_today() &&
          not is_nil(j.garden)
      end)

    focus_job = current_or_next_job(today_client_jobs)

    driving_venue =
      case venues do
        [] -> :headquarters
        [single] -> single
        _ -> nil
      end

    {:ok,
     socket
     |> assign(
       page_title: "Start shift",
       main_bg: "bg-[#16140E]",
       mode: :driving,
       odometer: "",
       driving_venue: driving_venue,
       venue_sheet_open: false,
       venues: venues,
       active_shift: active_shift,
       focus_job: focus_job,
       member_name: member_display_name(socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("select_mode", %{"mode" => "driving"}, socket) do
    {:noreply, assign(socket, mode: :driving, venue_sheet_open: false)}
  end

  @impl true
  def handle_event("select_mode", %{"mode" => "checkin"}, socket) do
    {:noreply, assign(socket, mode: :checkin, venue_sheet_open: false)}
  end

  @impl true
  def handle_event("select_mode", %{"mode" => "riding"}, socket) do
    {:noreply, assign(socket, mode: :riding, venue_sheet_open: false)}
  end

  @impl true
  def handle_event("open_venue_sheet", _params, socket) do
    {:noreply, assign(socket, venue_sheet_open: true)}
  end

  @impl true
  def handle_event("close_venue_sheet", _params, socket) do
    {:noreply, assign(socket, venue_sheet_open: false)}
  end

  @impl true
  def handle_event("pick_venue", %{"id" => id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == id))
    {:noreply, assign(socket, driving_venue: venue, venue_sheet_open: false)}
  end

  @impl true
  def handle_event("update_odometer", %{"odometer" => val}, socket) do
    {:noreply, assign(socket, odometer: val)}
  end

  @impl true
  def handle_event("start_shift", _params, socket) do
    if can_start?(socket.assigns.mode, socket.assigns.odometer, socket.assigns.active_shift) do
      member = socket.assigns.current_member
      now = DateTime.truncate(DateTime.utc_now(), :second)
      opts = [actor: member, tenant: member.organisation_id]

      case socket.assigns.mode do
        :driving ->
          odometer_km =
            case Integer.parse(socket.assigns.odometer) do
              {n, _} -> n
              :error -> nil
            end

          shift =
            Work.create_job!(
              %{
                type: :shift,
                status: :in_progress,
                scheduled_for: Date.utc_today(),
                organisation_id: member.organisation_id
              },
              opts
            )

          Work.log_job_event!(
            %{
              job_id: shift.id,
              timestamp: now,
              data: %{type: :shift_start, odometer_km: odometer_km},
              organisation_id: member.organisation_id
            },
            opts
          )

        mode when mode in [:checkin, :riding] ->
          if socket.assigns.active_shift do
            Work.log_job_event!(
              %{
                job_id: socket.assigns.active_shift.id,
                timestamp: now,
                data: %{type: :work_session_start},
                organisation_id: member.organisation_id
              },
              opts
            )
          end
      end

      {:noreply, push_navigate(socket, to: ~p"/manage/today")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:140px;">
      <%!-- Top bar --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:14px 16px 0;">
        <.link navigate={~p"/manage/today"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:6px;cursor:pointer;line-height:0;"
          >
            <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </.link>
        <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
          start shift
        </span>
        <div style="width:32px;"></div>
      </div>

      <%!-- Greeting --%>
      <div style="padding:16px 16px 0;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0 0 3px;">
          {greeting()}, {@member_name}
        </h1>
        <p style="font-size:12px;color:#6E675A;margin:0;">
          {today_subtitle()} · where are you?
        </p>
      </div>

      <%!-- Mode cards --%>
      <div style="padding:16px 16px 0;display:flex;flex-direction:column;gap:10px;">
        <%!-- Card 1: Loading the jalopy --%>
        <div style={"border-radius:14px;border:1.5px solid #{card_border(@mode, :driving)};background:#{card_bg(@mode, :driving)};overflow:hidden;"}>
          <button
            type="button"
            phx-click="select_mode"
            phx-value-mode="driving"
            ontouchstart=""
            style="width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px;background:none;border:none;cursor:pointer;text-align:left;"
          >
            <div style="flex:1;min-width:0;">
              <div style={"font-size:17px;font-weight:700;letter-spacing:-0.01em;color:#{card_label_color(@mode, :driving)};"}>
                Loading the jalopy
              </div>
              <div style="font-size:12px;color:#9A9384;margin-top:2px;">loading up · driving to first job</div>
            </div>
            <svg
              width="34"
              height="34"
              viewBox="0 0 24 24"
              fill="none"
              style={"flex-shrink:0;opacity:#{if @mode == :driving, do: "1", else: "0.35"};"}
            >
              <rect
                x="1" y="8" width="15" height="9" rx="1.5"
                stroke={card_label_color(@mode, :driving)}
                stroke-width="1.5"
              />
              <path
                d="M16 10.5l4 2V17h-4"
                stroke={card_label_color(@mode, :driving)}
                stroke-width="1.5"
                stroke-linejoin="round"
              />
              <circle cx="5.5" cy="17.5" r="1.5" fill={card_label_color(@mode, :driving)} />
              <circle cx="13.5" cy="17.5" r="1.5" fill={card_label_color(@mode, :driving)} />
            </svg>
          </button>

          <div :if={@mode == :driving} style="padding:0 14px 14px;border-top:1px dashed rgba(84,181,126,0.3);">
            <div style="padding-top:12px;">
              <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin:0 0 7px;">
                From
              </p>
              <.venue_selector venues={@venues} driving_venue={@driving_venue} />
            </div>

            <div style="margin-top:16px;">
              <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin:0 0 6px;">
                Start odometer
              </p>
              <form phx-change="update_odometer" phx-submit="start_shift" style="display:flex;align-items:baseline;gap:8px;">
                <input
                  type="number"
                  name="odometer"
                  value={@odometer}
                  placeholder="—"
                  min="0"
                  step="1"
                  inputmode="numeric"
                  style="background:none;border:none;outline:none;font-size:36px;font-weight:700;color:#F4EFE2;width:100%;max-width:200px;font-family:'Bricolage Grotesque',sans-serif;letter-spacing:-0.02em;-webkit-appearance:none;"
                />
                <span style="font-size:14px;color:#9A9384;">km</span>
              </form>
              <p style="font-size:11px;color:#6E675A;margin:4px 0 0;">required · needed for mileage tracking</p>
            </div>
          </div>
        </div>

        <%!-- Or divider --%>
        <div style="text-align:center;color:#6E675A;font-size:12px;font-weight:500;padding:2px 0;">
          — or —
        </div>

        <%!-- Card 2: Riding along --%>
        <div style={"border-radius:14px;border:1.5px solid #{card_border(@mode, :riding)};background:#{card_bg(@mode, :riding)};overflow:hidden;"}>
          <button
            type="button"
            phx-click="select_mode"
            phx-value-mode="riding"
            ontouchstart=""
            style="width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px;background:none;border:none;cursor:pointer;text-align:left;"
          >
            <div style="flex:1;min-width:0;">
              <div style={"font-size:17px;font-weight:700;letter-spacing:-0.01em;color:#{card_label_color(@mode, :riding)};"}>
                Riding along
              </div>
              <div style="font-size:12px;color:#9A9384;margin-top:2px;">in the van · someone else is driving</div>
            </div>
            <svg
              width="34"
              height="34"
              viewBox="0 0 24 24"
              fill="none"
              style={"flex-shrink:0;opacity:#{if @mode == :riding, do: "1", else: "0.35"};"}
            >
              <circle cx="12" cy="7" r="3" stroke={card_label_color(@mode, :riding)} stroke-width="1.5" />
              <path
                d="M5 21c0-4 3-7 7-7s7 3 7 7"
                stroke={card_label_color(@mode, :riding)}
                stroke-width="1.5"
                stroke-linecap="round"
              />
            </svg>
          </button>

          <%!-- No shift running yet --%>
          <div
            :if={@mode == :riding && is_nil(@active_shift)}
            style="padding:14px 16px 18px;border-top:1px dashed rgba(110,103,90,0.4);text-align:center;"
          >
            <div style="font-size:28px;margin:0 0 8px;line-height:1;">🚐</div>
            <p style="font-size:15px;font-weight:700;color:#F4EFE2;margin:0 0 5px;letter-spacing:-0.01em;">
              Nobody's behind the wheel yet.
            </p>
            <p style="font-size:13px;color:#9A9384;margin:0;line-height:1.45;">
              Grab a seat once the driver checks in.
            </p>
          </div>

          <%!-- Shift is running --%>
          <div
            :if={@mode == :riding && @active_shift}
            style="padding:12px 14px 14px;border-top:1px dashed rgba(84,181,126,0.3);"
          >
            <div style="display:flex;align-items:center;gap:7px;">
              <span class="dot pulse" style="flex-shrink:0;"></span>
              <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#54B57E;">
                Shift is running
              </span>
            </div>
            <p style="font-size:13px;color:#9A9384;margin:8px 0 0;">Hop in when you're ready.</p>
          </div>
        </div>

        <%!-- Or divider --%>
        <div style="text-align:center;color:#6E675A;font-size:12px;font-weight:500;padding:2px 0;">
          — or —
        </div>

        <%!-- Card 3: Already on site --%>
        <div style={"border-radius:14px;border:1.5px solid #{card_border(@mode, :checkin)};background:#{card_bg(@mode, :checkin)};overflow:hidden;"}>
          <button
            type="button"
            phx-click="select_mode"
            phx-value-mode="checkin"
            ontouchstart=""
            style="width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px;background:none;border:none;cursor:pointer;text-align:left;"
          >
            <div style="flex:1;min-width:0;">
              <div style={"font-size:17px;font-weight:700;letter-spacing:-0.01em;color:#{card_label_color(@mode, :checkin)};"}>
                Already on site
              </div>
              <div style="font-size:12px;color:#9A9384;margin-top:2px;">got here independently · no driving</div>
            </div>
            <svg
              width="34"
              height="34"
              viewBox="0 0 24 24"
              fill="none"
              style={"flex-shrink:0;opacity:#{if @mode == :checkin, do: "1", else: "0.35"};"}
            >
              <path
                d="M3 10.5L12 4l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V10.5z"
                stroke={card_label_color(@mode, :checkin)}
                stroke-width="1.5"
                stroke-linejoin="round"
              />
              <path
                d="M9 21V12h6v9"
                stroke={card_label_color(@mode, :checkin)}
                stroke-width="1.5"
                stroke-linejoin="round"
              />
            </svg>
          </button>

          <%!-- No shift running yet --%>
          <div
            :if={@mode == :checkin && is_nil(@active_shift)}
            style="padding:14px 16px 18px;border-top:1px dashed rgba(110,103,90,0.4);text-align:center;"
          >
            <div style="font-size:28px;margin:0 0 8px;line-height:1;">☕</div>
            <p style="font-size:15px;font-weight:700;color:#F4EFE2;margin:0 0 5px;letter-spacing:-0.01em;">
              Enjoy the garden.
            </p>
            <p style="font-size:13px;color:#9A9384;margin:0;line-height:1.45;">
              Nobody's started a shift yet.<br />Stick around until the van arrives.
            </p>
          </div>

          <%!-- Shift is running --%>
          <div
            :if={@mode == :checkin && @active_shift}
            style="padding:12px 14px 14px;border-top:1px dashed rgba(84,181,126,0.3);"
          >
            <div style="display:flex;align-items:center;gap:7px;margin-bottom:10px;">
              <span class="dot pulse" style="flex-shrink:0;"></span>
              <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#54B57E;">
                Shift is running
              </span>
            </div>
            <div :if={@focus_job}>
              <p style="font-size:16px;font-weight:700;letter-spacing:-0.01em;color:#F4EFE2;margin:0 0 3px;">
                {job_location_name(@focus_job)}
              </p>
              <p style="font-size:12px;color:#9A9384;margin:0;">
                {job_subtitle(@focus_job)}
              </p>
            </div>
            <p :if={is_nil(@focus_job)} style="font-size:13px;color:#9A9384;margin:0;">
              You'll be added to the crew when you join.
            </p>
          </div>
        </div>
      </div>

      <%!-- Venue picker sheet --%>
      <div
        :if={@venue_sheet_open}
        class="fixed inset-0 z-[60] flex items-end justify-center"
        role="dialog"
        aria-label="Choose depot"
      >
        <div class="absolute inset-0 bg-black/50" phx-click="close_venue_sheet" aria-hidden="true" />
        <div
          class="relative w-full max-w-lg bg-[#211E16] rounded-t-2xl px-5 pt-4"
          style="border-top:1.5px solid rgba(52,48,37,0.58);padding-bottom:max(2rem,env(safe-area-inset-bottom));"
        >
          <div style="width:36px;height:4px;background:rgba(52,48,37,0.7);border-radius:2px;margin:0 auto 16px;"></div>
          <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;margin:0 0 14px;">
            Choose depot
          </p>
          <div style="display:flex;flex-direction:column;gap:8px;padding-bottom:8px;">
            <button
              :for={venue <- @venues}
              type="button"
              phx-click="pick_venue"
              phx-value-id={venue.id}
              ontouchstart=""
              style={"width:100%;padding:12px 14px;border-radius:12px;border:1.5px solid #{if venue_active?(@driving_venue, venue), do: "#54B57E", else: "rgba(52,48,37,0.58)"};background:#{if venue_active?(@driving_venue, venue), do: "rgba(84,181,126,0.10)", else: "#16140E"};cursor:pointer;text-align:left;display:flex;align-items:center;gap:10px;"}
            >
              <span style={"width:8px;height:8px;border-radius:50%;flex-shrink:0;background:#{if venue_active?(@driving_venue, venue), do: "#54B57E", else: "rgba(154,147,132,0.3)"};"} />
              <span style={"font-size:15px;font-weight:600;color:#{if venue_active?(@driving_venue, venue), do: "#54B57E", else: "#F4EFE2"};"}>
                {venue.name}
              </span>
            </button>
          </div>
        </div>
      </div>

      <%!-- Sticky CTA — hidden when joining/riding but no shift is running --%>
      <div
        :if={@mode == :driving || @active_shift}
        style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;z-index:10;"
      >
        <.glow_button phx-click="start_shift" valid={can_start?(@mode, @odometer, @active_shift)}>
          {cta_label(@mode)}
        </.glow_button>
      </div>
    </div>
    """
  end

  attr :venues, :list, required: true
  attr :driving_venue, :any, required: true

  defp venue_selector(%{venues: []} = assigns) do
    ~H"""
    <p style="font-size:16px;font-weight:600;color:#54B57E;margin:0;">Headquarters</p>
    """
  end

  defp venue_selector(%{venues: [_single]} = assigns) do
    ~H"""
    <p style="font-size:16px;font-weight:600;color:#F4EFE2;margin:0;">{@driving_venue.name}</p>
    """
  end

  defp venue_selector(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="open_venue_sheet"
      ontouchstart=""
      style="display:inline-flex;align-items:center;gap:7px;background:#16140E;border:1.5px solid rgba(52,48,37,0.58);border-radius:10px;padding:8px 12px;cursor:pointer;"
    >
      <span style={"font-size:15px;font-weight:600;color:#{if @driving_venue, do: "#F4EFE2", else: "#6E675A"};"}>
        {if @driving_venue, do: @driving_venue.name, else: "tap to choose…"}
      </span>
      <svg width="13" height="13" fill="none" stroke="#6E675A" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M19 9l-7 7-7-7" />
      </svg>
    </button>
    """
  end

  defp can_start?(:driving, odometer, _active_shift) do
    case Integer.parse(odometer) do
      {n, _} when n >= 0 -> true
      _ -> false
    end
  end

  defp can_start?(mode, _odometer, active_shift) when mode in [:checkin, :riding],
    do: not is_nil(active_shift)

  defp cta_label(:driving), do: "start shift →"
  defp cta_label(:checkin), do: "join shift →"
  defp cta_label(:riding), do: "hop in →"

  defp venue_active?(driving_venue, venue) when is_struct(driving_venue),
    do: driving_venue.id == venue.id

  defp venue_active?(_, _), do: false

  defp card_border(mode, card) when mode == card, do: "#54B57E"
  defp card_border(_mode, _card), do: "rgba(52,48,37,0.58)"

  defp card_bg(mode, card) when mode == card, do: "rgba(84,181,126,0.07)"
  defp card_bg(_mode, _card), do: "#211E16"

  defp card_label_color(mode, card) when mode == card, do: "#54B57E"
  defp card_label_color(_mode, _card), do: "#F4EFE2"

  defp current_or_next_job([]), do: nil

  defp current_or_next_job(jobs) do
    Enum.find(jobs, &(&1.status == :in_progress)) ||
      jobs
      |> Enum.filter(&(&1.status == :scheduled))
      |> Enum.min_by(fn j -> {j.start_time && j.start_time.hour * 60 + j.start_time.minute, 0} end, fn -> nil end)
  end

  defp today_subtitle do
    now = DateTime.utc_now()
    "#{Calendar.strftime(now, "%a %-d %b")} · #{Calendar.strftime(now, "%H:%M")}"
  end

  defp greeting do
    hour = DateTime.utc_now().hour

    cond do
      hour >= 4 and hour < 12 -> "g'morning"
      hour >= 12 and hour < 17 -> "good afternoon"
      true -> "evening"
    end
  end

  defp member_display_name(user) do
    cond do
      is_binary(user.first_name) and String.trim(user.first_name) != "" ->
        String.trim(user.first_name)

      true ->
        user.email |> to_string() |> String.split("@") |> hd()
    end
  end

  defp job_location_name(%{garden: %{name: name}}) when is_binary(name) and name != "", do: name

  defp job_location_name(%{engagement: %{customer: %{company_name_nickname: nick}}})
       when is_binary(nick),
       do: nick

  defp job_location_name(%{engagement: %{customer: %{first_name: f, last_name: l}}}),
    do: "#{f} #{l}"

  defp job_location_name(_), do: "Job site"

  defp job_subtitle(job) do
    parts =
      [
        job.service_category && service_category_label(job.service_category),
        job.start_time && Calendar.strftime(job.start_time, "%H:%M")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " · ")
  end

  defp service_category_label(:installation), do: "Installation"
  defp service_category_label(:delivery), do: "Delivery"
  defp service_category_label(:pruning), do: "Pruning"
  defp service_category_label(:consultation), do: "Consultation"
  defp service_category_label(:design), do: "Design"
  defp service_category_label(:opening), do: "Opening"
  defp service_category_label(:winterization), do: "Winterization"
  defp service_category_label(:maintenance), do: "Maintenance"
  defp service_category_label(other), do: to_string(other)
end
