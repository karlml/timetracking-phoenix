defmodule TimetrackingPhoenix.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :password_hash, :string
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :role, :string, default: "developer"

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
