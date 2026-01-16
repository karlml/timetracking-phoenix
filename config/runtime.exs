import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# temporary stop, which means you can read and write to any file in
# the project directory.

if System.get_env("PHX_SERVER") do
  config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/timetracking_phoenix.db
      """

  config :timetracking_phoenix, TimetrackingPhoenix.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "timetracking-phoenix.fly.dev"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :timetracking_phoenix, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Configure Pow for production
  config :timetracking_phoenix, :pow,
    user: TimetrackingPhoenix.Accounts.User,
    repo: TimetrackingPhoenix.Repo
end
