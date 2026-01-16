#!/bin/bash

echo "🚀 Setting up TimeTracker Phoenix Application"
echo "=============================================="

# Add elixir-install paths to PATH if they exist
if [ -d "$HOME/.elixir-install/installs/otp/28.1/bin" ]; then
    export PATH="$HOME/.elixir-install/installs/otp/28.1/bin:$PATH"
fi
if [ -d "$HOME/.elixir-install/installs/elixir/1.19.4-otp-28/bin" ]; then
    export PATH="$HOME/.elixir-install/installs/elixir/1.19.4-otp-28/bin:$PATH"
fi

# Check if Elixir is installed
if ! command -v elixir &> /dev/null; then
    echo "❌ Elixir is not installed!"
    echo ""
    echo "Please install Elixir first. Here are some options:"
    echo ""
    echo "Option 1 - Using Homebrew (macOS):"
    echo "  brew install elixir"
    echo ""
    echo "Option 2 - Using asdf:"
    echo "  asdf plugin-add elixir"
    echo "  asdf install elixir latest"
    echo "  asdf global elixir latest"
    echo ""
    echo "Option 3 - Download from elixir-lang.org:"
    echo "  Visit https://elixir-lang.org/install.html"
    echo ""
    exit 1
fi

echo "✅ Elixir found: $(elixir --version)"

# Using SQLite database (no PostgreSQL required)
echo "🗄️  Using SQLite database (no additional setup needed)"

echo "📦 Installing Elixir dependencies..."
mix deps.get

echo "🗄️  Setting up database..."
mix ecto.setup

echo "🎨 Setting up assets..."
mix assets.setup

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the application:"
echo "  ./start.sh"
echo ""
echo "Then visit: http://localhost:4000"
echo ""
echo "Default login credentials:"
echo "  Admin: admin@example.com / password123"
echo "  Client: client@example.com / password123"
echo "  Developer 1: dev1@example.com / password123"
echo "  Developer 2: dev2@example.com / password123"
