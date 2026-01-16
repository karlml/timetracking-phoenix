defmodule TimetrackingPhoenix.Repo.Migrations.AddMultipleRolesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :roles, :string, default: "developer"
      add :current_role, :string, default: "developer"
    end

    # Migrate existing role data to roles field
    execute "UPDATE users SET roles = role, current_role = role WHERE role IS NOT NULL"
  end
end
