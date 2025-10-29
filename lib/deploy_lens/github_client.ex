defmodule DeployLens.GitHubClient do
  use Tesla
  require Logger

  # Define an adapter with redirect enabled for general use.
  @adapter {Tesla.Adapter.Httpc, [autoredirect: true]}

  plug Tesla.Middleware.BaseUrl, "https://api.github.com"

  plug Tesla.Middleware.Headers, [
    {"Accept", "application/vnd.github+json"},
    {"X-GitHub-Api-Version", "2022-11-28"},
    {"User-Agent", "DeployLens-App"}
  ]

  plug Tesla.Middleware.JSON

  def new(token) do
    # Pass the middleware AND the adapter to Tesla.client/2
    Tesla.client(
      [
        {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{token}"}]}
      ],
      @adapter
    )
  end

    def get_workflow_runs(client, owner, repo, page, per_page) do

      safe_request(client, fn client ->

        get(client, "/repos/#{owner}/#{repo}/actions/runs",

          params: [page: page, per_page: per_page]

        )

      end)

    end

  def get_workflow_run_jobs(client, owner, repo, run_id) do
    safe_request(client, fn client ->
      get(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs")
    end)
  end

  # Gets the raw log content for a specific job by handling redirects manually.
  def get_job_logs(client, owner, repo, job_id) do
    case DeployLens.LogCache.get(job_id) do
      {:ok, logs} ->
        :telemetry.execute([:github_client, :get_job_logs, :cache_hit], %{count: 1}, %{job_id: job_id})
        {:ok, logs}

      {:error, :not_found} ->
        :telemetry.execute([:github_client, :get_job_logs, :cache_miss], %{count: 1}, %{job_id: job_id})

        # For this call ONLY, disable autoredirects.
        opts = [adapter: [autoredirect: false]]

        # First, we ask GitHub for the log URL.
        case get(client, "/repos/#{owner}/#{repo}/actions/jobs/#{job_id}/logs", opts: opts) do
          # GitHub responded with a 302 Redirect, which is what we expect.
          {:ok, %{status: 302, headers: headers}} ->
            # --- MODIFIED: Case-insensitive header lookup ---
            # Convert header keys to lowercase to find "location" reliably.
            normalized_headers =
              Enum.into(headers, %{}, fn {key, val} -> {String.downcase(key), val} end)

            case Map.get(normalized_headers, "location") do
              nil ->
                # Log the headers so we can see what we got
                Logger.error("No 'location' header in 302 response for job #{job_id}")
                :telemetry.execute([:github_client, :get_job_logs, :error], %{count: 1}, %{job_id: job_id, reason: :no_location_header})
                {:error, :no_location_header}

              location_url ->
                # Now, make a fresh, clean request to the Azure URL.
                case Tesla.get(location_url) do
                  {:ok, %{status: 200, body: logs}} ->
                    DeployLens.LogCache.put(job_id, logs)
                    :telemetry.execute([:github_client, :get_job_logs, :success], %{count: 1}, %{job_id: job_id})
                    {:ok, logs}

                  {:ok, %{status: status, body: body}} ->
                    Logger.error(
                      "Failed to fetch logs from Azure for job #{job_id}. " <>
                      "Status: #{status}, Body: #{inspect(body)}"
                    )
                    :telemetry.execute([:github_client, :get_job_logs, :error], %{count: 1}, %{status: status, job_id: job_id, reason: :azure_log_fetch_failed})
                    {:error, :azure_log_fetch_failed, status}

                  {:error, reason} ->
                    Logger.error(
                      "HTTP error fetching logs from Azure for job #{job_id}. " <>
                      "Reason: #{inspect(reason)}"
                    )
                    :telemetry.execute([:github_client, :get_job_logs, :error], %{count: 1}, %{job_id: job_id, reason: :azure_log_fetch_error})
                    {:error, :azure_log_fetch_error, reason}
                end
            end

          # Handle cases where GitHub returns an error directly.
          {:ok, %{status: status, body: body}} when status in 400..599 ->
            Logger.error(
              "GitHub API error when fetching log URL for job #{job_id}. " <>
              "Status: #{status}, Body: #{inspect(body)}"
            )
            :telemetry.execute([:github_client, :get_job_logs, :error], %{count: 1}, %{status: status, job_id: job_id, reason: :github_api_error})
            {:error, :github_api_error, %{status: status, body: body}}

          {:error, reason} ->
            Logger.error(
              "HTTP error when fetching log URL for job #{job_id}. " <>
              "Reason: #{inspect(reason)}"
            )
            :telemetry.execute([:github_client, :get_job_logs, :error], %{count: 1}, %{job_id: job_id, reason: :github_client_error})
            {:error, :github_client_error, reason}
        end
    end
  end

  def get_deployments(client, owner, repo) do
    safe_request(client, fn client ->
      get(client, "/repos/#{owner}/#{repo}/deployments")
    end)
  end

  defp safe_request(client, fun) do
    :telemetry.execute([:github_client, :request], %{count: 1}, %{client: client})

    with {:ok, rate_limit_info} <- fetch_rate_limit(client),
         :ok <- check_rate_limit(rate_limit_info) do
      case fun.(client) do
        {:ok, %{status: 200, body: body}} ->
          :telemetry.execute([:github_client, :request, :success], %{count: 1}, %{status: 200})
          {:ok, body}

        {:ok, %{status: status, body: body}} when status in 400..599 ->
          :telemetry.execute([:github_client, :request, :error], %{count: 1}, %{status: status, body: body})
          {:error, :github_api_error, %{status: status, body: body}}

        {:error, reason} ->
          :telemetry.execute([:github_client, :request, :error], %{count: 1}, %{reason: reason})
          {:error, :github_client_error, reason}
      end
      |> tap(&update_rate_limit_from_response/1)
    else
      error ->
        :telemetry.execute([:github_client, :request, :error], %{count: 1}, %{error: error})
        error
    end
  end

  defp fetch_rate_limit(client) do
    case DeployLens.RateLimitCache.get() do
      {:ok, data} ->
        {:ok, data}

      {:error, :not_found} ->
        case get_rate_limit(client) do
          {:ok, %{body: body}} ->
            DeployLens.RateLimitCache.put(body)
            {:ok, body}

          {:error, reason} ->
            Logger.error("Failed to fetch initial rate limit: #{inspect(reason)}")
            {:error, :initial_rate_limit_fetch_failed, reason}
        end
    end
  end

  defp check_rate_limit(rate_limit_info) do
    threshold = Application.get_env(:deploy_lens, :github_rate_limit_threshold, 100)
    remaining = get_in(rate_limit_info, ["resources", "core", "remaining"])

    if remaining && remaining < threshold do
      :telemetry.execute([:github_client, :rate_limit_low], %{count: 1}, %{remaining: remaining})
      {:error, :rate_limit_low}
    else
      :ok
    end
  end

  defp update_rate_limit_from_response({:ok, %{headers: headers}} = response) do
    # Headers are a list of {key, value} tuples. Find the ones we need.
    remaining_str = List.keyfind(headers, "x-ratelimit-remaining", 0)
    reset_str = List.keyfind(headers, "x-ratelimit-reset", 0)

    # Conditionally update the cache if the headers are present.
    if remaining_str && reset_str do
      remaining = String.to_integer(elem(remaining_str, 1))
      reset = String.to_integer(elem(reset_str, 1))

      # Fetch the current rate limit data, update it, and put it back.
      case DeployLens.RateLimitCache.get() do
        {:ok, current_data} ->
          updated_data = 
            current_data
            |> put_in(["resources", "core", "remaining"], remaining)
            |> put_in(["resources", "core", "reset"], reset)

          DeployLens.RateLimitCache.put(updated_data)

        {:error, _} ->
          # If the cache is empty, we can't update it, but it's not a critical error.
          # The next call to `fetch_rate_limit` will repopulate it.
          :ok
      end
    end

    response
  end

  defp update_rate_limit_from_response(other), do: other

  def get_rate_limit(client) do
    get(client, "/rate_limit")
  end
end
