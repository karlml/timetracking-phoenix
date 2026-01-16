defmodule TimetrackingPhoenix.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string, null: false
      add :description, :text
      add :status, :string, default: "active"
      add :budget_hours, :decimal, precision: 10, scale: 2
      add :hourly_rate, :decimal, precision: 10, scale: 2
      add :start_date, :date
      add :end_date, :date
      add :client_id, references(:users, on_delete: :restrict)

      timestamps()
    end

    create index(:projects, [:client_id])
    create index(:projects, [:status])
  end
end
