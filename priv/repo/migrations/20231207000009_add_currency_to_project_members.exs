defmodule TimetrackingPhoenix.Repo.Migrations.AddCurrencyToProjectMembers do
  use Ecto.Migration

  def change do
    alter table(:project_members) do
      add :currency, :string, default: "USD"
    end
  end
end
