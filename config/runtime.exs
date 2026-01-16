import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# application starts.

if System.get_env("PHX_SERVER") do
  config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :timetracking_phoenix, TimetrackingPhoenix.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "timetracking-phoenix.onrender.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

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
