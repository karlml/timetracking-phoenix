defmodule TimetrackingPhoenix.Projects.ProjectMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_members" do
    field :hourly_rate, :decimal
    field :currency, :string, default: "USD"
    field :role, :string, default: "developer"  # developer, lead, etc.

    belongs_to :project, TimetrackingPhoenix.Projects.Project
    belongs_to :user, TimetrackingPhoenix.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(project_member, attrs) do
    project_member
    |> cast(attrs, [:hourly_rate, :currency, :role, :project_id, :user_id])
    |> validate_required([:project_id, :user_id])
    |> validate_number(:hourly_rate, greater_than_or_equal_to: 0)
    |> validate_inclusion(:currency, ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "BRL", "MXN", "ZAR", "SEK", "NOK", "DKK", "PLN", "NZD", "SGD", "HKD", "KRW"], message: "must be a valid currency code")
    |> unique_constraint([:project_id, :user_id], name: :project_members_project_id_user_id_index)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:user_id)
  end
end
