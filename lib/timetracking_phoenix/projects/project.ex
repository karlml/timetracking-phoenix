defmodule TimetrackingPhoenix.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_currencies ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "BRL", "MXN", "ZAR", "SEK", "NOK", "DKK", "PLN", "NZD", "SGD", "HKD", "KRW"]

  schema "projects" do
    field :name, :string
    field :description, :string
    field :client_name, :string
    field :status, :string, default: "active" # active, completed, paused
    field :budget_hours, :decimal
    field :hourly_rate, :decimal
    field :currency, :string, default: "USD"
    field :start_date, :date
    field :end_date, :date

    belongs_to :client, TimetrackingPhoenix.Accounts.User
    belongs_to :user, TimetrackingPhoenix.Accounts.User
    has_many :time_entries, TimetrackingPhoenix.TimeEntries.TimeEntry
    has_many :project_members, TimetrackingPhoenix.Projects.ProjectMember
    has_many :members, through: [:project_members, :user]

    timestamps()
  end

  def valid_currencies, do: @valid_currencies

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :client_name, :status, :budget_hours, :hourly_rate, :currency, :start_date, :end_date, :client_id, :user_id])
    |> validate_required([:name])
    |> validate_inclusion(:status, ["active", "completed", "paused"])
    |> validate_inclusion(:currency, @valid_currencies, message: "must be a valid currency code")
    |> validate_number(:budget_hours, greater_than: 0)
    |> validate_number(:hourly_rate, greater_than: 0)
    |> foreign_key_constraint(:client_id)
  end

  def total_hours(project) do
    project.time_entries
    |> Enum.reduce(Decimal.new(0), fn entry, acc ->
      Decimal.add(acc, entry.hours)
    end)
  end

  def remaining_budget_hours(project) do
    if project.budget_hours do
      Decimal.sub(project.budget_hours, total_hours(project))
    else
      nil
    end
  end

  def total_cost(project) do
    if project.hourly_rate do
      Decimal.mult(total_hours(project), project.hourly_rate)
    else
      Decimal.new(0)
    end
  end
end
