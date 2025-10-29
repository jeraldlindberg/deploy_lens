defmodule DeployLensWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.Poller.html
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Add reporters as children of your supervision tree.
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # GitHub API Metrics
      counter("github.client.request.count",
        event_name: [:github_client, :request]
      ),
      counter("github.client.request.success.count",
        event_name: [:github_client, :request, :success]
      ),
      counter("github.client.request.error.count",
        event_name: [:github_client, :request, :error]
      ),
      counter("github.client.rate_limit_low.count",
        event_name: [:github_client, :rate_limit_low]
      ),

      # Log Cache Metrics
      counter("log_cache.hit.count",
        event_name: [:github_client, :get_job_logs, :cache_hit]
      ),
      counter("log_cache.miss.count",
        event_name: [:github_client, :get_job_logs, :cache_miss]
      ),
      counter("github.client.get_job_logs.error.count",
        event_name: [:github_client, :get_job_logs, :error]
      ),
      counter("github.client.get_job_logs.success.count",
        event_name: [:github_client, :get_job_logs, :success]
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be defined above.
      # {DeployLensWeb, :count_users, []}
    ]
  end
end