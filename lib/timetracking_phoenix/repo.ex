defmodule TimetrackingPhoenix.Repo do
  use Ecto.Repo,
    otp_app: :timetracking_phoenix,
    adapter: Application.compile_env(:timetracking_phoenix, :database_adapter, Ecto.Adapters.Postgres)
end
