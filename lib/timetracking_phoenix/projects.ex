defmodule TimetrackingPhoenix.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias TimetrackingPhoenix.Repo

  alias TimetrackingPhoenix.Projects.Project
  alias TimetrackingPhoenix.Projects.ProjectMember
  alias TimetrackingPhoenix.Accounts.User

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]

  """
  def list_projects do
    Repo.all(Project) |> Repo.preload(:client)
  end

  @doc """
  Returns the list of projects for a specific user (developer or client).
  Uses current_role for users with multiple roles.
  """
  def list_user_projects(%User{current_role: "client"} = user) do
    Repo.all(from p in Project, where: p.client_id == ^user.id, preload: [:client])
  end

  def list_user_projects(%User{current_role: "developer"} = user) do
    # For developers, show projects they:
    # 1. Own (created by them)
    # 2. Are assigned to as a team member
    # 3. Have time entries in
    
    member_projects = from p in Project,
      join: pm in ProjectMember, on: pm.project_id == p.id,
      where: pm.user_id == ^user.id,
      distinct: true,
      select: p.id

    time_entry_projects = from p in Project,
      join: te in assoc(p, :time_entries),
      where: te.user_id == ^user.id,
      distinct: true,
      select: p.id

    Repo.all(from p in Project,
      where: p.user_id == ^user.id or 
             p.id in subquery(member_projects) or 
             p.id in subquery(time_entry_projects),
      distinct: true,
      preload: [:client])
  end

  def list_user_projects(%User{current_role: "admin"}) do
    Repo.all(Project) |> Repo.preload(:client)
  end

  # Fallback for legacy role field
  def list_user_projects(%User{role: role} = user) when role in ["client", "developer", "admin"] do
    list_user_projects(%{user | current_role: role})
  end

  def list_user_projects(_user) do
    # Default to empty list for unknown roles
    []
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  @doc """
  Returns the list of active projects.
  """
  def list_active_projects do
    Repo.all(from p in Project, where: p.status == "active")
  end

  @doc """
  Returns projects for a specific client.
  """
  def list_client_projects(client_id) do
    Repo.all(from p in Project, where: p.client_id == ^client_id)
  end

  @doc """
  Calculates total hours logged for a project.
  """
  def project_total_hours(%Project{} = project) do
    Repo.one(from te in "time_entries",
             where: te.project_id == ^project.id,
             select: coalesce(sum(te.hours), 0))
  end

  @doc """
  Calculates remaining budget hours for a project.
  """
  def project_remaining_budget(%Project{} = project) do
    if project.budget_hours do
      total_hours = project_total_hours(project)
      Decimal.sub(project.budget_hours, total_hours)
    else
      nil
    end
  end

  # =============================================================================
  # Project Members (Developer Assignments with Hourly Rates)
  # =============================================================================

  @doc """
  Returns all members for a project with user data preloaded.
  """
  def list_project_members(project_id) do
    Repo.all(
      from pm in ProjectMember,
        where: pm.project_id == ^project_id,
        preload: [:user],
        order_by: [asc: pm.inserted_at]
    )
  end

  @doc """
  Returns all project memberships for a user with project data preloaded.
  """
  def list_user_project_memberships(user_id) do
    Repo.all(
      from pm in ProjectMember,
        where: pm.user_id == ^user_id,
        preload: [:project],
        order_by: [asc: pm.inserted_at]
    )
  end

  @doc """
  Gets a single project member.
  """
  def get_project_member!(id), do: Repo.get!(ProjectMember, id) |> Repo.preload(:user)

  @doc """
  Gets a project member by project and user.
  """
  def get_project_member(project_id, user_id) do
    Repo.get_by(ProjectMember, project_id: project_id, user_id: user_id)
    |> case do
      nil -> nil
      pm -> Repo.preload(pm, :user)
    end
  end

  @doc """
  Adds a developer to a project with an optional hourly rate.
  """
  def add_project_member(attrs \\ %{}) do
    %ProjectMember{}
    |> ProjectMember.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project member's hourly rate or role.
  """
  def update_project_member(%ProjectMember{} = member, attrs) do
    member
    |> ProjectMember.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Removes a developer from a project.
  """
  def delete_project_member(%ProjectMember{} = member) do
    Repo.delete(member)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project member changes.
  """
  def change_project_member(%ProjectMember{} = member, attrs \\ %{}) do
    ProjectMember.changeset(member, attrs)
  end

  @doc """
  Gets the hourly rate for a specific user on a project.
  Falls back to the project's default hourly rate if no specific rate is set.
  """
  def get_developer_hourly_rate(project_id, user_id) do
    case get_project_member(project_id, user_id) do
      %ProjectMember{hourly_rate: rate} when not is_nil(rate) -> rate
      _ ->
        project = get_project!(project_id)
        project.hourly_rate || Decimal.new(0)
    end
  end

  @doc """
  Gets a project with members preloaded.
  """
  def get_project_with_members!(id) do
    Repo.get!(Project, id)
    |> Repo.preload(project_members: :user)
  end
end
