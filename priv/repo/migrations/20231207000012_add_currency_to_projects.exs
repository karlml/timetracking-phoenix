defmodule TimetrackingPhoenix.Repo.Migrations.AddCurrencyToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :currency, :string, default: "USD", null: false
    end
  end
end
