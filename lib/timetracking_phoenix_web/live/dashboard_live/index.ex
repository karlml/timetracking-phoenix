defmodule TimetrackingPhoenixWeb.DashboardLive.Index do
  use TimetrackingPhoenixWeb, :live_view

  alias TimetrackingPhoenix.{Projects, TimeEntries}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Get user's active projects
    projects = Projects.list_user_projects(user)

    # Get recent time entries
    recent_entries = TimeEntries.list_user_time_entries(user) |> Enum.take(10)

    # Calculate weekly totals
    weekly_hours = recent_entries
    |> Enum.reduce(Decimal.new(0), fn entry, acc ->
      Decimal.add(acc, entry.hours)
    end)

    # Get today's entries
    today = Date.utc_today()
    todays_entries = TimeEntries.list_user_time_entries_for_date(user, today)
    todays_hours = todays_entries
    |> Enum.reduce(Decimal.new(0), fn entry, acc ->
      Decimal.add(acc, entry.hours)
    end)

    socket = socket
    |> assign(:projects, projects)
    |> assign(:recent_entries, recent_entries)
    |> assign(:weekly_hours, weekly_hours)
    |> assign(:todays_hours, todays_hours)
    |> assign(:page_title, "Dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <div class="mb-12">
        <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2">Dashboard</h1>
        <p class="text-lg font-body text-[#94A3B8]">Welcome back, <%= @current_user.first_name %>!</p>
      </div>

      <!-- Time Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        <div class="group relative bg-[#0F1115] border border-white/10 rounded-2xl p-8 hover:-translate-y-1 hover:border-[#F7931A]/50 hover:shadow-[0_0_30px_-10px_rgba(247,147,26,0.2)] transition-all duration-300">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-[#EA580C]/20 border border-[#EA580C]/50 rounded-lg p-3 group-hover:shadow-[0_0_20px_rgba(234,88,12,0.4)] transition-all">
              <svg class="h-8 w-8 text-[#F7931A]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] truncate">Today's Hours</dt>
              <dd class="text-3xl font-mono font-bold text-white mt-1"><%= Decimal.round(@todays_hours, 2) %></dd>
            </div>
          </div>
        </div>

        <div class="group relative bg-[#0F1115] border border-white/10 rounded-2xl p-8 hover:-translate-y-1 hover:border-[#F7931A]/50 hover:shadow-[0_0_30px_-10px_rgba(247,147,26,0.2)] transition-all duration-300">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-[#EA580C]/20 border border-[#EA580C]/50 rounded-lg p-3 group-hover:shadow-[0_0_20px_rgba(234,88,12,0.4)] transition-all">
              <svg class="h-8 w-8 text-[#F7931A]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
              </svg>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] truncate">Recent Hours</dt>
              <dd class="text-3xl font-mono font-bold text-white mt-1"><%= Decimal.round(@weekly_hours, 2) %></dd>
            </div>
          </div>
        </div>

        <div class="group relative bg-[#0F1115] border border-white/10 rounded-2xl p-8 hover:-translate-y-1 hover:border-[#F7931A]/50 hover:shadow-[0_0_30px_-10px_rgba(247,147,26,0.2)] transition-all duration-300">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-[#EA580C]/20 border border-[#EA580C]/50 rounded-lg p-3 group-hover:shadow-[0_0_20px_rgba(234,88,12,0.4)] transition-all">
              <svg class="h-8 w-8 text-[#F7931A]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
              </svg>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] truncate">Active Projects</dt>
              <dd class="text-3xl font-mono font-bold text-white mt-1"><%= length(@projects) %></dd>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-12 hover:border-[#F7931A]/50 transition-all duration-300">
        <h2 class="text-xl font-heading font-semibold text-white mb-6">Quick Actions</h2>
        <div class="flex flex-wrap gap-4">
          <.link navigate={~p"/time_entries/new"} class="inline-flex items-center justify-center px-6 py-3 rounded-full bg-gradient-to-r from-[#EA580C] to-[#F7931A] hover:scale-105 hover:shadow-[0_0_30px_-5px_rgba(247,147,26,0.6)] text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300 shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]">
            Log Time Entry
          </.link>
          <.link navigate={~p"/projects"} class="inline-flex items-center justify-center px-6 py-3 rounded-full border-2 border-white/20 hover:border-white hover:bg-white/10 text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300">
            View Projects
          </.link>
          <.link navigate={~p"/reports"} class="inline-flex items-center justify-center px-6 py-3 rounded-full border-2 border-white/20 hover:border-white hover:bg-white/10 text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300">
            View Reports
          </.link>
        </div>
      </div>

      <!-- Recent Time Entries -->
      <div class="bg-[#0F1115] border border-white/10 rounded-2xl overflow-hidden hover:border-[#F7931A]/50 transition-all duration-300">
        <div class="px-8 py-6 border-b border-white/10">
          <h2 class="text-xl font-heading font-semibold text-white">Recent Time Entries</h2>
        </div>
        <div class="p-8">
          <%= if Enum.empty?(@recent_entries) do %>
            <p class="text-[#94A3B8] text-center py-12 font-body">No time entries yet.</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-white/10">
                <thead class="bg-[#030304]">
                  <tr>
                    <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Date</th>
                    <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Project</th>
                    <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Hours</th>
                    <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Description</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/10">
                  <%= for entry <- @recent_entries do %>
                    <tr class="hover:bg-white/5 transition-colors">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-white">
                        <%= entry.date %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-body text-white">
                        <%= if entry.project, do: entry.project.name, else: "N/A" %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-mono font-semibold text-[#F7931A]">
                        <%= Decimal.round(entry.hours, 2) %>
                      </td>
                      <td class="px-6 py-4 text-sm font-body text-[#94A3B8]">
                        <%= entry.description || "No description" %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
