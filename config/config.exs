# This file is responsible for configuring your application
import Config

# Ecto repos
config :timetracking_phoenix, ecto_repos: [TimetrackingPhoenix.Repo]

# Configure Pow authentication
config :timetracking_phoenix, :pow,
  user: TimetrackingPhoenix.Accounts.User,
  repo: TimetrackingPhoenix.Repo

# Configure the endpoint
config :timetracking_phoenix, TimetrackingPhoenixWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TimetrackingPhoenixWeb.ErrorHTML, json: TimetrackingPhoenixWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TimetrackingPhoenix.PubSub,
  live_view: [signing_salt: "abc123salt"]

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  timetracking_phoenix: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_ENV" => "development"}
  ]

# Configure the mailer
config :timetracking_phoenix, TimetrackingPhoenix.Mailer,
  adapter: Swoosh.Adapters.Local

# Configure Timex for date/time handling
config :timex, default_locale: "en"

# Configure logging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing
config :phoenix, :json_library, Jason

# Import environment specific config
import_config "#{config_env()}.exs"
