#!/bin/bash

echo "🚀 Starting TimeTracker Phoenix Application"
echo "==========================================="

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
    echo "Run ./setup.sh first to install dependencies."
    exit 1
fi

echo "🎨 Building assets..."
mix assets.build

echo "🖥️  Starting Phoenix server..."
echo ""
echo "Application will be available at: http://localhost:4000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

mix phx.server
