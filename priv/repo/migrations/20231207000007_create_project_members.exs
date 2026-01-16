defmodule TimetrackingPhoenix.Repo.Migrations.CreateProjectMembers do
  use Ecto.Migration

  def change do
    create table(:project_members) do
      add :hourly_rate, :decimal
      add :role, :string, default: "developer"
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:project_members, [:project_id])
    create index(:project_members, [:user_id])
    create unique_index(:project_members, [:project_id, :user_id])
  end
end
