defmodule TimetrackingPhoenixWeb.ProjectLive.Show do
  use TimetrackingPhoenixWeb, :live_view

  alias TimetrackingPhoenix.{Projects, TimeEntries}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    project = Projects.get_project!(id)
    entries = TimeEntries.list_project_time_entries(project)
    
    total_hours = entries
    |> Enum.reduce(Decimal.new(0), fn entry, acc ->
      Decimal.add(acc, entry.hours)
    end)

    total_billable = if project.hourly_rate do
      Decimal.mult(total_hours, project.hourly_rate)
    else
      Decimal.new(0)
    end

    socket = socket
    |> assign(:page_title, project.name)
    |> assign(:project, project)
    |> assign(:entries, entries)
    |> assign(:total_hours, total_hours)
    |> assign(:total_billable, total_billable)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="project-show">
      <div class="mb-6">
        <.link navigate={~p"/projects"} class="text-[#F7931A] hover:text-[#FFD600] text-sm font-heading font-semibold transition-colors inline-flex items-center gap-2">
          ← Back to Projects
        </.link>
      </div>

      <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-8 hover:border-[#F7931A]/50 transition-all duration-300">
        <div class="flex justify-between items-start mb-6">
          <div>
            <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2"><%= @project.name %></h1>
            <p class="text-lg font-body text-[#94A3B8]"><%= @project.client_name || "No client" %></p>
          </div>
          <span class={"px-4 py-2 text-sm font-mono uppercase tracking-wider rounded-full #{if @project.status == "active", do: "bg-[#F7931A]/20 text-[#F7931A] border border-[#F7931A]/50", else: "bg-white/10 text-[#94A3B8] border border-white/10"}"}>
            <%= @project.status %>
          </span>
        </div>

        <p class="text-base font-body text-[#94A3B8] mb-8"><%= @project.description || "No description" %></p>

        <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
          <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
            <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Total Hours</p>
            <p class="text-3xl font-mono font-bold text-white"><%= Decimal.round(@total_hours, 2) %></p>
          </div>
          <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
            <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Total Billable</p>
            <p class="text-3xl font-mono font-bold text-[#FFD600]">$<%= Decimal.round(@total_billable, 2) %></p>
          </div>
          <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
            <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Hourly Rate</p>
            <p class="text-3xl font-mono font-bold text-[#F7931A]">$<%= @project.hourly_rate || "0" %></p>
          </div>
          <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
            <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Budget Hours</p>
            <p class="text-3xl font-mono font-bold text-white"><%= @project.budget_hours || "∞" %></p>
          </div>
        </div>
      </div>

      <div class="bg-[#0F1115] border border-white/10 rounded-2xl overflow-hidden hover:border-[#F7931A]/50 transition-all duration-300">
        <div class="px-8 py-6 border-b border-white/10 flex justify-between items-center">
          <h2 class="text-xl font-heading font-semibold text-white">Time Entries</h2>
          <.link navigate={~p"/time_entries/new"} class="inline-flex items-center justify-center px-4 py-2 rounded-full bg-gradient-to-r from-[#EA580C] to-[#F7931A] hover:scale-105 hover:shadow-[0_0_30px_-5px_rgba(247,147,26,0.6)] text-xs font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300 shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]">
            + Add Entry
          </.link>
        </div>

        <%= if Enum.empty?(@entries) do %>
          <div class="p-12 text-center">
            <p class="text-[#94A3B8] font-body">No time entries for this project yet.</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-white/10">
              <thead class="bg-[#030304]">
                <tr>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Date</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Hours</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Description</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">User</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/10">
                <%= for entry <- @entries do %>
                  <tr class="hover:bg-white/5 transition-colors">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-white"><%= entry.date %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-mono font-semibold text-[#F7931A]"><%= Decimal.round(entry.hours, 2) %></td>
                    <td class="px-6 py-4 text-sm font-body text-[#94A3B8]"><%= entry.description || "—" %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-body text-[#94A3B8]">
                      <%= if entry.user, do: "#{entry.user.first_name} #{entry.user.last_name}", else: "—" %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
