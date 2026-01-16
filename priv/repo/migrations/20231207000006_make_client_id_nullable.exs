defmodule TimetrackingPhoenix.Repo.Migrations.MakeClientIdNullable do
  use Ecto.Migration

  def up do
    # In PostgreSQL, we can simply alter the column to drop NOT NULL constraint
    # The client_id column was already nullable in the original migration,
    # so this migration is essentially a no-op for PostgreSQL
    :ok
  end

  def down do
    :ok
  end
end
