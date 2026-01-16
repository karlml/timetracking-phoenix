defmodule TimetrackingPhoenixWeb.ReportLive.Index do
  use TimetrackingPhoenixWeb, :live_view

  alias TimetrackingPhoenix.{Projects, TimeEntries}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    projects = Projects.list_user_projects(user)
    
    # Default to current month
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    end_of_month = Date.end_of_month(today)

    socket = socket
    |> assign(:projects, projects)
    |> assign(:selected_project_id, nil)
    |> assign(:report_data, nil)
    |> assign(:page_title, "Reports")
    |> assign(:date_from, start_of_month)
    |> assign(:date_to, end_of_month)
    |> assign(:date_preset, "this_month")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_project", %{"project_id" => project_id}, socket) do
    project_id = String.to_integer(project_id)
    socket = assign(socket, :selected_project_id, project_id)
    {:noreply, generate_report(socket)}
  end

  @impl true
  def handle_event("update_dates", %{"date_from" => date_from, "date_to" => date_to}, socket) do
    {:ok, from} = Date.from_iso8601(date_from)
    {:ok, to} = Date.from_iso8601(date_to)
    
    socket = socket
    |> assign(:date_from, from)
    |> assign(:date_to, to)
    |> assign(:date_preset, "custom")
    
    {:noreply, generate_report(socket)}
  end

  @impl true
  def handle_event("set_preset", %{"preset" => preset}, socket) do
    today = Date.utc_today()
    
    {from, to} = case preset do
      "this_month" ->
        {Date.beginning_of_month(today), Date.end_of_month(today)}
      
      "last_month" ->
        last_month = Date.add(Date.beginning_of_month(today), -1)
        {Date.beginning_of_month(last_month), Date.end_of_month(last_month)}
      
      "this_quarter" ->
        quarter_start = quarter_start_date(today)
        {quarter_start, Date.add(Date.add(quarter_start, 90), -1)}
      
      "last_quarter" ->
        this_quarter = quarter_start_date(today)
        last_quarter_start = Date.add(this_quarter, -90)
        {last_quarter_start, Date.add(this_quarter, -1)}
      
      "this_year" ->
        {Date.new!(today.year, 1, 1), Date.new!(today.year, 12, 31)}
      
      "all_time" ->
        {Date.new!(2000, 1, 1), today}
      
      _ ->
        {Date.beginning_of_month(today), Date.end_of_month(today)}
    end
    
    socket = socket
    |> assign(:date_from, from)
    |> assign(:date_to, to)
    |> assign(:date_preset, preset)
    
    {:noreply, generate_report(socket)}
  end

  defp quarter_start_date(date) do
    quarter = div(date.month - 1, 3)
    month = quarter * 3 + 1
    Date.new!(date.year, month, 1)
  end

  defp generate_report(socket) do
    if socket.assigns.selected_project_id do
      project = Projects.get_project_with_members!(socket.assigns.selected_project_id)
      entries = TimeEntries.list_project_time_entries_in_range(
        project, 
        socket.assigns.date_from, 
        socket.assigns.date_to
      )

      # Build maps of user_id -> hourly_rate and user_id -> currency from project members
      # Rates are now per-project only (no user default_rate)
      project_currency = project.currency || "USD"
      {member_rates, member_currencies} = project.project_members
      |> Enum.reduce({%{}, %{}}, fn pm, {rates_acc, currencies_acc} ->
        rate = pm.hourly_rate || project.hourly_rate || Decimal.new(0)
        currency = pm.currency || project_currency
        rates_acc = Map.put(rates_acc, pm.user_id, rate)
        currencies_acc = Map.put(currencies_acc, pm.user_id, currency)
        {rates_acc, currencies_acc}
      end)

      # Default rate and currency for users not in project_members (use project settings)
      default_rate = project.hourly_rate || Decimal.new(0)
      default_currency = project_currency

      # Calculate totals using developer-specific rates (grouped by currency)
      # Note: We'll calculate totals per currency since mixing currencies doesn't make sense
      {total_hours, billable_by_currency} = entries
      |> Enum.reduce({Decimal.new(0), %{}}, fn entry, {hours_acc, billable_acc} ->
        rate = Map.get(member_rates, entry.user_id, default_rate)
        currency = Map.get(member_currencies, entry.user_id, default_currency)
        entry_billable = Decimal.mult(entry.hours, rate)
        billable_acc = Map.update(billable_acc, currency, entry_billable, fn existing -> Decimal.add(existing, entry_billable) end)
        {Decimal.add(hours_acc, entry.hours), billable_acc}
      end)

      # Group entries by user with their rates and currencies
      entries_by_user = Enum.group_by(entries, fn e -> 
        if e.user, do: {e.user_id, "#{e.user.first_name} #{e.user.last_name}"}, else: {nil, "Unknown"}
      end)

      user_summaries = Enum.map(entries_by_user, fn {{user_id, name}, user_entries} ->
        hours = Enum.reduce(user_entries, Decimal.new(0), fn e, acc -> Decimal.add(acc, e.hours) end)
        rate = Map.get(member_rates, user_id, default_rate)
        currency = Map.get(member_currencies, user_id, default_currency)
        amount = Decimal.mult(hours, rate)
        %{name: name, hours: hours, entries: length(user_entries), rate: rate, currency: currency, amount: amount, user_id: user_id}
      end)
      |> Enum.sort_by(& &1.name)

      # Group entries by date for daily breakdown
      entries_by_date = entries
      |> Enum.group_by(& &1.date)
      |> Enum.sort_by(fn {date, _} -> date end, {:desc, Date})
      |> Enum.map(fn {date, date_entries} ->
        hours = Enum.reduce(date_entries, Decimal.new(0), fn e, acc -> Decimal.add(acc, e.hours) end)
        # Group amounts by currency
        amounts_by_currency = Enum.reduce(date_entries, %{}, fn e, acc ->
          rate = Map.get(member_rates, e.user_id, default_rate)
          currency = Map.get(member_currencies, e.user_id, default_currency)
          amount = Decimal.mult(e.hours, rate)
          Map.update(acc, currency, amount, fn existing -> Decimal.add(existing, amount) end)
        end)
        %{date: date, hours: hours, entries: date_entries, amounts_by_currency: amounts_by_currency}
      end)

      report_data = %{
        project: project,
        entries: entries,
        total_hours: total_hours,
        billable_by_currency: billable_by_currency,
        user_summaries: user_summaries,
        entries_by_date: entries_by_date,
        member_rates: member_rates,
        member_currencies: member_currencies,
        default_rate: default_rate,
        default_currency: default_currency
      }

      assign(socket, :report_data, report_data)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reports">
      <div class="mb-12">
        <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2">Reports</h1>
        <p class="text-lg font-body text-[#94A3B8]">Generate reports for client billing</p>
      </div>

      <!-- Date Range Selection -->
      <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-6 hover:border-[#F7931A]/50 transition-all duration-300">
        <h2 class="text-xl font-heading font-semibold text-white mb-6">Date Range</h2>
        
        <!-- Preset Buttons -->
        <div class="flex flex-wrap gap-2 mb-6">
          <button 
            phx-click="set_preset" 
            phx-value-preset="this_month"
            class={"px-4 py-2 rounded-lg text-sm font-mono uppercase tracking-wider transition-all duration-200 #{if @date_preset == "this_month", do: "bg-gradient-to-r from-[#EA580C] to-[#F7931A] text-white shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]", else: "bg-white/5 text-[#94A3B8] border border-white/10 hover:border-white/20 hover:text-white"}"}
          >
            This Month
          </button>
          <button 
            phx-click="set_preset" 
            phx-value-preset="last_month"
            class={"px-4 py-2 rounded-lg text-sm font-mono uppercase tracking-wider transition-all duration-200 #{if @date_preset == "last_month", do: "bg-gradient-to-r from-[#EA580C] to-[#F7931A] text-white shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]", else: "bg-white/5 text-[#94A3B8] border border-white/10 hover:border-white/20 hover:text-white"}"}
          >
            Last Month
          </button>
          <button 
            phx-click="set_preset" 
            phx-value-preset="this_quarter"
            class={"px-4 py-2 rounded-lg text-sm font-mono uppercase tracking-wider transition-all duration-200 #{if @date_preset == "this_quarter", do: "bg-gradient-to-r from-[#EA580C] to-[#F7931A] text-white shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]", else: "bg-white/5 text-[#94A3B8] border border-white/10 hover:border-white/20 hover:text-white"}"}
          >
            This Quarter
          </button>
          <button 
            phx-click="set_preset" 
            phx-value-preset="last_quarter"
            class={"px-4 py-2 rounded-lg text-sm font-mono uppercase tracking-wider transition-all duration-200 #{if @date_preset == "last_quarter", do: "bg-gradient-to-r from-[#EA580C] to-[#F7931A] text-white shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]", else: "bg-white/5 text-[#94A3B8] border border-white/10 hover:border-white/20 hover:text-white"}"}
          >
            Last Quarter
          </button>
          <button 
            phx-click="set_preset" 
            phx-value-preset="this_year"
            class={"px-4 py-2 rounded-lg text-sm font-mono uppercase tracking-wider transition-all duration-200 #{if @date_preset == "this_year", do: "bg-gradient-to-r from-[#EA580C] to-[#F7931A] text-white shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]", else: "bg-white/5 text-[#94A3B8] border border-white/10 hover:border-white/20 hover:text-white"}"}
          >
            This Year
          </button>
          <button 
            phx-click="set_preset" 
            phx-value-preset="all_time"
            class={"px-4 py-2 rounded-lg text-sm font-mono uppercase tracking-wider transition-all duration-200 #{if @date_preset == "all_time", do: "bg-gradient-to-r from-[#EA580C] to-[#F7931A] text-white shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]", else: "bg-white/5 text-[#94A3B8] border border-white/10 hover:border-white/20 hover:text-white"}"}
          >
            All Time
          </button>
        </div>

        <!-- Custom Date Inputs -->
        <form phx-change="update_dates" class="flex flex-wrap gap-4 items-end">
          <div>
            <TimetrackingPhoenixWeb.CoreComponents.label for="date_from">From</TimetrackingPhoenixWeb.CoreComponents.label>
            <input 
              type="date" 
              name="date_from" 
              id="date_from"
              value={@date_from}
              class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200"
            />
          </div>
          <div>
            <TimetrackingPhoenixWeb.CoreComponents.label for="date_to">To</TimetrackingPhoenixWeb.CoreComponents.label>
            <input 
              type="date" 
              name="date_to" 
              id="date_to"
              value={@date_to}
              class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200"
            />
          </div>
          <div class="text-sm font-mono text-[#94A3B8] py-2">
            <%= format_date_range(@date_from, @date_to) %>
          </div>
        </form>
      </div>

      <!-- Project Selection -->
      <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-6 hover:border-[#F7931A]/50 transition-all duration-300">
        <h2 class="text-xl font-heading font-semibold text-white mb-6">Select Project</h2>
        <%= if Enum.empty?(@projects) do %>
          <p class="text-[#94A3B8] font-body">No projects available. Create a project first.</p>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <%= for project <- @projects do %>
              <button 
                phx-click="select_project" 
                phx-value-project_id={project.id}
                class={"p-4 rounded-xl border-2 text-left transition-all duration-200 #{if @selected_project_id == project.id, do: "border-[#F7931A] bg-[#F7931A]/10 shadow-[0_0_20px_-5px_rgba(247,147,26,0.3)]", else: "border-white/10 bg-black/50 hover:border-white/20"}"}
              >
                <div class="font-heading font-semibold text-white"><%= project.name %></div>
                <div class="text-sm font-body text-[#94A3B8] mt-1"><%= project.client_name || "No client" %></div>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Report Display -->
      <%= if @report_data do %>
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl overflow-hidden hover:border-[#F7931A]/50 transition-all duration-300">
          <div class="px-8 py-6 border-b border-white/10 flex flex-wrap justify-between items-center gap-4">
            <div>
              <h2 class="text-xl font-heading font-semibold text-white"><%= @report_data.project.name %> Report</h2>
              <p class="text-sm font-body text-[#94A3B8] mt-1">
                Client: <%= @report_data.project.client_name || "N/A" %> • 
                <%= format_date_range(@date_from, @date_to) %>
              </p>
            </div>
            <div class="flex gap-2">
              <a 
                href={"/reports/export/#{@report_data.project.id}?from=#{Date.to_string(@date_from)}&to=#{Date.to_string(@date_to)}"} 
                class="inline-flex items-center justify-center px-6 py-3 rounded-full border-2 border-white/20 hover:border-white hover:bg-white/10 text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                Export CSV
              </a>
            </div>
          </div>

          <!-- Summary Cards -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 p-8 border-b border-white/10">
            <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
              <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Total Hours</p>
              <p class="text-3xl font-mono font-bold text-white"><%= Decimal.round(@report_data.total_hours, 2) %></p>
            </div>
            <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
              <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Team Members</p>
              <p class="text-3xl font-mono font-bold text-[#F7931A]"><%= length(@report_data.user_summaries) %></p>
              <p class="text-xs font-body text-[#94A3B8] mt-2">With time entries</p>
            </div>
            <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
              <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Total Amount</p>
              <div class="space-y-1">
                <%= for {currency, amount} <- Enum.sort(@report_data.billable_by_currency) do %>
                  <p class="text-2xl font-mono font-bold text-[#FFD600]"><%= currency %> <%= Decimal.round(amount, 2) %></p>
                <% end %>
                <%= if Enum.empty?(@report_data.billable_by_currency) do %>
                  <p class="text-2xl font-mono font-bold text-[#94A3B8]">—</p>
                <% end %>
              </div>
            </div>
            <div class="group relative bg-[#030304] border border-white/10 rounded-xl p-6 hover:border-[#F7931A]/50 transition-all duration-300">
              <p class="text-sm font-mono uppercase tracking-wider text-[#94A3B8] mb-2">Time Entries</p>
              <p class="text-3xl font-mono font-bold text-white"><%= length(@report_data.entries) %></p>
            </div>
          </div>

          <!-- User Summary -->
          <%= if length(@report_data.user_summaries) > 0 do %>
            <div class="p-8 border-b border-white/10">
              <h3 class="text-lg font-heading font-semibold text-white mb-6">Hours by Team Member</h3>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-white/10">
                  <thead class="bg-[#030304]">
                    <tr>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Developer</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Hours</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Rate</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Currency</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Amount</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Entries</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-white/10">
                    <%= for summary <- @report_data.user_summaries do %>
                      <tr class="hover:bg-white/5 transition-colors">
                        <td class="px-4 py-3 whitespace-nowrap font-body font-medium text-white"><%= summary.name %></td>
                        <td class="px-4 py-3 whitespace-nowrap font-mono text-white"><%= Decimal.round(summary.hours, 2) %></td>
                        <td class="px-4 py-3 whitespace-nowrap font-mono text-[#94A3B8]">
                          <%= Decimal.round(summary.rate, 2) %>/hr
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap font-mono text-[#F7931A]"><%= summary.currency %></td>
                        <td class="px-4 py-3 whitespace-nowrap font-mono font-semibold text-[#FFD600]"><%= summary.currency %> <%= Decimal.round(summary.amount, 2) %></td>
                        <td class="px-4 py-3 whitespace-nowrap font-mono text-[#94A3B8]"><%= summary.entries %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          <% end %>

          <!-- Daily Breakdown -->
          <%= if length(@report_data.entries_by_date) > 0 do %>
            <div class="p-8 border-b border-white/10">
              <h3 class="text-lg font-heading font-semibold text-white mb-6">Daily Breakdown</h3>
              <div class="space-y-2">
                <%= for day <- @report_data.entries_by_date do %>
                  <div class="p-4 bg-[#030304] border border-white/10 rounded-xl hover:border-[#F7931A]/50 transition-all duration-200">
                    <div class="flex justify-between items-center mb-2">
                      <div>
                        <span class="font-body font-medium text-white"><%= Calendar.strftime(day.date, "%A, %B %d, %Y") %></span>
                        <span class="text-sm font-body text-[#94A3B8] ml-2">(<%= length(day.entries) %> entries)</span>
                      </div>
                      <span class="font-mono font-semibold text-[#F7931A]"><%= Decimal.round(day.hours, 2) %> hrs</span>
                    </div>
                    <div class="flex flex-wrap gap-2 mt-2">
                      <%= for {currency, amount} <- Enum.sort(day.amounts_by_currency) do %>
                        <span class="text-sm font-mono text-[#FFD600]"><%= currency %> <%= Decimal.round(amount, 2) %></span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Detailed Entries -->
          <div class="p-8">
            <h3 class="text-lg font-heading font-semibold text-white mb-6">Time Entry Details</h3>
            <%= if Enum.empty?(@report_data.entries) do %>
              <p class="text-[#94A3B8] text-center py-8 font-body">No time entries for this project in the selected date range.</p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-white/10">
                  <thead class="bg-[#030304]">
                    <tr>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Date</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">User</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Hours</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Rate</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Currency</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Amount</th>
                      <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Description</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-white/10">
                    <%= for entry <- @report_data.entries do %>
                      <% entry_rate = Map.get(@report_data.member_rates, entry.user_id, @report_data.default_rate) %>
                      <% entry_currency = Map.get(@report_data.member_currencies, entry.user_id, @report_data.default_currency) %>
                      <tr class="hover:bg-white/5 transition-colors">
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-mono text-white"><%= entry.date %></td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-body text-[#94A3B8]">
                          <%= if entry.user, do: "#{entry.user.first_name} #{entry.user.last_name}", else: "—" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-mono text-[#F7931A]"><%= Decimal.round(entry.hours, 2) %></td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-mono text-[#94A3B8]">
                          <%= Decimal.round(entry_rate, 2) %>/hr
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-mono text-[#F7931A]"><%= entry_currency %></td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-mono font-semibold text-[#FFD600]">
                          <%= entry_currency %> <%= Decimal.round(Decimal.mult(entry.hours, entry_rate), 2) %>
                        </td>
                        <td class="px-4 py-3 text-sm font-body text-[#94A3B8] max-w-md truncate"><%= entry.description || "—" %></td>
                      </tr>
                    <% end %>
                  </tbody>
                  <tfoot class="bg-[#030304] border-t border-white/10">
                    <tr class="font-semibold">
                      <td class="px-4 py-3 text-sm font-mono text-white" colspan="3">Total</td>
                      <td class="px-4 py-3 text-sm font-mono text-[#94A3B8]" colspan="2">
                        <%= for {currency, amount} <- Enum.sort(@report_data.billable_by_currency) do %>
                          <span class="mr-4"><%= currency %> <%= Decimal.round(amount, 2) %></span>
                        <% end %>
                      </td>
                      <td class="px-4 py-3 text-sm font-mono text-[#F7931A]"><%= Decimal.round(@report_data.total_hours, 2) %> hrs</td>
                      <td></td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-12 text-center hover:border-[#F7931A]/50 transition-all duration-300">
          <svg class="h-16 w-16 text-[#94A3B8] mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
          </svg>
          <p class="text-[#94A3B8] font-body">Select a project above to generate a report</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_date_range(from, to) do
    "#{Calendar.strftime(from, "%b %d, %Y")} - #{Calendar.strftime(to, "%b %d, %Y")}"
  end
end
