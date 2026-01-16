#!/usr/bin/env python3
"""
TimeTracker Phoenix Demo Server

This script starts a simple HTTP server to demonstrate the TimeTracker application.
Since Elixir/Phoenix isn't available in this environment, this HTML demo shows
what the real application would look like.
"""

import http.server
import socketserver
import os
import webbrowser
from pathlib import Path

PORT = 8000

class DemoHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = '/demo/index.html'
        elif not self.path.startswith('/demo/'):
            self.path = '/demo' + self.path
        return super().do_GET()

def main():
    # Change to the project directory
    project_dir = Path(__file__).parent
    os.chdir(project_dir)

    print("🚀 TimeTracker Phoenix Demo")
    print("=" * 40)
    print()
    print("Starting demo server...")
    print(f"📱 Visit: http://localhost:{PORT}")
    print()
    print("Demo pages:")
    print(f"  🏠 Home:     http://localhost:{PORT}/")
    print(f"  🔐 Login:    http://localhost:{PORT}/login.html")
    print(f"  📊 Dashboard: http://localhost:{PORT}/dashboard.html")
    print()
    print("To run the real Phoenix app:")
    print("  1. Install Elixir: https://elixir-lang.org/install.html")
    print("  2. Install PostgreSQL")
    print("  3. Run: ./setup.sh && ./start.sh")
    print()
    print("Press Ctrl+C to stop the demo server")
    print()

    # Try to open browser automatically
    try:
        webbrowser.open(f"http://localhost:{PORT}")
    except:
        pass

    # Start server
    with socketserver.TCPServer(("", PORT), DemoHTTPRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Demo server stopped")

if __name__ == "__main__":
    main()
