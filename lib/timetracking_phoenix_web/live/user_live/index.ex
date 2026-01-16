defmodule TimetrackingPhoenixWeb.UserLive.Index do
  use TimetrackingPhoenixWeb, :live_view
  import TimetrackingPhoenixWeb.CoreComponents, except: [label: 1]

  alias TimetrackingPhoenix.Accounts
  alias TimetrackingPhoenix.Accounts.User
  alias TimetrackingPhoenix.Projects

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    is_admin = User.is_admin?(current_user)

    # Only admins can access the index page, but developers can edit their own profile
    {:ok,
     socket
     |> assign(:users, if(is_admin, do: Accounts.list_users(), else: []))
     |> assign(:page_title, "Users")
     |> assign(:project_memberships, [])
     |> assign(:all_projects, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns.current_user
    user = Accounts.get_user!(id)
    is_admin = User.is_admin?(current_user)
    
    # Developers can only edit their own profile
    if !is_admin && user.id != current_user.id do
      socket
      |> put_flash(:error, "You don't have permission to edit this user.")
      |> redirect(to: ~p"/dashboard")
    else
      # Load project memberships for this user (for rate management)
      project_memberships = Projects.list_user_project_memberships(user.id)
      all_projects = if is_admin, do: Projects.list_projects(), else: []
      
      socket
      |> assign(:page_title, if(user.id == current_user.id, do: "My Profile", else: "Edit User"))
      |> assign(:user, user)
      |> assign(:changeset, Accounts.change_user(user))
      |> assign(:project_memberships, project_memberships)
      |> assign(:all_projects, all_projects)
    end
  end

  defp apply_action(socket, :new, _params) do
    current_user = socket.assigns.current_user
    
    # Only admins can create new users
    if !User.is_admin?(current_user) do
      socket
      |> put_flash(:error, "You don't have permission to create users.")
      |> redirect(to: ~p"/dashboard")
    else
      user = %User{role: "developer", roles: "developer", current_role: "developer", confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)}
      socket
      |> assign(:page_title, "New User")
      |> assign(:user, user)
      |> assign(:changeset, Accounts.change_user(user))
    end
  end

  defp apply_action(socket, :index, _params) do
    current_user = socket.assigns.current_user
    
    # Only admins can see the user list
    if !User.is_admin?(current_user) do
      socket
      |> put_flash(:error, "You don't have permission to access this page.")
      |> redirect(to: ~p"/dashboard")
    else
      socket
      |> assign(:page_title, "Users")
      |> assign(:user, nil)
      |> assign(:changeset, nil)
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    # Don't allow deleting yourself
    if user.id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "You cannot delete your own account.")}
    else
      case Accounts.delete_user(user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "User deleted successfully.")
           |> assign(:users, Accounts.list_users())}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete user.")}
      end
    end
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # Process roles from checkboxes
    user_params = process_roles_params(user_params)
    # Process can_see_rate checkbox (unchecked checkboxes don't send any value)
    user_params = process_can_see_rate_param(user_params)
    save_user(socket, socket.assigns.live_action, user_params)
  end

  # Process the roles array from checkboxes into a comma-separated string
  defp process_roles_params(params) do
    case Map.get(params, "roles") do
      nil -> params
      [] -> Map.put(params, "roles", "developer")
      roles when is_list(roles) ->
        roles_string = Enum.join(roles, ",")
        # Set current_role to first role if not already set
        params
        |> Map.put("roles", roles_string)
        |> Map.put_new("current_role", List.first(roles))
    end
  end

  # Process can_see_rate checkbox - unchecked checkboxes don't send any value
  defp process_can_see_rate_param(params) do
    case Map.get(params, "can_see_rate") do
      "true" -> Map.put(params, "can_see_rate", true)
      _ -> Map.put(params, "can_see_rate", false)
    end
  end

  defp save_user(socket, :edit, user_params) do
    current_user = socket.assigns.current_user
    user = socket.assigns.user
    is_admin = User.is_admin?(current_user)
    
    # Non-admin users can update their own profile (name, email, and rate/currency if permitted)
    if !is_admin && user.id == current_user.id do
      # Base profile fields - always allowed for self-edit
      profile_params = %{
        "first_name" => user_params["first_name"],
        "last_name" => user_params["last_name"],
        "email" => user_params["email"]
      }
      
      case Accounts.update_user(user, profile_params) do
        {:ok, _updated_user} ->
          # Use redirect for cross-LiveView navigation (more reliable than push_navigate)
          {:noreply,
           socket
           |> put_flash(:info, "Profile updated successfully.")
           |> redirect(to: ~p"/dashboard")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
      # Admins can update all fields
      case Accounts.update_user(user, user_params) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "User updated successfully.")
           |> assign(:users, Accounts.list_users())
           |> push_patch(to: ~p"/users")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    end
  end

  defp save_user(socket, :new, user_params) do
    # Add confirmed_at for new users and ensure current_role is set
    user_params = user_params
    |> Map.put("confirmed_at", NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    |> ensure_current_role()

    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully.")
         |> assign(:users, Accounts.list_users())
         |> push_patch(to: ~p"/users")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  # Ensure current_role is set from roles
  defp ensure_current_role(%{"roles" => roles} = params) when is_binary(roles) do
    first_role = roles |> String.split(",") |> List.first() |> String.trim()
    Map.put_new(params, "current_role", first_role)
  end
  defp ensure_current_role(params), do: Map.put_new(params, "current_role", "developer")

  # Helper to get user's roles as a list
  defp get_user_roles(nil), do: ["developer"]
  defp get_user_roles(%User{} = user), do: User.roles_list(user)

  # Role checkbox component
  attr :role, :string, required: true
  attr :user, :any, required: true
  
  defp role_checkbox(assigns) do
    user_roles = get_user_roles(assigns.user)
    is_checked = assigns.role in user_roles
    
    assigns = assign(assigns, :is_checked, is_checked)
    assigns = assign(assigns, :class_active, if(is_checked, do: "bg-[#F7931A]/10 border-[#F7931A]/50 text-[#F7931A]", else: "bg-black/30 border-white/20 text-[#94A3B8]"))
    
    ~H"""
    <label class={"relative flex items-center gap-2 px-4 py-2 rounded-lg border cursor-pointer transition-all duration-200 hover:border-[#F7931A]/50 #{@class_active}"}>
      <input 
        type="checkbox" 
        name="user[roles][]" 
        value={@role}
        checked={@is_checked}
        class="rounded border-white/20 bg-black/50 text-[#F7931A] focus:ring-[#F7931A] focus:ring-2 focus:ring-offset-2 focus:ring-offset-[#030304]"
      />
      <span class="text-sm font-mono capitalize"><%= @role %></span>
    </label>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="users">
      <.flash_group flash={@flash} />
      <div class="flex justify-between items-center mb-12">
        <div>
          <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2">Users</h1>
          <p class="text-lg font-body text-[#94A3B8]">Manage developers, admins, and clients</p>
        </div>
        <.link patch={~p"/users/new"} class="inline-flex items-center justify-center px-6 py-3 rounded-full bg-gradient-to-r from-[#EA580C] to-[#F7931A] hover:scale-105 hover:shadow-[0_0_30px_-5px_rgba(247,147,26,0.6)] text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300 shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]">
          + New User
        </.link>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-8 hover:border-[#F7931A]/50 transition-all duration-300">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl font-heading font-semibold text-white">
              <%= if @live_action == :new, do: "New User", else: "Edit User" %>
            </h2>
            <.link patch={~p"/users"} class="text-sm font-body text-[#94A3B8] hover:text-white transition-colors">Cancel</.link>
          </div>

          <.form :let={f} for={@changeset} phx-submit="save" class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <.input field={f[:first_name]} type="text" label="First Name" required />
              <.input field={f[:last_name]} type="text" label="Last Name" required />
            </div>

            <.input field={f[:email]} type="email" label="Email" required />

            <%= if User.is_admin?(@current_user) do %>
              <!-- Multiple Roles Selection -->
              <div>
                <label class="block text-sm font-heading font-semibold leading-6 text-white mb-3">Roles</label>
                <p class="text-xs font-body text-[#94A3B8] mb-3">Select one or more roles for this user</p>
                <div class="flex flex-wrap gap-3">
                  <.role_checkbox role="developer" user={@user} />
                  <.role_checkbox role="admin" user={@user} />
                  <.role_checkbox role="client" user={@user} />
                </div>
              </div>
              
              <!-- Rate Visibility Permission (only for non-admin users being edited) -->
              <%= if @user && @user.id && !User.is_admin?(@user) do %>
                <div class="border border-white/10 rounded-lg p-4 bg-black/20">
                  <div class="flex items-center justify-between">
                    <div>
                      <label class="block text-sm font-heading font-semibold leading-6 text-white">Rate Visibility</label>
                      <p class="text-xs font-body text-[#94A3B8] mt-1">Allow this user to see and edit their own hourly rate</p>
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input 
                        type="checkbox" 
                        name="user[can_see_rate]" 
                        value="true"
                        checked={@user.can_see_rate}
                        class="sr-only peer"
                      />
                      <div class="w-11 h-6 bg-black/50 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-[#F7931A] rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-white/20 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#F7931A]"></div>
                    </label>
                  </div>
                </div>
              <% end %>
            <% else %>
              <div>
                <label for="user_role" class="block text-sm font-heading font-semibold leading-6 text-white">Role</label>
                <input type="text" name="user[role]" id="user_role" value={Phoenix.HTML.Form.input_value(f, :role)} disabled class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/10 bg-black/30 text-white/50 text-sm font-body px-4 py-2 cursor-not-allowed" />
              </div>
            <% end %>

            <%= if User.is_admin?(@current_user) and @live_action == :edit and "developer" in get_user_roles(@user) do %>
              <!-- Project Rates Section -->
              <div class="border-t border-white/10 pt-6 mt-6">
                <h3 class="text-lg font-heading font-semibold text-white mb-4">Project Rates</h3>
                <p class="text-sm font-body text-[#94A3B8] mb-4">Set hourly rates for each project this user is assigned to</p>
                
                <%= if Enum.empty?(@project_memberships) do %>
                  <div class="bg-black/30 rounded-lg p-6 text-center">
                    <p class="text-[#94A3B8] font-body">This user is not assigned to any projects yet.</p>
                    <p class="text-sm text-[#94A3B8] mt-2">Add them to projects from the <.link navigate={~p"/projects"} class="text-[#F7931A] hover:text-[#FFD600]">Projects</.link> page.</p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-white/10">
                      <thead class="bg-black/30">
                        <tr>
                          <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Project</th>
                          <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Rate</th>
                          <th class="px-4 py-3 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Currency</th>
                          <th class="px-4 py-3 text-right text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Actions</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-white/10">
                        <%= for membership <- @project_memberships do %>
                          <tr class="hover:bg-white/5 transition-colors">
                            <td class="px-4 py-3 whitespace-nowrap text-sm font-body text-white">
                              <%= membership.project.name %>
                            </td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm font-mono text-[#F7931A]">
                              <%= if membership.hourly_rate, do: Decimal.round(membership.hourly_rate, 2), else: "Not set" %>
                            </td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm font-mono text-[#94A3B8]">
                              <%= membership.currency || membership.project.currency || "USD" %>
                            </td>
                            <td class="px-4 py-3 whitespace-nowrap text-right text-sm">
                              <.link navigate={~p"/projects/#{membership.project_id}/members"} class="text-[#F7931A] hover:text-[#FFD600] font-mono uppercase tracking-wider transition-colors">
                                Edit
                              </.link>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>
            <% end %>

            <%= if @current_user.role == "admin" do %>
              <div>
                <label for="user_password" class="block text-sm font-heading font-semibold leading-6 text-white">
                  Password <%= if @live_action == :edit, do: "(leave blank to keep current)" %>
                </label>
                <div class="relative mt-2">
                  <input 
                    type="password" 
                    name="user[password]" 
                    id="user_password" 
                    placeholder={if @live_action == :edit, do: "••••••••", else: ""} 
                    class="block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white placeholder:text-white/30 px-4 py-2 pr-12 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200 font-body text-sm" 
                  />
                  <button 
                    type="button"
                    onclick="togglePasswordVisibility()"
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-[#94A3B8] hover:text-[#F7931A] transition-colors duration-200"
                    aria-label="Toggle password visibility"
                  >
                    <!-- Eye icon (visible when password is hidden) -->
                    <svg id="eye-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.64 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.64 0-8.573-3.007-9.963-7.178Z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                    </svg>
                    <!-- Eye-slash icon (visible when password is shown) -->
                    <svg id="eye-slash-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 hidden">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88" />
                    </svg>
                  </button>
                </div>
                <p class="mt-1 text-xs font-body text-[#94A3B8]">Minimum 6 characters</p>
              </div>
              <script>
                function togglePasswordVisibility() {
                  const input = document.getElementById('user_password');
                  const eyeIcon = document.getElementById('eye-icon');
                  const eyeSlashIcon = document.getElementById('eye-slash-icon');
                  
                  if (input.type === 'password') {
                    input.type = 'text';
                    eyeIcon.classList.add('hidden');
                    eyeSlashIcon.classList.remove('hidden');
                  } else {
                    input.type = 'password';
                    eyeIcon.classList.remove('hidden');
                    eyeSlashIcon.classList.add('hidden');
                  }
                }
              </script>
            <% end %>

            <div class="pt-4">
              <.button type="submit">
                <%= if @live_action == :new, do: "Create User", else: "Save Changes" %>
              </.button>
            </div>
          </.form>
        </div>
      <% end %>

      <!-- Users Table -->
      <div class="bg-[#0F1115] border border-white/10 rounded-2xl overflow-hidden hover:border-[#F7931A]/50 transition-all duration-300">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-white/10">
            <thead class="bg-[#030304]">
              <tr>
                <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Name</th>
                <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Email</th>
                <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Roles</th>
                <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Active Role</th>
                <th class="px-6 py-4 text-left text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Status</th>
                <th class="px-6 py-4 text-right text-xs font-mono font-medium text-[#94A3B8] uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-white/10">
              <%= for user <- @users do %>
                <% user_roles = get_user_roles(user) %>
                <tr class={"hover:bg-white/5 transition-colors #{if user.id == @current_user.id, do: "bg-[#F7931A]/5"}"}>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div class="flex-shrink-0 h-10 w-10">
                        <div class={"h-10 w-10 rounded-full flex items-center justify-center text-white font-heading font-semibold text-sm #{role_color(user.current_role || user.role)}"}>
                          <%= String.first(user.first_name) %><%= String.first(user.last_name) %>
                        </div>
                      </div>
                      <div class="ml-4">
                        <div class="text-sm font-body font-medium text-white">
                          <%= user.first_name %> <%= user.last_name %>
                          <%= if user.id == @current_user.id do %>
                            <span class="text-xs text-[#F7931A] ml-1">(you)</span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-[#94A3B8]">
                    <%= user.email %>
                  </td>
                  <td class="px-6 py-4">
                    <div class="flex flex-wrap gap-1">
                      <%= for role <- user_roles do %>
                        <span class={"inline-flex px-2 py-0.5 text-xs font-mono uppercase tracking-wider rounded-full #{role_badge_color(role)}"}>
                          <%= String.capitalize(role) %>
                        </span>
                      <% end %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center px-3 py-1 text-xs font-mono uppercase tracking-wider rounded-full bg-gradient-to-r from-[#EA580C]/20 to-[#F7931A]/20 text-[#F7931A] border border-[#F7931A]/50">
                      <%= String.capitalize(user.current_role || user.role) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= if user.confirmed_at do %>
                      <span class="inline-flex px-3 py-1 text-xs font-mono uppercase tracking-wider rounded-full bg-[#F7931A]/20 text-[#F7931A] border border-[#F7931A]/50">Active</span>
                    <% else %>
                      <span class="inline-flex px-3 py-1 text-xs font-mono uppercase tracking-wider rounded-full bg-[#FFD600]/20 text-[#FFD600] border border-[#FFD600]/50">Pending</span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <.link patch={~p"/users/#{user}/edit"} class="text-[#F7931A] hover:text-[#FFD600] mr-4 font-mono uppercase tracking-wider transition-colors">Edit</.link>
                    <%= if user.id != @current_user.id do %>
                      <button phx-click="delete" phx-value-id={user.id}
                        data-confirm="Are you sure you want to delete this user?"
                        class="text-[#EA580C] hover:text-[#F7931A] font-mono uppercase tracking-wider transition-colors">
                        Delete
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp role_color("admin"), do: "bg-gradient-to-br from-[#EA580C] to-[#F7931A]"
  defp role_color("developer"), do: "bg-gradient-to-br from-[#F7931A] to-[#FFD600]"
  defp role_color("client"), do: "bg-gradient-to-br from-[#FFD600] to-[#F7931A]"
  defp role_color(_), do: "bg-white/20"

  defp role_badge_color("admin"), do: "bg-[#EA580C]/20 text-[#EA580C] border border-[#EA580C]/50"
  defp role_badge_color("developer"), do: "bg-[#F7931A]/20 text-[#F7931A] border border-[#F7931A]/50"
  defp role_badge_color("client"), do: "bg-[#FFD600]/20 text-[#FFD600] border border-[#FFD600]/50"
  defp role_badge_color(_), do: "bg-white/10 text-[#94A3B8] border border-white/10"
end
