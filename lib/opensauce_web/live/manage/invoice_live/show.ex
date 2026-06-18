defmodule OpenSauceWeb.InvoiceLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import Ash.Query

  alias OpenSauce.CRM
  alias OpenSauce.Work

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:100px;">
      <%!-- top bar --%>
      <div style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;">
        <.link navigate={~p"/manage/invoices"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </button>
        </.link>
        <div style="flex:1;min-width:0;">
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:19px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
            {customer_name(@invoice)}
          </h1>
          <p style="font-size:12px;color:#6E675A;margin-top:1px;font-family:monospace;">{@invoice.reference}</p>
        </div>
        <span style={"#{status_badge_style(@invoice.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
          {status_label(@invoice.status)}
        </span>
      </div>

      <%!-- amount + dates --%>
      <div style="padding:0 16px 16px;">
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:16px;">
          <p style="font-size:30px;font-weight:700;font-family:'Bricolage Grotesque',sans-serif;letter-spacing:-0.02em;color:#F4EFE2;">
            {format_money(@organisation.currency, @invoice.amount)}
          </p>
          <div style="display:flex;gap:16px;margin-top:10px;">
            <div>
              <p style="font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
                Issued
              </p>
              <p style="font-size:13px;color:#F4EFE2;margin-top:2px;">{format_date(@invoice.issued_on)}</p>
            </div>
            <div :if={@invoice.due_on}>
              <p style="font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
                Due
              </p>
              <p style="font-size:13px;color:#F4EFE2;margin-top:2px;">{format_date(@invoice.due_on)}</p>
            </div>
          </div>
          <div :if={@invoice.notes} style="margin-top:12px;padding-top:12px;border-top:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@invoice.notes}</p>
          </div>
        </div>
      </div>

      <%!-- engagement link --%>
      <div :if={@invoice.engagement} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          Engagement
        </p>
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;">
          <p style="font-size:14px;color:#F4EFE2;">
            {@invoice.engagement.scope_description || Atom.to_string(@invoice.engagement.status)}
          </p>
        </div>
      </div>

      <%!-- linked jobs --%>
      <div style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          Jobs ({length(@jobs)})
        </p>
        <div :if={@jobs == []} style="padding:16px 0;text-align:center;">
          <p style="font-size:13px;color:#6E675A;">No jobs linked to this invoice.</p>
        </div>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <div
            :for={job <- @jobs}
            style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between;"
          >
            <div>
              <p style="font-size:14px;font-weight:600;color:#F4EFE2;">{job_label(job)}</p>
              <p style="font-size:12px;color:#9A9384;margin-top:2px;">{format_date(job.scheduled_for)}</p>
            </div>
            <div style="display:flex;align-items:center;gap:8px;">
              <span style={"#{job_status_style(job.status)}border-radius:20px;padding:3px 8px;font-size:11px;font-weight:600;"}>
                {job.status}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- sticky action buttons --%>
      <div
        :if={@invoice.status in [:draft, :sent]}
        style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:12px 16px;display:flex;gap:10px;"
      >
        <button
          :if={@invoice.status == :draft}
          type="button"
          phx-click="mark_sent"
          ontouchstart=""
          style="flex:1;background:rgba(90,180,216,0.15);border:1px solid rgba(90,180,216,0.3);border-radius:12px;padding:12px;font-size:14px;font-weight:600;color:#5AB4D8;cursor:pointer;"
        >
          Mark Sent
        </button>
        <button
          type="button"
          phx-click="mark_paid"
          ontouchstart=""
          style="flex:1;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
        >
          Mark Paid
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    member = socket.assigns.current_member
    invoice = load_invoice(id, member)

    jobs =
      Work.Job
      |> filter(invoice_id == ^id)
      |> Ash.read!(actor: member, tenant: member.organisation_id)

    socket =
      socket
      |> assign(:invoice, invoice)
      |> assign(:jobs, jobs)
      |> assign(:page_title, "Invoice #{invoice.reference}")
      |> assign(:main_bg, "bg-[#16140E]")

    {:noreply, socket}
  end

  @impl true
  def handle_event("mark_paid", _params, socket) do
    member = socket.assigns.current_member
    {:ok, _} = CRM.mark_invoice_paid(socket.assigns.invoice, actor: member, tenant: member.organisation_id)
    {:noreply, assign(socket, :invoice, load_invoice(socket.assigns.invoice.id, member))}
  end

  @impl true
  def handle_event("mark_sent", _params, socket) do
    member = socket.assigns.current_member
    {:ok, _} = CRM.mark_invoice_sent(socket.assigns.invoice, actor: member, tenant: member.organisation_id)
    {:noreply, assign(socket, :invoice, load_invoice(socket.assigns.invoice.id, member))}
  end

  defp load_invoice(id, member) do
    CRM.get_invoice_by_id!(id,
      actor: member,
      tenant: member.organisation_id,
      load: [:customer, :engagement]
    )
  end

  defp customer_name(%{customer: %{first_name: f, last_name: l}}), do: "#{f} #{l}"
  defp customer_name(_), do: "Unknown customer"

  defp job_label(job) do
    cat = job.service_category || job.type
    cat |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp status_label(:draft), do: "draft"
  defp status_label(:sent), do: "sent"
  defp status_label(:paid), do: "paid"
  defp status_label(:void), do: "void"
  defp status_label(s), do: to_string(s)

  defp status_badge_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:sent), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_badge_style(:paid), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:void), do: "background:rgba(232,126,126,0.15);color:#E87E7E;"
  defp status_badge_style(_), do: "background:rgba(154,147,132,0.15);color:#9A9384;"

  defp job_status_style(:completed), do: "background:rgba(84,181,126,0.12);color:#54B57E;"
  defp job_status_style(:in_progress), do: "background:rgba(90,180,216,0.12);color:#5AB4D8;"
  defp job_status_style(:scheduled), do: "background:rgba(154,147,132,0.12);color:#9A9384;"
  defp job_status_style(:cancelled), do: "background:rgba(232,126,126,0.12);color:#E87E7E;"
  defp job_status_style(_), do: "background:rgba(154,147,132,0.12);color:#9A9384;"
end
