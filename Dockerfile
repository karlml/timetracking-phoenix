# Use the official Elixir image
FROM elixir:1.15-alpine

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory and copy the Elixir project
WORKDIR /app
COPY mix.exs mix.lock ./
COPY config config
COPY lib lib
COPY priv priv
COPY assets assets

# Install dependencies
RUN mix deps.get

# Compile the project
RUN mix compile

# Install Node.js for assets
RUN apk add --no-cache nodejs npm

# Install asset dependencies and build assets
RUN cd assets && npm install
RUN mix assets.setup
RUN mix assets.build

# Create the database and run migrations
RUN mix ecto.setup

# Expose port 4000
EXPOSE 4000

# Start the Phoenix server
CMD ["mix", "phx.server"]
