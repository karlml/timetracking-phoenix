defmodule TimetrackingPhoenixWeb.PageController do
  use TimetrackingPhoenixWeb, :controller

  def home(conn, _params) do
    render(conn, :home, page_title: "TimeTracker - Track your work hours")
  end
end
