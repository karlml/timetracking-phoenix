defmodule TimetrackingPhoenix.Repo.Migrations.AddClientNameAndUserIdToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :client_name, :string
      add :user_id, references(:users, on_delete: :nothing)
    end

    create index(:projects, [:user_id])
  end
end
