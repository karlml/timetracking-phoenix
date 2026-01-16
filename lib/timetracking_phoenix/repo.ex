defmodule TimetrackingPhoenix.Repo do
  use Ecto.Repo,
    otp_app: :timetracking_phoenix,
    adapter: Ecto.Adapters.SQLite3
end
