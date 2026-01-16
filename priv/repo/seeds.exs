# Script for populating the database
alias TimetrackingPhoenix.Repo
alias TimetrackingPhoenix.Accounts.User

# Create admin user (with multi-role support)
admin = %User{
  email: "admin@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("admin123"),
  first_name: "Admin",
  last_name: "User",
  role: "admin",
  roles: "admin,developer",
  current_role: "admin",
  can_see_rate: true,
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(admin, on_conflict: :nothing)

# Create client user
client = %User{
  email: "client@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("client123"),
  first_name: "John",
  last_name: "Client",
  role: "client",
  roles: "client",
  current_role: "client",
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(client, on_conflict: :nothing)

# Create developer user
dev1 = %User{
  email: "dev@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("dev123"),
  first_name: "Alice",
  last_name: "Developer",
  role: "developer",
  roles: "developer",
  current_role: "developer",
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(dev1, on_conflict: :nothing)

IO.puts("✅ Database seeded!")
IO.puts("Demo accounts created:")
IO.puts("  Admin: admin@example.com / admin123")
IO.puts("  Client: client@example.com / client123")
IO.puts("  Developer: dev@example.com / dev123")