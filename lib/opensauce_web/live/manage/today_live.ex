defmodule OpenSauceWeb.TodayLive do
  use OpenSauceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Today")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-16 text-center">
      <p class="text-stone-400 text-sm">Today's dashboard coming soon.</p>
    </div>
    """
  end
end
