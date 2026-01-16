defmodule TimetrackingPhoenix.Repo.Migrations.AddDefaultRateAndCurrencyToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :default_rate, :decimal, precision: 10, scale: 2
      add :default_currency, :string, default: "USD"
    end
  end
end
