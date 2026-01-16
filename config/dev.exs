import Config

# Configure your database (PostgreSQL for dev)
config :timetracking_phoenix, TimetrackingPhoenix.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "timetracking_phoenix_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable debugging
config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:timetracking_phoenix, ~w(--sourcemap=inline --watch)]}
  ]

# Watch static and templates for browser reloading
config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/timetracking_phoenix_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :timetracking_phoenix, dev_routes: true

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client
config :swoosh, :api_client, false
