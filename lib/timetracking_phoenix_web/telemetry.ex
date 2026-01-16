defmodule TimetrackingPhoenixWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
              tags: [:method, :request_path],
              unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
              tags: [:method, :request_path, :status],
              unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
              tags: [:method, :route],
              unit: {:native, :millisecond},
              description: "The time spent in the router"
      ),
      summary("phoenix.router_dispatch.exception.duration",
              tags: [:method, :route],
              unit: {:native, :millisecond},
              description: "The time spent in the router when an exception occurs"
      ),
      summary("phoenix.socket_connected.duration",
              tags: [:transport],
              unit: {:native, :millisecond},
              description: "The time spent setting up a socket connection"
      ),
      summary("phoenix.channel_join.duration",
              tags: [:channel],
              unit: {:native, :millisecond},
              description: "The time spent joining channels"
      ),
      summary("phoenix.channel_handled_in.duration",
              tags: [:event, :channel],
              unit: {:native, :millisecond},
              description: "The time spent handling channel events"
      ),

      # Database Metrics
      summary("timetracking_phoenix.repo.query.total_time",
              unit: {:native, :millisecond},
              description: "The sum of the other measurements"
      ),
      summary("timetracking_phoenix.repo.query.decode_time",
              unit: {:native, :millisecond},
              description: "The time spent decoding the data received from the database"
      ),
      summary("timetracking_phoenix.repo.query.query_time",
              unit: {:native, :millisecond},
              description: "The time spent executing the query"
      ),
      summary("timetracking_phoenix.repo.query.queue_time",
              unit: {:native, :millisecond},
              description: "The time spent waiting for a database connection"
      ),
      summary("timetracking_phoenix.repo.query.idle_time",
              unit: {:native, :millisecond},
              description: "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a measurement name.
      # {TimetrackingPhoenixWeb, :count_users, []}
    ]
  end
end
