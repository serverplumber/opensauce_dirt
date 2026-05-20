defmodule OpenSauce.Calendar.FeedGenerator do
  @moduledoc false

  alias OpenSauce.Orders

  @past_days 30
  @future_days 90

  def generate(actor) do
    now = DateTime.utc_now()
    date_start = DateTime.add(now, -@past_days, :day)
    date_end = DateTime.add(now, @future_days, :day)

    job_events = build_job_events(actor, date_start, date_end)

    to_ics(job_events)
  end

  defp build_job_events(actor, date_start, date_end) do
    case Orders.list_jobs(
           actor: actor,
           load: [:customer],
           filter: [scheduled_at_gte: date_start, scheduled_at_lte: date_end]
         ) do
      {:ok, jobs} ->
        Enum.map(jobs, &job_to_event/1)

      _ ->
        []
    end
  end

  defp job_to_event(job) do
    customer_name =
      case job do
        %{customer: %{first_name: first, last_name: last}}
        when is_binary(first) and is_binary(last) ->
          "#{first} #{last}"

        _ ->
          "Unknown"
      end

    service = job.service_type |> Atom.to_string() |> String.replace("_", " ")

    %{
      summary: "#{service} — #{customer_name}",
      dtstart: job.scheduled_at,
      dtend: job.scheduled_at,
      uid: "job-#{job.id}@opensauce",
      description: "Status: #{job.status}"
    }
  end

  defp to_ics(events) do
    lines =
      Enum.flat_map(events, fn event ->
        [
          "BEGIN:VEVENT",
          "UID:#{event.uid}",
          "SUMMARY:#{event.summary}",
          "DESCRIPTION:#{event.description}",
          "DTSTART:#{format_dt(event.dtstart)}",
          "DTEND:#{format_dt(event.dtend)}",
          "END:VEVENT"
        ]
      end)

    (["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//OpenSauce//EN"] ++ lines ++ ["END:VCALENDAR"])
    |> Enum.join("\r\n")
  end

  defp format_dt(nil), do: ""

  defp format_dt(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y%m%dT%H%M%SZ")
  end

  defp format_dt(%Date{} = d) do
    Calendar.strftime(d, "%Y%m%d")
  end
end
