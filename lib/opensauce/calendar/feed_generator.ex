defmodule OpenSauce.Calendar.FeedGenerator do
  @moduledoc """
  Generates iCalendar (.ics) feed content from orders and production batches.
  """

  alias OpenSauce.Orders

  @past_days 30
  @future_days 90

  @doc """
  Generates an iCalendar string for the given actor, including order delivery
  events and production batch events within a rolling date window.
  """
  def generate(actor) do
    now = DateTime.utc_now()
    date_start = DateTime.add(now, -@past_days, :day)
    date_end = DateTime.add(now, @future_days, :day)

    order_events = build_order_events(actor, date_start, date_end)
    batch_events = build_batch_events(actor, date_start, date_end)

    to_ics(order_events ++ batch_events)
  end

  defp build_order_events(actor, date_start, date_end) do
    case Orders.list_orders(
           %{delivery_date_start: date_start, delivery_date_end: date_end},
           actor: actor
         ) do
      {:ok, %{results: orders}} ->
        Enum.map(orders, &order_to_event/1)

      {:ok, orders} when is_list(orders) ->
        Enum.map(orders, &order_to_event/1)

      _ ->
        []
    end
  end

  defp order_to_event(order) do
    customer_name =
      case order do
        %{customer: %{first_name: first, last_name: last}}
        when is_binary(first) and is_binary(last) ->
          "#{first} #{last}"

        _ ->
          "Unknown"
      end

    %{
      summary: "Order #{order.reference} - #{customer_name}",
      dtstart: order.delivery_date,
      dtend: order.delivery_date,
      uid: "order-#{order.id}@opensauce",
      description: "Status: #{order.status}"
    }
  end

  defp build_batch_events(actor, date_start, date_end) do
    case Orders.list_production_batches(actor: actor, load: [:product]) do
      {:ok, %{results: batches}} ->
        batches |> filter_batches(date_start, date_end) |> Enum.map(&batch_to_event/1)

      {:ok, batches} when is_list(batches) ->
        batches |> filter_batches(date_start, date_end) |> Enum.map(&batch_to_event/1)

      _ ->
        []
    end
  end

  defp filter_batches(batches, date_start, date_end) do
    Enum.filter(batches, fn batch ->
      date = batch.started_at || batch.completed_at

      date != nil and
        DateTime.compare(date, date_start) != :lt and
        DateTime.compare(date, date_end) != :gt
    end)
  end

  defp batch_to_event(batch) do
    product_name =
      case batch do
        %{product: %{name: name}} when is_binary(name) -> name
        _ -> "Unknown"
      end

    dtstart = batch.started_at || batch.completed_at
    dtend = batch.completed_at || batch.started_at

    %{
      summary: "Batch #{batch.batch_code} - #{product_name}",
      dtstart: dtstart,
      dtend: dtend,
      uid: "batch-#{batch.id}@opensauce",
      description: "Status: #{batch.status}, Planned: #{batch.planned_qty}"
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
