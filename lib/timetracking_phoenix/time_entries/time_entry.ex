defmodule TimetrackingPhoenix.TimeEntries.TimeEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "time_entries" do
    field :date, :date
    field :hours, :decimal
    field :description, :string
    field :billable, :boolean, default: true
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime

    belongs_to :user, TimetrackingPhoenix.Accounts.User
    belongs_to :project, TimetrackingPhoenix.Projects.Project

    timestamps()
  end

  @doc false
  def changeset(time_entry, attrs) do
    time_entry
    |> cast(attrs, [:date, :hours, :description, :billable, :start_time, :end_time, :user_id, :project_id])
    |> validate_required([:date, :hours, :user_id, :project_id])
    |> validate_number(:hours, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
    |> validate_start_end_times()
  end

  defp validate_start_end_times(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    cond do
      is_nil(start_time) and is_nil(end_time) ->
        changeset
      is_nil(start_time) or is_nil(end_time) ->
        add_error(changeset, :start_time, "Both start and end time must be provided together")
      DateTime.compare(start_time, end_time) == :gt ->
        add_error(changeset, :start_time, "Start time must be before end time")
      true ->
        hours_from_times = DateTime.diff(end_time, start_time) / 3600
        case get_field(changeset, :hours) do
          nil -> put_change(changeset, :hours, Decimal.from_float(hours_from_times))
          hours -> validate_calculated_hours(changeset, hours, hours_from_times)
        end
    end
  end

  defp validate_calculated_hours(changeset, entered_hours, calculated_hours) do
    # Allow small differences due to rounding
    diff = abs(Decimal.to_float(entered_hours) - calculated_hours)
    if diff > 0.01 do
      add_error(changeset, :hours, "Hours don't match the time range (#{calculated_hours} hours)")
    else
      changeset
    end
  end

  def duration_in_hours(%__MODULE__{start_time: start_time, end_time: end_time})
      when not is_nil(start_time) and not is_nil(end_time) do
    DateTime.diff(end_time, start_time) / 3600
  end

  def duration_in_hours(_), do: 0
end
