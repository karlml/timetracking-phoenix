defmodule TimetrackingPhoenix.Repo.Migrations.MakeClientIdNullable do
  use Ecto.Migration

  def up do
    # SQLite doesn't support ALTER COLUMN, so we need to recreate the table
    # First, let's just drop the foreign key constraint by recreating without it
    execute "PRAGMA foreign_keys = OFF"
    
    execute """
    CREATE TABLE projects_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      client_name TEXT,
      status TEXT DEFAULT 'active',
      budget_hours DECIMAL,
      hourly_rate DECIMAL,
      start_date DATE,
      end_date DATE,
      client_id INTEGER REFERENCES users(id),
      user_id INTEGER REFERENCES users(id),
      inserted_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL
    )
    """

    execute "INSERT INTO projects_new SELECT id, name, description, client_name, status, budget_hours, hourly_rate, start_date, end_date, client_id, user_id, inserted_at, updated_at FROM projects"
    execute "DROP TABLE projects"
    execute "ALTER TABLE projects_new RENAME TO projects"
    
    execute "CREATE INDEX projects_client_id_index ON projects(client_id)"
    execute "CREATE INDEX projects_status_index ON projects(status)"
    execute "CREATE INDEX projects_user_id_index ON projects(user_id)"
    
    execute "PRAGMA foreign_keys = ON"
  end

  def down do
    # Cannot easily reverse this migration
    :ok
  end
end
