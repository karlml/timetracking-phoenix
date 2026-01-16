defmodule TimetrackingPhoenix.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_roles ["developer", "admin", "client"]

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :first_name, :string
    field :last_name, :string
    field :role, :string, default: "developer"  # Legacy field, kept for compatibility
    field :roles, :string, default: "developer"  # Comma-separated roles
    field :current_role, :string, default: "developer"  # Currently active role
    field :confirmed_at, :naive_datetime
    field :default_currency, :string, default: "USD"
    field :can_see_rate, :boolean, default: false  # Whether user can see/edit their own hourly rate

    has_many :time_entries, TimetrackingPhoenix.TimeEntries.TimeEntry
    has_many :projects, TimetrackingPhoenix.Projects.Project, foreign_key: :client_id
    has_many :project_memberships, TimetrackingPhoenix.Projects.ProjectMember

    timestamps()
  end

  @doc "Returns the list of valid roles"
  def valid_roles, do: @valid_roles

  @doc "Returns the user's roles as a list"
  def roles_list(%__MODULE__{roles: nil}), do: ["developer"]
  def roles_list(%__MODULE__{roles: ""}), do: ["developer"]
  def roles_list(%__MODULE__{roles: roles}) when is_binary(roles) do
    roles |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))
  end

  @doc "Checks if user has a specific role"
  def has_role?(%__MODULE__{} = user, role) do
    role in roles_list(user)
  end

  @doc "Checks if user can access admin features"
  def is_admin?(%__MODULE__{current_role: "admin"}), do: true
  def is_admin?(_), do: false

  @doc "Checks if user can access client/admin features"
  def can_view_reports?(%__MODULE__{current_role: role}) when role in ["admin", "client"], do: true
  def can_view_reports?(_), do: false

  @doc "Checks if user can see/edit their own hourly rate (admins always can)"
  def can_see_own_rate?(%__MODULE__{current_role: "admin"}), do: true
  def can_see_own_rate?(%__MODULE__{can_see_rate: true}), do: true
  def can_see_own_rate?(_), do: false

  @valid_currencies ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "BRL", "MXN", "ZAR", "SEK", "NOK", "DKK", "PLN", "NZD", "SGD", "HKD", "KRW"]

  @doc false
  def changeset(user, attrs) do
    attrs = normalize_roles(attrs)
    
    user
    |> cast(attrs, [:email, :first_name, :last_name, :role, :roles, :current_role, :default_currency, :can_see_rate])
    |> validate_required([:email, :first_name, :last_name])
    |> validate_roles()
    |> validate_current_role()
    |> validate_inclusion(:default_currency, @valid_currencies, message: "must be a valid currency code")
    |> unique_constraint(:email)
    |> sync_legacy_role()
  end

  @doc false
  def registration_changeset(user, attrs) do
    attrs = normalize_roles(attrs)
    
    user
    |> cast(attrs, [:email, :password, :first_name, :last_name, :role, :roles, :current_role, :default_currency])
    |> validate_required([:email, :password, :first_name, :last_name])
    |> validate_length(:password, min: 6)
    |> validate_roles()
    |> validate_current_role()
    |> validate_inclusion(:default_currency, @valid_currencies, message: "must be a valid currency code")
    |> unique_constraint(:email)
    |> sync_legacy_role()
    |> hash_password()
  end

  # Normalize roles from list to comma-separated string
  defp normalize_roles(%{"roles" => roles} = attrs) when is_list(roles) do
    Map.put(attrs, "roles", Enum.join(roles, ","))
  end
  defp normalize_roles(attrs), do: attrs

  # Validate that all roles in the roles field are valid
  defp validate_roles(changeset) do
    case get_field(changeset, :roles) do
      nil -> changeset
      "" -> changeset
      roles_string ->
        roles = roles_string |> String.split(",") |> Enum.map(&String.trim/1)
        invalid_roles = Enum.reject(roles, &(&1 in @valid_roles))
        
        if invalid_roles == [] do
          changeset
        else
          add_error(changeset, :roles, "contains invalid roles: #{Enum.join(invalid_roles, ", ")}")
        end
    end
  end

  # Validate that current_role is one of the user's assigned roles
  defp validate_current_role(changeset) do
    current_role = get_field(changeset, :current_role)
    roles_string = get_field(changeset, :roles) || ""
    roles = roles_string |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))
    
    cond do
      current_role == nil -> changeset
      roles == [] -> changeset
      current_role in roles -> changeset
      true -> add_error(changeset, :current_role, "must be one of the assigned roles")
    end
  end

  # Sync the legacy role field with current_role for backwards compatibility
  defp sync_legacy_role(changeset) do
    case get_field(changeset, :current_role) do
      nil -> changeset
      current_role -> put_change(changeset, :role, current_role)
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password ->
        hashed = Pow.Ecto.Schema.Password.pbkdf2_hash(password)
        put_change(changeset, :password_hash, hashed)
    end
  end

  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Admin changeset for creating/editing users.
  Password is optional for updates.
  """
  def admin_changeset(user, attrs) do
    attrs = normalize_roles(attrs)
    
    changeset = user
    |> cast(attrs, [:email, :password, :first_name, :last_name, :role, :roles, :current_role, :confirmed_at, :default_currency, :can_see_rate])
    |> validate_required([:email, :first_name, :last_name])
    |> validate_roles()
    |> validate_current_role()
    |> validate_inclusion(:default_currency, @valid_currencies, message: "must be a valid currency code")
    |> unique_constraint(:email)
    |> sync_legacy_role()
    |> ensure_roles_set()

    # Only validate and hash password if it's provided
    if get_change(changeset, :password) do
      changeset
      |> validate_length(:password, min: 6)
      |> hash_password()
    else
      changeset
    end
  end

  # Ensure roles is set if not provided
  defp ensure_roles_set(changeset) do
    if get_field(changeset, :roles) in [nil, ""] do
      put_change(changeset, :roles, "developer")
    else
      changeset
    end
  end

  @doc """
  Changeset for switching the current role.
  """
  def switch_role_changeset(user, new_role) do
    if has_role?(user, new_role) do
      user
      |> change(current_role: new_role, role: new_role)
    else
      user
      |> change()
      |> add_error(:current_role, "you don't have the #{new_role} role")
    end
  end

  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end
end