defmodule TimetrackingPhoenix.Repo.Migrations.CreateTimeEntries do
  use Ecto.Migration

  def change do
    create table(:time_entries) do
      add :date, :date, null: false
      add :hours, :decimal, precision: 8, scale: 2, null: false
      add :description, :text
      add :billable, :boolean, default: true
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :project_id, references(:projects, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:time_entries, [:user_id])
    create index(:time_entries, [:project_id])
    create index(:time_entries, [:date])
    create unique_index(:time_entries, [:user_id, :project_id, :date, :start_time],
                         name: :unique_time_entry_per_user_project_date_time)
  end
end
