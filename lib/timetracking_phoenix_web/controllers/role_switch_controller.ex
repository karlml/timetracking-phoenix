defmodule TimetrackingPhoenixWeb.RoleSwitchController do
  use TimetrackingPhoenixWeb, :controller

  alias TimetrackingPhoenix.Accounts

  def switch(conn, %{"role" => role}) do
    user = conn.assigns.current_user

    case Accounts.switch_role(user, role) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, "Switched to #{String.capitalize(role)} role")
        |> redirect(to: ~p"/dashboard")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to switch role. You may not have the #{role} role assigned.")
        |> redirect(to: ~p"/dashboard")
    end
  end
end
