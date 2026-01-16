defmodule TimetrackingPhoenixWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.
  """
  use Gettext.Backend, otp_app: :timetracking_phoenix
end