defmodule TimetrackingPhoenix.Repo.Migrations.AddCanSeeRateToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Controls whether the user can see/edit their own hourly rate
      # Default to false - admins must explicitly grant this permission
      add :can_see_rate, :boolean, default: false, null: false
    end

    # Admins should always be able to see rates - set true for existing admins
    execute "UPDATE users SET can_see_rate = true WHERE role = 'admin' OR roles LIKE '%admin%'"
  end
end
