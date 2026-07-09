# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.Components.Jobs do
  @moduledoc """
  Shared job card component used across the job index, home, and shift summary screens.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    router: OpenSauceWeb.Router,
    endpoint: OpenSauceWeb.Endpoint

  import OpenSauceWeb.Components.Core, only: [member_avatar: 1]
  import OpenSauceWeb.HtmlHelpers, only: [format_currency: 2]

  alias Phoenix.LiveView.JS

  @doc """
  A job card for use in list and summary screens.

  ## Attrs

  - `job` — required. Must have `:garden`, `:engagement` (with `:customer`), and `:status` loaded.
  - `return_to` — appended as `?return_to=` on the navigate path. Default nil.
  - `org_members` — list of org members; enables the crew row and live strip. Default [].
  - `show_due` — show the due date on unscheduled cards. Default false.
  - `place_on_tap` — when true, tapping a `:scheduling` job card (shift off) navigates to the schedule screen to place it. Default false.
  - `show_start` — when true, card tap on a `:scheduling` job navigates to the arrive screen (shift is on). Takes precedence over `place_on_tap`. Default false.
  """
  attr :job, :any, required: true
  attr :return_to, :string, default: nil
  attr :org_members, :list, default: []
  attr :show_due, :boolean, default: false
  attr :place_on_tap, :boolean, default: false
  attr :show_start, :boolean, default: false

  def job_card(assigns) do
    ~H"""
    <div
      class={["jcard", @job.status == :in_progress && "live"]}
      phx-click={card_navigate(@job, @return_to, @place_on_tap, @show_start)}
      ontouchstart=""
    >
      <%!-- top row: title + status chip --%>
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
        <div style="min-width:0;flex:1;">
          <div style="font-size:15.5px;font-weight:700;letter-spacing:-0.01em;line-height:1.25;color:#F4EFE2;">
            {job_title(@job)}
          </div>
          <div
            :if={job_location(@job)}
            style="margin-top:4px;font-size:12.5px;color:#9A9384;line-height:1.3;display:flex;align-items:center;gap:5px;"
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style="flex:0 0 auto;">
              <path
                d="M12 21s7-5.5 7-11a7 7 0 1 0-14 0c0 5.5 7 11 7 11Z"
                stroke="#9A9384"
                stroke-width="1.6"
              />
              <circle cx="12" cy="10" r="2.4" stroke="#9A9384" stroke-width="1.6" />
            </svg>
            {job_location(@job)}
          </div>
        </div>

        <.job_status_chip
          status={@job.status}
          scheduling_label={scheduling_chip_label(@show_start, @place_on_tap)}
        />
      </div>

      <%!-- meta row: start time + category + due date --%>
      <div style="margin-top:11px;display:flex;align-items:center;justify-content:space-between;gap:8px;">
        <div style="display:flex;align-items:center;gap:6px;min-width:0;flex:1;">
          <span
            :if={@job.start_time}
            style="font-size:11px;font-weight:700;color:#6E675A;background:#16140E;border:1px solid rgba(52,48,37,0.5);border-radius:6px;padding:2px 6px;flex-shrink:0;letter-spacing:0.02em;"
          >
            {Calendar.strftime(@job.start_time, "%H:%M")}
          </span>
          <span :if={@job.service_category} class="jcat">
            <span class="catdot" style={"background:#{category_color(@job.service_category)}"}></span>
            {service_category_label(@job.service_category)}
          </span>
          <span :if={!@job.service_category} class="jcat" style="color:#6E675A;">—</span>
        </div>
        <span
          :if={@show_due && @job.due_by}
          style="font-size:11.5px;color:#6E675A;font-weight:600;flex-shrink:0;"
        >
          due {Calendar.strftime(@job.due_by, "%-d %b")}
        </span>
      </div>

      <%!-- live strip: on-site crew summary + leave link --%>
      <div :if={@job.status == :in_progress && @org_members != []} class="live-strip">
        <span class="lbl">{live_strip_label(@job, @org_members)}</span>
        <.link
          navigate={~p"/manage/jobs/#{@job.id}/closeout"}
          onclick="event.stopPropagation()"
          ontouchstart=""
        >
          <button class="open" type="button" style="border:none;background:none;cursor:pointer;">
            Leave →
          </button>
        </.link>
      </div>

      <%!-- crew row: avatars for scheduled jobs when org_members provided --%>
      <% assigned_ids = member_ids(@job) %>
      <div
        :if={@job.status != :in_progress && assigned_ids != [] && @org_members != []}
        class="crewrow"
      >
        <div class="avs">
          <.member_avatar
            :for={m <- @org_members |> Enum.filter(&(&1.id in assigned_ids)) |> Enum.take(5)}
            member={m}
            size={26}
          />
        </div>
      </div>
    </div>
    """
  end

  defp scheduling_chip_label(true, _), do: "Start"
  defp scheduling_chip_label(_, true), do: "Place"
  defp scheduling_chip_label(_, _), do: "Unscheduled"

  # For :scheduling jobs: start (arrive) when shift active; navigate to schedule screen to place
  # when place_on_tap; otherwise fall through to detail navigate like any other status.
  defp card_navigate(%{status: :scheduling} = job, _return_to, _place_on_tap, true),
    do: JS.navigate(~p"/manage/jobs/#{job.id}/arrive")

  defp card_navigate(%{status: :scheduling} = job, _return_to, true, _show_start),
    do: JS.navigate(~p"/manage/schedule?place_job_id=#{job.id}")

  defp card_navigate(job, nil, _place_on_tap, _show_start), do: JS.navigate(~p"/manage/jobs/#{job.id}")

  defp card_navigate(job, return_to, _place_on_tap, _show_start),
    do: JS.navigate(~p"/manage/jobs/#{job.id}?return_to=#{return_to}")

  defp member_ids(%{staff_assignments: assignments}) when is_list(assignments), do: Enum.map(assignments, & &1.member_id)

  defp member_ids(_), do: []

  defp live_strip_label(job, org_members) do
    names =
      org_members
      |> Enum.filter(&(&1.id in member_ids(job)))
      |> Enum.take(3)
      |> Enum.map_join(" + ", &member_display_name/1)

    if names == "", do: "on the clock", else: "on the clock · #{names}"
  end

  defp member_display_name(%{user: %{first_name: f, last_name: l}}) when not is_nil(f) and not is_nil(l), do: "#{f} #{l}"

  defp member_display_name(%{user: %{first_name: f}}) when not is_nil(f), do: f
  defp member_display_name(%{user: %{email: email}}), do: to_string(email)
  defp member_display_name(_), do: "—"

  defp job_title(job) do
    cl = customer_label(job)

    base =
      if cl == "",
        do: (job.garden && (job.garden.name || "Unnamed site")) || "Unnamed job",
        else: cl

    case job do
      %{engagement: %{scope_title: t}} when is_binary(t) and t != "" -> "#{base} · #{t}"
      _ -> base
    end
  end

  defp job_location(%{garden: nil}), do: nil

  defp job_location(%{garden: g}) do
    parts = [g.name, g.zip] |> Enum.reject(&is_nil/1) |> Enum.reject(&(&1 == ""))
    if parts == [], do: nil, else: Enum.join(parts, " · ")
  end

  defp customer_label(%{engagement: nil}), do: ""
  defp customer_label(%{engagement: %{customer: nil}}), do: ""

  defp customer_label(%{engagement: %{customer: c}}) do
    if c.company_name_nickname,
      do: c.company_name_nickname,
      else: "#{c.first_name} #{c.last_name}"
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

  # ---------------------------------------------------------------------------
  # job_status_chip — renders the status pill for a job. Renders nothing for
  # :scheduled and :scheduling (callers handle action buttons for those).
  # ---------------------------------------------------------------------------

  attr :status, :atom, required: true
  attr :scheduling_label, :string, default: "Unscheduled"

  def job_status_chip(assigns) do
    ~H"""
    <span :if={@status == :in_progress} class="pill live" style="flex-shrink:0;">
      <span class="dot pulse"></span>On site
    </span>
    <span :if={@status == :scheduling} class="pill cancel" style="flex-shrink:0;">
      {@scheduling_label}
    </span>
    <span :if={@status == :completed} class="pill done" style="flex-shrink:0;">Done</span>
    <span :if={@status == :cancelled} class="pill cancel" style="flex-shrink:0;">Cancelled</span>
    """
  end

  # ---------------------------------------------------------------------------
  # job_ref_card — compact reference card used inside engagement and customer
  # screens. The caller supplies the "verb + object" title (e.g. "Delivery at
  # Oakwood"); this component appends the date/time suffix and renders
  # the accent bar, cost/price/GP row, and status pill.
  # ---------------------------------------------------------------------------

  attr :job, :any, required: true
  attr :title, :string, required: true
  attr :navigate, :string, required: true
  attr :currency, :atom, default: :cad

  def job_ref_card(assigns) do
    ~H"""
    <% {cost, price} = ref_cost_price(@job) %>
    <% gp = Decimal.sub(price, cost) %>
    <div class="jcard" phx-click={JS.navigate(@navigate)} ontouchstart="">
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
        <p style="font-size:14px;font-weight:600;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;min-width:0;">
          {ref_full_title(@title, @job)}
        </p>
        <span
          :if={@job.status != :scheduled}
          class={"#{ref_pill_class(@job.status)} pill"}
          style="flex-shrink:0;"
        >
          {ref_status_label(@job.status)}
        </span>
      </div>
      <div style="margin-top:4px;display:flex;align-items:center;gap:10px;">
        <span style="font-size:11.5px;font-weight:600;color:#E87E7E;">
          {format_currency(@currency, cost)}
        </span>
        <span style="font-size:11.5px;font-weight:600;color:#DB9258;">
          {format_currency(@currency, price)}
        </span>
        <span style="font-size:11.5px;font-weight:700;color:#54B57E;">
          {format_currency(@currency, gp)}
        </span>
      </div>
    </div>
    """
  end

  defp ref_full_title(title, %{scheduled_for: date, start_time: time}) when not is_nil(date) and not is_nil(time),
    do: "#{title} on #{Calendar.strftime(date, "%-d %b")} at #{Calendar.strftime(time, "%-H:%M")}"

  defp ref_full_title(title, %{scheduled_for: date}) when not is_nil(date),
    do: "#{title} on #{Calendar.strftime(date, "%-d %b")}"

  defp ref_full_title(title, %{due_by: date}) when not is_nil(date),
    do: "#{title} by #{Calendar.strftime(date, "%-d %b")}"

  defp ref_full_title(title, _), do: title

  defp ref_cost_price(%{materials: materials}) when is_list(materials) do
    Enum.reduce(materials, {Decimal.new(0), Decimal.new(0)}, fn m, {ca, pa} ->
      qty = m.quantity || Decimal.new(0)
      cost = if m.cost, do: Decimal.mult(qty, m.cost), else: Decimal.new(0)
      price = if m.price, do: Decimal.mult(qty, m.price), else: Decimal.new(0)
      {Decimal.add(ca, cost), Decimal.add(pa, price)}
    end)
  end

  defp ref_cost_price(_), do: {Decimal.new(0), Decimal.new(0)}

  defp ref_pill_class(:in_progress), do: "live"
  defp ref_pill_class(:scheduling), do: "cancel"
  defp ref_pill_class(:completed), do: "done"
  defp ref_pill_class(:cancelled), do: "cancel"
  defp ref_pill_class(_), do: "sched"

  defp ref_status_label(:in_progress), do: "On site"
  defp ref_status_label(:scheduling), do: "Place"
  defp ref_status_label(:completed), do: "Done"
  defp ref_status_label(:cancelled), do: "Cancelled"
  defp ref_status_label(s), do: Phoenix.Naming.humanize(s)
end
