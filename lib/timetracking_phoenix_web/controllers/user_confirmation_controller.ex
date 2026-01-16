defmodule TimetrackingPhoenixWeb.UserConfirmationController do
  use TimetrackingPhoenixWeb, :controller

  def new(conn, _params) do
    conn
    |> put_flash(:info, "Email confirmation not required for demo")
    |> redirect(to: "/")
  end

  def create(conn, _params) do
    conn
    |> put_flash(:info, "Email confirmation not required for demo")
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    conn
    |> put_flash(:info, "Email confirmation not required for demo")
    |> redirect(to: "/")
  end

  def update(conn, _params) do
    conn
    |> put_flash(:info, "Email confirmed successfully")
    |> redirect(to: "/dashboard")
  end
end
