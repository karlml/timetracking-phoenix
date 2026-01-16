defmodule TimetrackingPhoenixWeb.ProjectLive.Members do
  use TimetrackingPhoenixWeb, :live_view
  import TimetrackingPhoenixWeb.CoreComponents

  alias TimetrackingPhoenix.Projects
  alias TimetrackingPhoenix.Accounts

  @impl true
  def mount(%{"id" => project_id}, _session, socket) do
    current_user = socket.assigns.current_user

    # Only admins can manage project members
    if current_user.role != "admin" do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/projects")}
    else
      project = Projects.get_project_with_members!(project_id)
      members = Projects.list_project_members(project_id)
      developers = Accounts.list_developers()

      # Filter out developers already assigned
      assigned_user_ids = Enum.map(members, & &1.user_id)
      available_developers = Enum.filter(developers, fn d -> d.id not in assigned_user_ids end)

      {:ok,
       socket
       |> assign(:project, project)
       |> assign(:members, members)
       |> assign(:developers, available_developers)
       |> assign(:page_title, "#{project.name} - Team Members")
       |> assign(:editing_member_id, nil)
       |> assign(:show_add_form, false)}
    end
  end

  @impl true
  def handle_event("show_add_form", _params, socket) do
    {:noreply, assign(socket, :show_add_form, true)}
  end

  @impl true
  def handle_event("hide_add_form", _params, socket) do
    {:noreply, assign(socket, :show_add_form, false)}
  end

  @impl true
  def handle_event("add_member", %{"member" => member_params}, socket) do
    project_id = socket.assigns.project.id
    project = socket.assigns.project
    user_id = String.to_integer(member_params["user_id"])
    
    # Rate is required for each developer
    hourly_rate = parse_decimal(member_params["hourly_rate"])
    currency = if member_params["currency"] && member_params["currency"] != "", do: member_params["currency"], else: project.currency || "USD"

    # Validate rate is provided
    if hourly_rate == nil do
      {:noreply, put_flash(socket, :error, "Hourly rate is required")}
    else
      attrs = %{
        project_id: project_id,
        user_id: user_id,
        hourly_rate: hourly_rate,
        currency: currency,
        role: member_params["role"] || "developer"
      }

      case Projects.add_project_member(attrs) do
        {:ok, _member} ->
          {:noreply, refresh_data(socket) |> assign(:show_add_form, false) |> put_flash(:info, "Developer added to project.")}

        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          {:noreply, put_flash(socket, :error, "Error: #{inspect(errors)}")}
      end
    end
  end

  @impl true
  def handle_event("edit_member", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_member_id, String.to_integer(id))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_member_id, nil)}
  end

  @impl true
  def handle_event("update_member", %{"id" => id, "member" => member_params}, socket) do
    member = Projects.get_project_member!(id)
    
    # If currency is empty string, set to nil to use developer's default
    currency = if member_params["currency"] == "", do: nil, else: member_params["currency"]

    attrs = %{
      hourly_rate: parse_decimal(member_params["hourly_rate"]),
      currency: currency,
      role: member_params["role"]
    }

    case Projects.update_project_member(member, attrs) do
      {:ok, _member} ->
        {:noreply, refresh_data(socket) |> assign(:editing_member_id, nil) |> put_flash(:info, "Member updated.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update member.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    member = Projects.get_project_member!(id)

    case Projects.delete_project_member(member) do
      {:ok, _} ->
        {:noreply, refresh_data(socket) |> put_flash(:info, "Developer removed from project.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove member.")}
    end
  end

  defp refresh_data(socket) do
    project_id = socket.assigns.project.id
    members = Projects.list_project_members(project_id)
    developers = Accounts.list_developers()
    assigned_user_ids = Enum.map(members, & &1.user_id)
    available_developers = Enum.filter(developers, fn d -> d.id not in assigned_user_ids end)

    socket
    |> assign(:members, members)
    |> assign(:developers, available_developers)
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end
  defp parse_decimal(value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <div class="project-members">
      <div class="mb-6">
        <.link navigate={~p"/projects"} class="text-[#F7931A] hover:text-[#FFD600] text-sm font-heading font-semibold transition-colors inline-flex items-center gap-2">
          ← Back to Projects
        </.link>
      </div>

      <div class="flex justify-between items-start mb-12">
        <div>
          <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2"><%= @project.name %></h1>
          <p class="text-lg font-body text-[#94A3B8] mb-2">Manage team members and hourly rates</p>
          <div class="mt-2 flex items-center gap-4 text-sm font-mono text-[#94A3B8]">
            <span>Client: <%= @project.client_name || "N/A" %></span>
            <span>Default Rate: $<%= @project.hourly_rate || "0" %>/hr</span>
          </div>
        </div>
        <%= if not @show_add_form and length(@developers) > 0 do %>
          <button phx-click="show_add_form" class="inline-flex items-center justify-center px-6 py-3 rounded-full bg-gradient-to-r from-[#EA580C] to-[#F7931A] hover:scale-105 hover:shadow-[0_0_30px_-5px_rgba(247,147,26,0.6)] text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300 shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]">
            + Add Developer
          </button>
        <% end %>
      </div>

      <!-- Add Member Form -->
      <%= if @show_add_form do %>
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-8 hover:border-[#F7931A]/50 transition-all duration-300">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl font-heading font-semibold text-white">Add Developer to Project</h2>
            <button phx-click="hide_add_form" class="text-sm font-body text-[#94A3B8] hover:text-white transition-colors">Cancel</button>
          </div>

          <form phx-submit="add_member" class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <TimetrackingPhoenixWeb.CoreComponents.label for="member_user_id">Developer</TimetrackingPhoenixWeb.CoreComponents.label>
                <select name="member[user_id]" id="member_user_id" required class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200">
                  <option value="">Select a developer...</option>
                  <%= for dev <- @developers do %>
                    <option value={dev.id}><%= dev.first_name %> <%= dev.last_name %> (<%= dev.email %>)</option>
                  <% end %>
                </select>
              </div>

              <div>
                <TimetrackingPhoenixWeb.CoreComponents.label for="member_role">Role</TimetrackingPhoenixWeb.CoreComponents.label>
                <select name="member[role]" id="member_role" class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200">
                  <option value="developer">Developer</option>
                  <option value="lead">Lead Developer</option>
                  <option value="consultant">Consultant</option>
                </select>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <TimetrackingPhoenixWeb.CoreComponents.label for="member_hourly_rate">
                  Hourly Rate
                  <span class="text-[#EA580C] font-normal">*</span>
                </TimetrackingPhoenixWeb.CoreComponents.label>
                <input type="number" step="0.01" min="0" name="member[hourly_rate]" id="member_hourly_rate" required placeholder="Enter hourly rate" class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white placeholder:text-white/30 px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200 font-body text-sm" />
                <p class="mt-1 text-xs font-body text-[#94A3B8]">Rate for this developer on this project</p>
              </div>

              <div>
                <TimetrackingPhoenixWeb.CoreComponents.label for="member_currency">Currency</TimetrackingPhoenixWeb.CoreComponents.label>
                <select name="member[currency]" id="member_currency" class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200">
                  <option value="">Use project currency (<%= @project.currency || "USD" %>)</option>
                  <option value="USD">USD - US Dollar</option>
                  <option value="EUR">EUR - Euro</option>
                  <option value="GBP">GBP - British Pound</option>
                  <option value="JPY">JPY - Japanese Yen</option>
                  <option value="CAD">CAD - Canadian Dollar</option>
                  <option value="AUD">AUD - Australian Dollar</option>
                  <option value="CHF">CHF - Swiss Franc</option>
                  <option value="CNY">CNY - Chinese Yuan</option>
                  <option value="INR">INR - Indian Rupee</option>
                  <option value="BRL">BRL - Brazilian Real</option>
                  <option value="MXN">MXN - Mexican Peso</option>
                  <option value="ZAR">ZAR - South African Rand</option>
                  <option value="SEK">SEK - Swedish Krona</option>
                  <option value="NOK">NOK - Norwegian Krone</option>
                  <option value="DKK">DKK - Danish Krone</option>
                  <option value="PLN">PLN - Polish Zloty</option>
                  <option value="NZD">NZD - New Zealand Dollar</option>
                  <option value="SGD">SGD - Singapore Dollar</option>
                  <option value="HKD">HKD - Hong Kong Dollar</option>
                  <option value="KRW">KRW - South Korean Won</option>
                </select>
                <p class="mt-1 text-xs font-body text-[#94A3B8]">Leave blank to use developer's default currency</p>
              </div>
            </div>

            <div class="pt-2">
              <.button type="submit">Add to Project</.button>
            </div>
          </form>
        </div>
      <% end %>

      <!-- Members List -->
      <div class="bg-[#0F1115] border border-white/10 rounded-2xl overflow-hidden hover:border-[#F7931A]/50 transition-all duration-300">
        <div class="px-8 py-6 border-b border-white/10">
          <h2 class="text-lg font-heading font-semibold text-white">Team Members (<%= length(@members) %>)</h2>
        </div>

        <%= if Enum.empty?(@members) do %>
          <div class="p-12 text-center">
            <svg class="h-12 w-12 text-[#94A3B8] mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
            </svg>
            <p class="text-[#94A3B8] mb-4 font-body">No developers assigned to this project yet.</p>
            <%= if length(@developers) > 0 do %>
              <button phx-click="show_add_form" class="text-[#F7931A] hover:text-[#FFD600] font-heading font-semibold transition-colors">
                Add the first developer →
              </button>
            <% else %>
              <p class="text-[#94A3B8] text-sm font-body">Create developers in the Users section first.</p>
            <% end %>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-white/10">
              <thead class="bg-[#030304]">
                <tr>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Developer</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Role</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Rate</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Currency</th>
                  <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Added</th>
                  <th class="px-6 py-4 text-right text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/10">
                <%= for member <- @members do %>
                  <tr class="hover:bg-white/5 transition-colors">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="flex-shrink-0 h-10 w-10">
                          <div class="h-10 w-10 rounded-full bg-gradient-to-br from-[#F7931A] to-[#FFD600] flex items-center justify-center text-white font-heading font-semibold text-sm">
                            <%= String.first(member.user.first_name) %><%= String.first(member.user.last_name) %>
                          </div>
                        </div>
                        <div class="ml-4">
                          <div class="text-sm font-body font-medium text-white"><%= member.user.first_name %> <%= member.user.last_name %></div>
                          <div class="text-sm font-mono text-[#94A3B8]"><%= member.user.email %></div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if @editing_member_id == member.id do %>
                        <select form={"edit-form-#{member.id}"} name="member[role]" class="rounded-lg border border-white/20 bg-black/50 text-white text-sm px-2 py-1">
                          <option value="developer" selected={member.role == "developer"}>Developer</option>
                          <option value="lead" selected={member.role == "lead"}>Lead Developer</option>
                          <option value="consultant" selected={member.role == "consultant"}>Consultant</option>
                        </select>
                      <% else %>
                        <span class="inline-flex px-3 py-1 text-xs font-mono uppercase tracking-wider rounded-full bg-[#F7931A]/20 text-[#F7931A] border border-[#F7931A]/50">
                          <%= String.capitalize(member.role || "developer") %>
                        </span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if @editing_member_id == member.id do %>
                        <form id={"edit-form-#{member.id}"} phx-submit="update_member" phx-value-id={member.id} class="space-y-2">
                          <div class="flex items-center gap-2">
                            <input type="number" step="0.01" min="0" name="member[hourly_rate]" value={member.hourly_rate} required placeholder="0.00" class="w-24 rounded-lg border border-white/20 bg-black/50 text-white text-sm px-2 py-1 font-mono" />
                            <span class="text-[#94A3B8] font-mono text-xs">/hr</span>
                          </div>
                        </form>
                      <% else %>
                        <%= if member.hourly_rate do %>
                          <span class="text-sm font-mono font-semibold text-[#F7931A]"><%= Decimal.round(member.hourly_rate, 2) %>/hr</span>
                        <% else %>
                          <span class="text-sm font-mono text-[#94A3B8]">Not set</span>
                        <% end %>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if @editing_member_id == member.id do %>
                        <select form={"edit-form-#{member.id}"} name="member[currency]" class="rounded-lg border border-white/20 bg-black/50 text-white text-sm px-2 py-1">
                          <option value="" selected={member.currency == nil}>Use project default (<%= @project.currency || "USD" %>)</option>
                          <option value="USD" selected={member.currency == "USD"}>USD</option>
                          <option value="EUR" selected={member.currency == "EUR"}>EUR</option>
                          <option value="GBP" selected={member.currency == "GBP"}>GBP</option>
                          <option value="JPY" selected={member.currency == "JPY"}>JPY</option>
                          <option value="CAD" selected={member.currency == "CAD"}>CAD</option>
                          <option value="AUD" selected={member.currency == "AUD"}>AUD</option>
                          <option value="CHF" selected={member.currency == "CHF"}>CHF</option>
                          <option value="CNY" selected={member.currency == "CNY"}>CNY</option>
                          <option value="INR" selected={member.currency == "INR"}>INR</option>
                          <option value="BRL" selected={member.currency == "BRL"}>BRL</option>
                          <option value="MXN" selected={member.currency == "MXN"}>MXN</option>
                          <option value="ZAR" selected={member.currency == "ZAR"}>ZAR</option>
                          <option value="SEK" selected={member.currency == "SEK"}>SEK</option>
                          <option value="NOK" selected={member.currency == "NOK"}>NOK</option>
                          <option value="DKK" selected={member.currency == "DKK"}>DKK</option>
                          <option value="PLN" selected={member.currency == "PLN"}>PLN</option>
                          <option value="NZD" selected={member.currency == "NZD"}>NZD</option>
                          <option value="SGD" selected={member.currency == "SGD"}>SGD</option>
                          <option value="HKD" selected={member.currency == "HKD"}>HKD</option>
                          <option value="KRW" selected={member.currency == "KRW"}>KRW</option>
                        </select>
                      <% else %>
                        <% currency = member.currency || @project.currency || "USD" %>
                        <span class="text-sm font-mono text-[#F7931A]"><%= currency %></span>
                        <%= if member.currency == nil do %>
                          <span class="text-xs text-[#94A3B8] ml-1">(project)</span>
                        <% end %>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-[#94A3B8]">
                      <%= Calendar.strftime(member.inserted_at, "%b %d, %Y") %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <%= if @editing_member_id == member.id do %>
                        <button type="submit" form={"edit-form-#{member.id}"} class="text-[#F7931A] hover:text-[#FFD600] mr-3 font-mono uppercase tracking-wider transition-colors">Save</button>
                        <button phx-click="cancel_edit" class="text-[#94A3B8] hover:text-white font-mono uppercase tracking-wider transition-colors">Cancel</button>
                      <% else %>
                        <button phx-click="edit_member" phx-value-id={member.id} class="text-[#F7931A] hover:text-[#FFD600] mr-4 font-mono uppercase tracking-wider transition-colors">Edit Rate</button>
                        <button phx-click="remove_member" phx-value-id={member.id} data-confirm="Remove this developer from the project?" class="text-[#EA580C] hover:text-[#F7931A] font-mono uppercase tracking-wider transition-colors">
                          Remove
                        </button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <!-- Info Box -->
      <div class="mt-8 bg-[#0F1115] border border-[#F7931A]/50 rounded-xl p-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-[#F7931A]" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-body text-[#94A3B8]">
              <strong class="text-white">Hourly rates:</strong> Each developer has their own hourly rate for this project. These rates are used in time tracking reports and billing.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
