# Script for populating the database
alias TimetrackingPhoenix.Repo
alias TimetrackingPhoenix.Accounts.User

# Create admin user
admin = %User{
  email: "admin@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("password123"),
  first_name: "Admin",
  last_name: "User",
  role: "admin",
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(admin, on_conflict: :nothing)

# Create client user
client = %User{
  email: "client@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("password123"),
  first_name: "John",
  last_name: "Client",
  role: "client",
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(client, on_conflict: :nothing)

# Create developer users
dev1 = %User{
  email: "dev1@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("password123"),
  first_name: "Alice",
  last_name: "Developer",
  role: "developer",
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(dev1, on_conflict: :nothing)

dev2 = %User{
  email: "dev2@example.com",
  password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("password123"),
  first_name: "Bob",
  last_name: "Coder",
  role: "developer",
  confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
}
Repo.insert!(dev2, on_conflict: :nothing)

IO.puts("✅ Database seeded!")
IO.puts("Test accounts created:")
IO.puts("  Admin: admin@example.com / password123")
IO.puts("  Client: client@example.com / password123")
IO.puts("  Developer 1: dev1@example.com / password123")
IO.puts("  Developer 2: dev2@example.com / password123")