import Config

# Use SQLite adapter for tests
config :timetracking_phoenix, :database_adapter, Ecto.Adapters.SQLite3

# Configure your database
config :timetracking_phoenix, TimetrackingPhoenix.Repo,
  database: "timetracking_phoenix_test#{System.get_env("MIX_TEST_PARTITION")}.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "your-secret-key-change-this-in-production",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
