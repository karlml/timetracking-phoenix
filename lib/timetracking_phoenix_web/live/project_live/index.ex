defmodule TimetrackingPhoenixWeb.ProjectLive.Index do
  use TimetrackingPhoenixWeb, :live_view
  import TimetrackingPhoenixWeb.CoreComponents

  alias TimetrackingPhoenix.Projects
  alias TimetrackingPhoenix.Projects.Project
  alias TimetrackingPhoenix.Accounts
  alias TimetrackingPhoenix.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    projects = Projects.list_user_projects(user)
    # Load available clients for the dropdown (users with client role)
    clients = list_available_clients()

    socket = socket
    |> assign(:projects, projects)
    |> assign(:clients, clients)
    |> assign(:page_title, "Projects")

    {:ok, socket}
  end

  # Get users who have the client role
  defp list_available_clients do
    Accounts.list_users()
    |> Enum.filter(fn user -> 
      "client" in User.roles_list(user)
    end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    project = Projects.get_project!(id)
    socket
    |> assign(:page_title, "Edit Project")
    |> assign(:project, project)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Project")
    |> assign(:project, %Project{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Projects")
    |> assign(:project, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    project = Projects.get_project!(id)
    {:ok, _} = Projects.delete_project(project)

    projects = Projects.list_user_projects(socket.assigns.current_user)
    {:noreply, assign(socket, :projects, projects)}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    save_project(socket, socket.assigns.live_action, project_params)
  end

  defp save_project(socket, :edit, project_params) do
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, _project} ->
        projects = Projects.list_user_projects(socket.assigns.current_user)
        {:noreply,
          socket
          |> put_flash(:info, "Project updated successfully")
          |> assign(:projects, projects)
          |> push_patch(to: ~p"/projects")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_project(socket, :new, project_params) do
    project_params = Map.put(project_params, "user_id", socket.assigns.current_user.id)

    case Projects.create_project(project_params) do
      {:ok, _project} ->
        projects = Projects.list_user_projects(socket.assigns.current_user)
        {:noreply,
          socket
          |> put_flash(:info, "Project created successfully")
          |> assign(:projects, projects)
          |> push_patch(to: ~p"/projects")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="projects">
      <div class="flex justify-between items-center mb-12">
        <div>
          <h1 class="text-3xl md:text-5xl font-heading font-bold text-white mb-2">Projects</h1>
          <p class="text-lg font-body text-[#94A3B8]">Manage your projects and clients</p>
        </div>
        <.link patch={~p"/projects/new"} class="inline-flex items-center justify-center px-6 py-3 rounded-full bg-gradient-to-r from-[#EA580C] to-[#F7931A] hover:scale-105 hover:shadow-[0_0_30px_-5px_rgba(247,147,26,0.6)] text-sm font-mono font-semibold text-white uppercase tracking-wider transition-all duration-300 shadow-[0_0_20px_-5px_rgba(234,88,12,0.5)]">
          + New Project
        </.link>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="bg-[#0F1115] border border-white/10 rounded-2xl p-8 mb-8 hover:border-[#F7931A]/50 transition-all duration-300">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-xl font-heading font-semibold text-white"><%= @page_title %></h2>
            <.link patch={~p"/projects"} class="text-sm font-body text-[#94A3B8] hover:text-white transition-colors">Cancel</.link>
          </div>

          <form phx-submit="save" class="space-y-6">
            <.input name="project[name]" value={@project.name} type="text" label="Project Name" required />
            <.input name="project[client_name]" value={@project.client_name} type="text" label="Client Name" />
            
            <!-- Assigned Client User -->
            <div>
              <label for="project_client_id" class="block text-sm font-heading font-semibold leading-6 text-white">Assigned Client</label>
              <p class="text-xs font-body text-[#94A3B8] mb-2">Select a client user who can view this project and its time entries</p>
              <select name="project[client_id]" id="project_client_id" class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200">
                <option value="">No client assigned</option>
                <%= for client <- @clients do %>
                  <option value={client.id} selected={@project.client_id == client.id}>
                    <%= client.first_name %> <%= client.last_name %> (<%= client.email %>)
                  </option>
                <% end %>
              </select>
            </div>
            
            <.input name="project[description]" value={@project.description} type="textarea" label="Description" />
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label for="project_currency" class="block text-sm font-heading font-semibold leading-6 text-white">Currency</label>
                <select name="project[currency]" id="project_currency" class="mt-2 block w-full h-12 rounded-lg border-b-2 border-white/20 bg-black/50 text-white text-sm font-body px-4 py-2 focus-visible:border-[#F7931A] focus-visible:shadow-[0_10px_20px_-10px_rgba(247,147,26,0.3)] focus-visible:outline-none transition-all duration-200">
                  <%= for currency <- Project.valid_currencies() do %>
                    <option value={currency} selected={(@project.currency || "USD") == currency}>
                      <%= currency %>
                    </option>
                  <% end %>
                </select>
                <p class="mt-1 text-xs font-body text-[#94A3B8]">Currency for all billing on this project</p>
              </div>
              
              <.input name="project[budget_hours]" value={@project.budget_hours} type="number" label="Budget Hours" step="0.5" min="0" />
            </div>

            <div class="pt-4">
              <.button type="submit">Save Project</.button>
            </div>
          </form>
        </div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= if Enum.empty?(@projects) do %>
          <div class="col-span-full bg-[#0F1115] border border-white/10 rounded-2xl p-12 text-center">
            <p class="text-[#94A3B8] font-body">No projects yet. Click "+ New Project" to create your first project.</p>
          </div>
        <% else %>
          <%= for project <- @projects do %>
            <div class="group relative bg-[#0F1115] border border-white/10 rounded-2xl p-8 hover:-translate-y-1 hover:border-[#F7931A]/50 hover:shadow-[0_0_30px_-10px_rgba(247,147,26,0.2)] transition-all duration-300">
              <div class="flex justify-between items-start mb-4">
                <div>
                  <h3 class="text-lg font-heading font-semibold text-white mb-1"><%= project.name %></h3>
                  <p class="text-sm font-body text-[#94A3B8]"><%= project.client_name || "No client" %></p>
                  <%= if project.client do %>
                    <p class="text-xs font-body text-[#F7931A] mt-1 flex items-center gap-1">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3 h-3">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                      </svg>
                      <%= project.client.first_name %> <%= project.client.last_name %>
                    </p>
                  <% end %>
                </div>
                <span class={"px-3 py-1 text-xs font-mono uppercase tracking-wider rounded-full #{if project.status == "active", do: "bg-[#F7931A]/20 text-[#F7931A] border border-[#F7931A]/50", else: "bg-white/10 text-[#94A3B8] border border-white/10"}"}>
                  <%= project.status %>
                </span>
              </div>

              <p class="text-sm font-body text-[#94A3B8] mb-6 line-clamp-2">
                <%= project.description || "No description" %>
              </p>

              <div class="grid grid-cols-2 gap-4 mb-6 text-sm">
                <div>
                  <span class="text-[#94A3B8] font-mono text-xs uppercase tracking-wider">Currency:</span>
                  <span class="font-mono font-semibold text-white block mt-1"><%= project.currency || "USD" %></span>
                </div>
                <div>
                  <span class="text-[#94A3B8] font-mono text-xs uppercase tracking-wider">Budget:</span>
                  <span class="font-mono font-semibold text-white block mt-1"><%= project.budget_hours || "∞" %> hrs</span>
                </div>
              </div>

              <div class="flex justify-end space-x-3 pt-6 border-t border-white/10">
                <.link navigate={~p"/projects/#{project}"} class="text-[#F7931A] hover:text-[#FFD600] text-sm font-mono uppercase tracking-wider transition-colors">View</.link>
                <%= if @current_user.role == "admin" do %>
                  <.link navigate={~p"/projects/#{project}/members"} class="text-[#F7931A] hover:text-[#FFD600] text-sm font-mono uppercase tracking-wider transition-colors">Team</.link>
                <% end %>
                <.link patch={~p"/projects/#{project}/edit"} class="text-[#94A3B8] hover:text-white text-sm font-mono uppercase tracking-wider transition-colors">Edit</.link>
                <.link phx-click="delete" phx-value-id={project.id} data-confirm="Are you sure?" class="text-[#EA580C] hover:text-[#F7931A] text-sm font-mono uppercase tracking-wider transition-colors">Delete</.link>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
