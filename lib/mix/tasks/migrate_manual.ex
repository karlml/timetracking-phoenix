defmodule Mix.Tasks.MigrateManual do
  use Mix.Task

  @shortdoc "Manually add missing columns for rates and currencies"

  @moduledoc """
  This task manually adds the missing columns to the database.
  Run with: mix migrate_manual
  """

  def run(_args) do
    Mix.Task.run("app.start")

    alias TimetrackingPhoenix.Repo

    IO.puts("Adding columns to users table...")
    
    try do
      Repo.query!("ALTER TABLE users ADD COLUMN default_rate DECIMAL(10, 2)")
      IO.puts("  ✓ Added default_rate column")
    rescue
      e ->
        if String.contains?(inspect(e), "duplicate column") do
          IO.puts("  ⚠ default_rate column already exists")
        else
          raise e
        end
    end

    try do
      Repo.query!("ALTER TABLE users ADD COLUMN default_currency TEXT DEFAULT 'USD'")
      IO.puts("  ✓ Added default_currency column")
    rescue
      e ->
        if String.contains?(inspect(e), "duplicate column") do
          IO.puts("  ⚠ default_currency column already exists")
        else
          raise e
        end
    end

    IO.puts("Adding column to project_members table...")
    
    try do
      Repo.query!("ALTER TABLE project_members ADD COLUMN currency TEXT DEFAULT 'USD'")
      IO.puts("  ✓ Added currency column")
    rescue
      e ->
        if String.contains?(inspect(e), "duplicate column") do
          IO.puts("  ⚠ currency column already exists")
        else
          raise e
        end
    end

    IO.puts("\n✓ All migrations completed successfully!")
  end
end
