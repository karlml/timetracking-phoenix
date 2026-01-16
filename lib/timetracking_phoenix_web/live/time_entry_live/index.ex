defmodule TimetrackingPhoenixWeb.TimeEntryLive.Index do
  use TimetrackingPhoenixWeb, :live_view
  import TimetrackingPhoenixWeb.CoreComponents

  alias TimetrackingPhoenix.{TimeEntries, Projects, Accounts}
  alias TimetrackingPhoenix.TimeEntries.TimeEntry

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    is_admin = user.current_role == "admin"

    entries = if is_admin do
      TimeEntries.list_managed_project_time_entries(user)
    else
      TimeEntries.list_user_time_entries(user)
    end

    projects = Projects.list_user_projects(user)
    
    # Load developers for admin user selector
    developers = if is_admin, do: Accounts.list_developers(), else: []
    
    # Generate week dates for table view
    today = Date.utc_today()
    week_start = Date.beginning_of_week(today, :monday)
    week_dates = Enum.map(0..6, fn i -> Date.add(week_start, i) end)

    socket = socket
    |> assign(:entries, entries)
    |> assign(:projects, projects)
    |> assign(:developers, developers)
    |> assign(:is_admin, is_admin)
    |> assign(:page_title, "Time Entries")
    |> assign(:view_mode, "list")  # "list" or "table"
    |> assign(:week_dates, week_dates)
    |> assign(:week_start, week_start)
    |> assign(:selected_project_id, nil)
    |> assign(:week_entries, %{})
    |> assign(:last_list_project_id, nil)  # Remember last project for List view form

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_view", %{"mode" => mode}, socket) do
    socket = assign(socket, :view_mode, mode)
    
    socket = if mode == "table" && socket.assigns.selected_project_id do
      load_week_entries(socket)
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  def handle_event("change_week", %{"direction" => direction}, socket) do
    offset = if direction == "prev", do: -7, else: 7
    new_start = Date.add(socket.assigns.week_start, offset)
    week_dates = Enum.map(0..6, fn i -> Date.add(new_start, i) end)
    
    socket = socket
    |> assign(:week_start, new_start)
    |> assign(:week_dates, week_dates)
    |> load_week_entries()
    
    {:noreply, socket}
  end
  
  def handle_event("select_project", params, socket) do
    project_id = params["project_id"] || params["value"] || ""
    project_id = if project_id == "", do: nil, else: String.to_integer(project_id)
    
    socket = socket
    |> assign(:selected_project_id, project_id)
    |> load_week_entries()
    
    {:noreply, socket}
  end
  
  # Remember project selection in List view form
  def handle_event("remember_list_project", %{"new_entry" => %{"project_id" => project_id}}, socket) do
    project_id = if project_id == "", do: nil, else: String.to_integer(project_id)
    {:noreply, assign(socket, :last_list_project_id, project_id)}
  end
  
  def handle_event("save_week_entry", %{"date" => date, "hours" => hours}, socket) do
    project_id = socket.assigns.selected_project_id
    user_id = socket.assigns.current_user.id
    
    hours = if hours == "" || hours == "0", do: nil, else: hours
    date = Date.from_iso8601!(date)
    
    existing = TimeEntries.find_entry(user_id, project_id, date)
    
    case {existing, hours} do
      {nil, nil} ->
        {:noreply, socket}
        
      {nil, hours} when not is_nil(hours) ->
        attrs = %{
          "user_id" => user_id,
          "project_id" => project_id,
          "date" => date,
          "hours" => hours
        }
        case TimeEntries.create_time_entry(attrs) do
          {:ok, _} ->
            {:noreply, socket |> load_week_entries() |> reload_all_entries() |> put_flash(:info, "Time entry saved")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to save entry")}
        end
        
      {entry, nil} ->
        TimeEntries.delete_time_entry(entry)
        {:noreply, socket |> load_week_entries() |> reload_all_entries() |> put_flash(:info, "Time entry removed")}
        
      {entry, hours} ->
        case TimeEntries.update_time_entry(entry, %{"hours" => hours}) do
          {:ok, _} ->
            {:noreply, socket |> load_week_entries() |> reload_all_entries() |> put_flash(:info, "Time entry updated")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update entry")}
        end
    end
  end

  # Inline edit for list view
  def handle_event("update_entry", %{"entry_id" => entry_id} = params, socket) do
    entry = TimeEntries.get_time_entry!(entry_id)
    
    attrs = %{
      "hours" => params["hours"],
      "description" => params["description"]
    }
    
    case TimeEntries.update_time_entry(entry, attrs) do
      {:ok, _} ->
        {:noreply, socket |> reload_all_entries()}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update entry")}
    end
  end
  
  def handle_event("save_new_entry", %{"new_entry" => entry_params}, socket) do
    user_id = if socket.assigns.is_admin && entry_params["user_id"] && entry_params["user_id"] != "" do
      entry_params["user_id"]
    else
      socket.assigns.current_user.id
    end
    
    project_id = entry_params["project_id"]
    
    attrs = %{
      "user_id" => user_id,
      "project_id" => project_id,
      "date" => entry_params["date"],
      "hours" => entry_params["hours"],
      "description" => entry_params["description"] || ""
    }
    
    case TimeEntries.create_time_entry(attrs) do
      {:ok, _} ->
        # Remember the project for next entry
        last_project_id = if project_id && project_id != "", do: String.to_integer(project_id), else: nil
        {:noreply, socket |> assign(:last_list_project_id, last_project_id) |> reload_all_entries() |> put_flash(:info, "Time entry created")}
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        {:noreply, put_flash(socket, :error, "Failed to create entry: #{inspect(errors)}")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    entry = TimeEntries.get_time_entry!(id)
    {:ok, _} = TimeEntries.delete_time_entry(entry)

    {:noreply, socket |> reload_all_entries() |> put_flash(:info, "Entry deleted")}
  end

  defp reload_entries(socket) do
    user = socket.assigns.current_user
    if socket.assigns.is_admin do
      TimeEntries.list_managed_project_time_entries(user)
    else
      TimeEntries.list_user_time_entries(user)
    end
  end
  
  defp reload_all_entries(socket) do
    assign(socket, :entries, reload_entries(socket))
  end
  
  defp load_week_entries(socket) do
    project_id = socket.assigns.selected_project_id
    user_id = socket.assigns.current_user.id
    week_dates = socket.assigns.week_dates
    
    if project_id do
      start_date = List.first(week_dates)
      end_date = List.last(week_dates)
      
      entries = TimeEntries.list_entries_for_week(user_id, project_id, start_date, end_date)
      
      week_entries = Map.new(entries, fn e -> {e.date, e} end)
      assign(socket, :week_entries, week_entries)
    else
      assign(socket, :week_entries, %{})
    end
  end
  
  defp day_name(date) do
    case Date.day_of_week(date) do
      1 -> "Mon"
      2 -> "Tue"
      3 -> "Wed"
      4 -> "Thu"
      5 -> "Fri"
      6 -> "Sat"
      7 -> "Sun"
    end
  end
  
  defp format_week_range(week_dates) do
    first = List.first(week_dates)
    last = List.last(week_dates)
    "#{Calendar.strftime(first, "%b %d")} - #{Calendar.strftime(last, "%b %d, %Y")}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="time-entries">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2">Time Entries</h1>
          <p class="text-lg font-body text-[#94A3B8]">
            <%= if @is_admin do %>
              View all time entries across all projects
            <% else %>
              Track your work hours
            <% end %>
          </p>
        </div>
        <div class="flex items-center gap-4">
          <!-- View Mode Toggle -->
          <div class="flex items-center bg-[#0F1115] border border-white/10 rounded-full p-1">
            <button phx-click="switch_view" phx-value-mode="list" class={"px-4 py-2 text-xs font-mono uppercase tracking-wider rounded-full transition-all duration-200 #{if @view_mode == "list", do: "bg-[#F7931A] text-white", else: "text-[#94A3B8] hover:text-white"}"}>
              List
            </button>
            <button phx-click="switch_view" phx-value-mode="table" class={"px-4 py-2 text-xs font-mono uppercase tracking-wider rounded-full transition-all duration-200 #{if @view_mode == "table", do: "bg-[#F7931A] text-white", else: "text-[#94A3B8] hover:text-white"}"}>
              Week
            </button>
          </div>
        </div>
      </div>

      <%= if @view_mode == "table" do %>
        <!-- Week Table View -->
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-6 mb-6">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-4">
              <button phx-click="change_week" phx-value-direction="prev" class="p-2 rounded-lg bg-black/50 border border-white/10 text-[#94A3B8] hover:text-white hover:border-[#F7931A]/50 transition-all">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
                </svg>
              </button>
              <h2 class="text-lg font-heading font-semibold text-white"><%= format_week_range(@week_dates) %></h2>
              <button phx-click="change_week" phx-value-direction="next" class="p-2 rounded-lg bg-black/50 border border-white/10 text-[#94A3B8] hover:text-white hover:border-[#F7931A]/50 transition-all">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                </svg>
              </button>
            </div>
            <form phx-change="select_project" class="flex items-center gap-3">
              <label class="text-sm font-body text-[#94A3B8]">Project:</label>
              <select name="project_id" id="week-project-select" phx-hook="RememberProject" class="h-10 rounded-lg border border-white/10 bg-black/50 text-white text-sm font-body px-4 focus:border-[#F7931A] focus:outline-none transition-all min-w-[200px]">
                <option value="">Select a project...</option>
                <%= for project <- @projects do %>
                  <option value={project.id} selected={@selected_project_id == project.id}><%= project.name %></option>
                <% end %>
              </select>
            </form>
          </div>
          
          <%= if @selected_project_id do %>
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr>
                    <%= for date <- @week_dates do %>
                      <th class={"px-3 py-3 text-center #{if Date.day_of_week(date) in [6, 7], do: "bg-white/5"}"}>
                        <div class="text-xs font-mono text-[#94A3B8] uppercase"><%= day_name(date) %></div>
                        <div class={"text-lg font-mono font-semibold #{if date == Date.utc_today(), do: "text-[#F7931A]", else: "text-white"}"}><%= date.day %></div>
                      </th>
                    <% end %>
                    <th class="px-3 py-3 text-center">
                      <div class="text-xs font-mono text-[#94A3B8] uppercase">Total</div>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <%= for date <- @week_dates do %>
                      <% entry = Map.get(@week_entries, date) %>
                      <td class={"px-2 py-3 text-center #{if Date.day_of_week(date) in [6, 7], do: "bg-white/5"}"}>
                        <form phx-change="save_week_entry" phx-debounce="500">
                          <input type="hidden" name="date" value={Date.to_iso8601(date)} />
                          <input 
                            type="number" 
                            name="hours"
                            step="0.25" 
                            min="0" 
                            max="24"
                            value={if entry, do: Decimal.to_string(entry.hours), else: ""}
                            placeholder="0"
                            class="w-16 h-12 text-center rounded-lg border border-white/10 bg-black/50 text-white text-lg font-mono focus:border-[#F7931A] focus:outline-none focus:ring-2 focus:ring-[#F7931A]/20 transition-all placeholder:text-white/20"
                          />
                        </form>
                      </td>
                    <% end %>
                    <td class="px-3 py-3 text-center">
                      <% week_total = @week_entries |> Map.values() |> Enum.reduce(Decimal.new(0), fn e, acc -> Decimal.add(acc, e.hours) end) %>
                      <div class="text-xl font-mono font-bold text-[#F7931A]"><%= Decimal.round(week_total, 2) %></div>
                      <div class="text-xs font-body text-[#94A3B8]">hours</div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p class="mt-4 text-xs font-body text-[#94A3B8]">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 inline mr-1">
                <path stroke-linecap="round" stroke-linejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
              </svg>
              Enter hours and changes save automatically.
            </p>
          <% else %>
            <div class="text-center py-12">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1" stroke="currentColor" class="w-16 h-16 mx-auto text-[#94A3B8]/50 mb-4">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" />
              </svg>
              <p class="text-[#94A3B8] font-body">Select a project to start logging hours for the week</p>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Entries List -->
      <%= if @view_mode == "list" do %>
        <!-- New Entry Form -->
        <form phx-submit="save_new_entry" class="bg-[#0F1115] border border-[#F7931A]/30 rounded-2xl p-4 mb-4">
          <div class="flex items-center gap-3 flex-wrap">
            <%= if @is_admin do %>
              <select name="new_entry[user_id]" class="h-10 rounded-lg border border-white/20 bg-black/50 text-white text-sm px-3 focus:border-[#F7931A] focus:outline-none min-w-[150px]">
                <option value="">Developer...</option>
                <%= for dev <- @developers do %>
                  <option value={dev.id}><%= dev.first_name %> <%= dev.last_name %></option>
                <% end %>
              </select>
            <% end %>
            <select name="new_entry[project_id]" id="list-project-select" phx-hook="RememberProject" phx-change="remember_list_project" required class="h-10 rounded-lg border border-white/20 bg-black/50 text-white text-sm px-3 focus:border-[#F7931A] focus:outline-none min-w-[180px]">
              <option value="">Select project...</option>
              <%= for project <- @projects do %>
                <option value={project.id} selected={@last_list_project_id == project.id}><%= project.name %></option>
              <% end %>
            </select>
            <input type="date" name="new_entry[date]" value={Date.utc_today()} required class="h-10 rounded-lg border border-white/20 bg-black/50 text-white text-sm px-3 focus:border-[#F7931A] focus:outline-none" />
            <input type="number" name="new_entry[hours]" step="0.25" min="0.25" max="24" placeholder="Hours" required class="h-10 w-20 rounded-lg border border-white/20 bg-black/50 text-white text-sm px-3 text-center font-mono focus:border-[#F7931A] focus:outline-none" />
            <input type="text" name="new_entry[description]" placeholder="Description (optional)" class="h-10 flex-1 min-w-[200px] rounded-lg border border-white/20 bg-black/50 text-white text-sm px-3 placeholder:text-white/30 focus:border-[#F7931A] focus:outline-none" />
            <button type="submit" class="h-10 px-6 rounded-lg bg-[#F7931A] hover:bg-[#FFD600] text-white text-sm font-mono uppercase tracking-wider transition-colors">
              Add Entry
            </button>
          </div>
        </form>
        
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl overflow-hidden hover:border-[#F7931A]/50 transition-all duration-300">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-white/10">
              <thead class="bg-[#030304]">
                <tr>
                  <%= if @is_admin do %>
                    <th class="px-3 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider w-40">Developer</th>
                  <% end %>
                  <th class="px-3 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider w-44">Project</th>
                  <th class="px-3 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider w-32">Date</th>
                  <th class="px-3 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider w-20">Hours</th>
                  <th class="px-3 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Description</th>
                  <th class="px-3 py-3 text-right text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider w-16"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/10">
                
                <!-- Existing Entries -->
                <%= if Enum.empty?(@entries) do %>
                  <tr>
                    <td colspan={if @is_admin, do: 6, else: 5} class="px-4 py-8 text-center text-[#94A3B8] font-body">
                      No time entries yet. Use the row above to add your first entry.
                    </td>
                  </tr>
                <% else %>
                  <%= for entry <- @entries do %>
                    <tr class="hover:bg-white/5 transition-colors group">
                      <%= if @is_admin do %>
                        <td class="px-3 py-2 text-sm font-body text-[#94A3B8]">
                          <%= if entry.user, do: "#{entry.user.first_name} #{entry.user.last_name}", else: "—" %>
                        </td>
                      <% end %>
                      <td class="px-3 py-2 text-sm font-body text-white">
                        <%= if entry.project, do: entry.project.name, else: "—" %>
                      </td>
                      <td class="px-3 py-2 text-sm font-mono text-white">
                        <%= entry.date %>
                      </td>
                      <td class="px-3 py-2">
                        <form phx-change="update_entry" phx-debounce="500">
                          <input type="hidden" name="entry_id" value={entry.id} />
                          <input 
                            type="number" 
                            name="hours" 
                            value={Decimal.to_string(entry.hours)} 
                            step="0.25" 
                            min="0" 
                            max="24" 
                            class="w-16 h-8 rounded border border-transparent bg-transparent text-[#F7931A] text-sm px-2 text-center font-mono font-semibold hover:border-white/20 focus:border-[#F7931A] focus:bg-black/50 focus:outline-none transition-all"
                          />
                        </form>
                      </td>
                      <td class="px-3 py-2">
                        <form phx-change="update_entry" phx-debounce="500">
                          <input type="hidden" name="entry_id" value={entry.id} />
                          <input 
                            type="text" 
                            name="description" 
                            value={entry.description || ""} 
                            placeholder="—"
                            class="w-full h-8 rounded border border-transparent bg-transparent text-[#94A3B8] text-sm px-2 placeholder:text-[#94A3B8]/50 hover:border-white/20 focus:border-[#F7931A] focus:bg-black/50 focus:outline-none transition-all"
                          />
                        </form>
                      </td>
                      <td class="px-3 py-2 text-right">
                        <button phx-click="delete" phx-value-id={entry.id} data-confirm="Delete this entry?" class="opacity-0 group-hover:opacity-100 p-1.5 rounded text-[#EA580C] hover:text-[#F7931A] hover:bg-white/5 transition-all">
                          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                            <path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                          </svg>
                        </button>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
