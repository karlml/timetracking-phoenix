# Manual migration script
# Run with: elixir run_migrations_manual.exs

alias TimetrackingPhoenix.Repo

# Add columns to users table
Repo.query!("ALTER TABLE users ADD COLUMN default_rate DECIMAL(10, 2)")
Repo.query!("ALTER TABLE users ADD COLUMN default_currency TEXT DEFAULT 'USD'")

# Add column to project_members table
Repo.query!("ALTER TABLE project_members ADD COLUMN currency TEXT DEFAULT 'USD'")

IO.puts("✓ Migrations completed successfully!")
