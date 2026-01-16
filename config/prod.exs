import Config

# Use PostgreSQL adapter for production
config :timetracking_phoenix, :database_adapter, Ecto.Adapters.Postgres

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
