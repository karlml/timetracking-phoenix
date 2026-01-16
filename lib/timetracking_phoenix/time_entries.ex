defmodule TimetrackingPhoenix.TimeEntries do
  @moduledoc """
  The TimeEntries context.
  """

  import Ecto.Query, warn: false
  alias TimetrackingPhoenix.Repo

  alias TimetrackingPhoenix.TimeEntries.TimeEntry
  alias TimetrackingPhoenix.Accounts.User

  @doc """
  Returns the list of time_entries.

  ## Examples

      iex> list_time_entries()
      [%TimeEntry{}, ...]

  """
  def list_time_entries do
    Repo.all(TimeEntry)
  end

  @doc """
  Returns the list of time entries for a specific user.
  """
  def list_user_time_entries(%User{} = user) do
    Repo.all(from te in TimeEntry,
             where: te.user_id == ^user.id,
             order_by: [desc: te.date, desc: te.inserted_at],
             preload: [:project])
  end

  @doc """
  Returns time entries for a user between specific dates.
  """
  def list_user_time_entries_between_dates(%User{} = user, start_date, end_date) do
    Repo.all(from te in TimeEntry,
             where: te.user_id == ^user.id,
             where: te.date >= ^start_date and te.date <= ^end_date,
             order_by: [desc: te.date, desc: te.inserted_at],
             preload: [:project])
  end

  @doc """
  Returns time entries for a user on a specific date.
  """
  def list_user_time_entries_for_date(%User{} = user, date) do
    Repo.all(from te in TimeEntry,
             where: te.user_id == ^user.id and te.date == ^date,
             order_by: [desc: te.inserted_at],
             preload: [:project])
  end

  @doc """
  Returns time entries for a specific project.
  """
  def list_project_time_entries(project) do
    project_id = if is_struct(project), do: project.id, else: project
    Repo.all(from te in TimeEntry,
             where: te.project_id == ^project_id,
             order_by: [desc: te.date, desc: te.inserted_at],
             preload: [:user])
  end

  @doc """
  Returns time entries for a project within a date range.
  """
  def list_project_time_entries_in_range(project, start_date, end_date) do
    project_id = if is_struct(project), do: project.id, else: project
    Repo.all(from te in TimeEntry,
             where: te.project_id == ^project_id,
             where: te.date >= ^start_date and te.date <= ^end_date,
             order_by: [desc: te.date, desc: te.inserted_at],
             preload: [:user])
  end

  @doc """
  Gets a single time_entry.

  Raises `Ecto.NoResultsError` if the TimeEntry does not exist.

  ## Examples

      iex> get_time_entry!(123)
      %TimeEntry{}

      iex> get_time_entry!(456)
      ** (Ecto.NoResultsError)

  """
  def get_time_entry!(id), do: Repo.get!(TimeEntry, id)

  @doc """
  Creates a time_entry.

  ## Examples

      iex> create_time_entry(%{field: value})
      {:ok, %TimeEntry{}}

      iex> create_time_entry(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_time_entry(attrs \\ %{}) do
    %TimeEntry{}
    |> TimeEntry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a time_entry.

  ## Examples

      iex> update_time_entry(time_entry, %{field: new_value})
      {:ok, %TimeEntry{}}

      iex> update_time_entry(time_entry, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_time_entry(%TimeEntry{} = time_entry, attrs) do
    time_entry
    |> TimeEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a time_entry.

  ## Examples

      iex> delete_time_entry(time_entry)
      {:ok, %TimeEntry{}}

      iex> delete_time_entry(time_entry)
      {:error, %Ecto.Changeset{}}

  """
  def delete_time_entry(%TimeEntry{} = time_entry) do
    Repo.delete(time_entry)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking time_entry changes.

  ## Examples

      iex> change_time_entry(time_entry)
      %Ecto.Changeset{data: %TimeEntry{}}

  """
  def change_time_entry(%TimeEntry{} = time_entry, attrs \\ %{}) do
    TimeEntry.changeset(time_entry, attrs)
  end

  @doc """
  Calculates total hours for a user in a date range.
  """
  def user_total_hours_in_range(%User{} = user, start_date, end_date) do
    Repo.one(from te in TimeEntry,
             where: te.user_id == ^user.id,
             where: te.date >= ^start_date and te.date <= ^end_date,
             select: coalesce(sum(te.hours), 0))
  end

  @doc """
  Calculates total hours for a project.
  """
  def project_total_hours(project_id) do
    Repo.one(from te in TimeEntry,
             where: te.project_id == ^project_id,
             select: coalesce(sum(te.hours), 0))
  end

  @doc """
  Gets time entries for reporting (with project and user info).
  """
  def list_time_entries_for_report(project_id, start_date \\ nil, end_date \\ nil) do
    query = from te in TimeEntry,
            where: te.project_id == ^project_id,
            preload: [:user, :project]

    query = if start_date, do: where(query, [te], te.date >= ^start_date), else: query
    query = if end_date, do: where(query, [te], te.date <= ^end_date), else: query

    Repo.all(from q in query, order_by: [asc: q.date, asc: q.inserted_at])
  end

  @doc """
  Returns time entries for projects managed by the given user.
  For admins (by current_role), returns all time entries (since admins can manage all projects).
  For other users, returns time entries for projects they own (project.user_id == user.id).
  """
  def list_managed_project_time_entries(%User{current_role: "admin"}) do
    Repo.all(from te in TimeEntry,
             order_by: [desc: te.date, desc: te.inserted_at],
             preload: [:project, :user])
  end

  def list_managed_project_time_entries(%User{} = user) do
    Repo.all(from te in TimeEntry,
             join: p in assoc(te, :project),
             where: p.user_id == ^user.id,
             order_by: [desc: te.date, desc: te.inserted_at],
             preload: [:project, :user])
  end

  @doc """
  Checks if a user can edit a time entry (only their own entries, or admin).
  """
  def can_edit_time_entry?(%User{role: "admin"}, _time_entry), do: true
  def can_edit_time_entry?(%User{id: user_id}, %TimeEntry{user_id: entry_user_id}), do: user_id == entry_user_id
  def can_edit_time_entry?(_, _), do: false

  @doc """
  Finds a time entry for a specific user, project, and date.
  Returns nil if not found.
  """
  def find_entry(user_id, project_id, date) do
    Repo.one(from te in TimeEntry,
             where: te.user_id == ^user_id and te.project_id == ^project_id and te.date == ^date,
             limit: 1)
  end

  @doc """
  Lists time entries for a user and project within a date range (for weekly view).
  """
  def list_entries_for_week(user_id, project_id, start_date, end_date) do
    Repo.all(from te in TimeEntry,
             where: te.user_id == ^user_id and te.project_id == ^project_id,
             where: te.date >= ^start_date and te.date <= ^end_date,
             order_by: [asc: te.date])
  end
end
