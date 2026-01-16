defmodule TimetrackingPhoenix.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias TimetrackingPhoenix.Repo

  alias TimetrackingPhoenix.Accounts.User

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if user && valid_password?(user, password), do: user
  end

  defp valid_password?(%User{password_hash: hashed_password}, password) when is_binary(hashed_password) do
    Pow.Ecto.Schema.Password.pbkdf2_verify(password, hashed_password)
  end

  defp valid_password?(_, _), do: false

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Registers a user.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an changeset for tracking user changes.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    token = :crypto.strong_rand_bytes(32)
    Repo.insert!(%TimetrackingPhoenix.Accounts.UserToken{
      token: token,
      context: "session",
      user_id: user.id
    })
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    query = from t in TimetrackingPhoenix.Accounts.UserToken,
            where: t.token == ^token and t.context == "session",
            join: u in assoc(t, :user),
            select: u

    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(from t in TimetrackingPhoenix.Accounts.UserToken,
                    where: t.token == ^token and t.context == "session")
    :ok
  end

  @doc """
  Delivers the confirmation email instructions to the given user.
  """
  def deliver_user_confirmation_instructions(%User{} = _user, _confirmation_url_fun) do
    # For now, just return ok - email delivery can be added later
    {:ok, %{}}
  end

  @doc """
  Lists users by role.
  Checks both legacy `role` field and multi-role `roles` field (comma-separated).
  """
  def list_developers do
    # Match users with developer role in either the legacy role field or the multi-role roles field
    Repo.all(from u in User, 
      where: u.role == "developer" or 
             u.roles == "developer" or 
             like(u.roles, "developer,%") or 
             like(u.roles, "%,developer,%") or 
             like(u.roles, "%,developer"),
      order_by: [asc: u.first_name])
  end

  def list_clients do
    # Match users with client role in either the legacy role field or the multi-role roles field
    Repo.all(from u in User, 
      where: u.role == "client" or 
             u.roles == "client" or 
             like(u.roles, "client,%") or 
             like(u.roles, "%,client,%") or 
             like(u.roles, "%,client"),
      order_by: [asc: u.first_name])
  end

  def list_admins do
    # Match users with admin role in either the legacy role field or the multi-role roles field
    Repo.all(from u in User, 
      where: u.role == "admin" or 
             u.roles == "admin" or 
             like(u.roles, "admin,%") or 
             like(u.roles, "%,admin,%") or 
             like(u.roles, "%,admin"),
      order_by: [asc: u.first_name])
  end

  # =============================================================================
  # Admin User Management
  # =============================================================================

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(from u in User, order_by: [asc: u.role, asc: u.first_name])
  end

  @doc """
  Updates a user (admin function).
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user with specific role (admin function).
  """
  def create_user(attrs) do
    %User{}
    |> User.admin_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a user (admin function).
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an changeset for admin user editing.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.admin_changeset(user, attrs)
  end

  @doc """
  Switches the user's current role.
  Returns {:ok, user} or {:error, changeset}.
  """
  def switch_role(%User{} = user, new_role) do
    user
    |> User.switch_role_changeset(new_role)
    |> Repo.update()
  end

  @doc """
  Returns the list of valid roles.
  """
  def valid_roles, do: User.valid_roles()
end