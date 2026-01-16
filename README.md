# TimeTracker Phoenix

A professional time tracking application built with Phoenix LiveView for developers and agencies to track work hours and generate client reports.

## Features

- **Time Tracking**: Log hours manually or with timers
- **Project Management**: Organize work by projects and clients
- **User Roles**: Support for developers, clients, and admins
- **Reports**: Generate detailed reports for client billing
- **Authentication**: Secure user authentication with Pow
- **Real-time Updates**: LiveView for instant UI updates

## Quick Start

### Option 1: Automated Setup (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

2. **Start the application:**
   ```bash
   ./start.sh
   ```

### Option 2: Manual Setup

#### Prerequisites

- Elixir 1.14 or later
- PostgreSQL
- Node.js (for assets)

#### Installation

1. **Install Elixir dependencies:**
   ```bash
   mix deps.get
   ```

2. **Create and migrate the database:**
   ```bash
   mix ecto.setup
   ```

3. **Install Node.js dependencies:**
   ```bash
   mix assets.setup
   ```

4. **Start the Phoenix server:**
   ```bash
   mix phx.server
   ```

   Or with an interactive shell:
   ```bash
   iex -S mix phx.server
   ```

The application will be available at `http://localhost:4000`.

## Default Login Credentials

After running setup, you can login with these accounts:

- **Admin**: `admin@example.com` / `password123`
- **Client**: `client@example.com` / `password123`
- **Developer 1**: `dev1@example.com` / `password123`
- **Developer 2**: `dev2@example.com` / `password123`

### Option 3: Docker Setup

If you have Docker and Docker Compose installed:

1. **Start the application:**
   ```bash
   docker-compose up --build
   ```

2. **Access the application:**
   - Phoenix app: `http://localhost:4000`
   - PostgreSQL: `localhost:5432`

The application will automatically set up the database and seed it with sample data.

## Usage

### User Roles

- **Developers**: Can log time entries on assigned projects
- **Clients**: Can view projects and reports for their work
- **Admins**: Full access to all features and user management

### Getting Started

1. Visit `http://localhost:4000` and click "Get Started"
2. Create your account
3. If you're an admin, create projects and assign developers
4. Start logging time on projects

### Key Features

- **Dashboard**: Overview of your time entries and active projects
- **Time Entries**: Log and manage your work hours
- **Projects**: View project details and budgets
- **Reports**: Generate client reports and export data

## Development

### Running Tests

```bash
mix test
```

### Database Management

```bash
# Create migration
mix ecto.gen.migration create_example_table

# Run migrations
mix ecto.migrate

# Rollback
mix ecto.rollback

# Reset database
mix ecto.reset
```

### Assets

```bash
# Build assets for production
mix assets.deploy
```

## Deployment

This application can be deployed to any platform that supports Elixir/Phoenix applications, including:

- Fly.io
- Heroku
- Gigalixir
- Docker containers

Make sure to set the following environment variables in production:

- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY_BASE`: Secret key for session encryption
- `PHX_HOST`: Your domain name

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

This project is licensed under the MIT License.
