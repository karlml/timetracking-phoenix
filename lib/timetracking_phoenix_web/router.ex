defmodule TimetrackingPhoenixWeb.Router do
  use TimetrackingPhoenixWeb, :router

  import TimetrackingPhoenixWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TimetrackingPhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end


  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TimetrackingPhoenixWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Authentication routes
    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    patch "/users/confirm/:token", UserConfirmationController, :update
  end

  scope "/", TimetrackingPhoenixWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Role switching
    post "/switch_role/:role", RoleSwitchController, :switch

    live_session :authenticated,
      on_mount: [{TimetrackingPhoenixWeb.UserAuth, :ensure_authenticated}] do
      # Time tracking routes
      live "/dashboard", DashboardLive.Index, :index
      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.Index, :new
      live "/projects/:id/edit", ProjectLive.Index, :edit
      live "/projects/:id", ProjectLive.Show, :show
      live "/projects/:id/show/edit", ProjectLive.Show, :edit
      live "/projects/:id/members", ProjectLive.Members, :index

      # Time entries
      live "/time_entries", TimeEntryLive.Index, :index

      # Reports
      live "/reports", ReportLive.Index, :index

      # Admin: User management
      live "/users", UserLive.Index, :index
      live "/users/new", UserLive.Index, :new
      live "/users/:id/edit", UserLive.Index, :edit
    end

    get "/reports/export/:project_id", ReportController, :export
  end

  # Other scopes may use custom stacks.
  # scope "/api", TimetrackingPhoenixWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:timetracking_phoenix, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TimetrackingPhoenixWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
