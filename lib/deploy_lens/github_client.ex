defmodule DeployLens.GitHubClient do
  use Tesla

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

  def get_workflow_runs(client, owner, repo) do
    safe_request(client, fn client ->
      get(client, "/repos/#{owner}/#{repo}/actions/runs")
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
        {:ok, logs}

      {:error, :not_found} ->
        safe_request(client, fn client ->
          # For this call ONLY, disable autoredirects and skip the JSON parser.
          opts = [adapter: [autoredirect: false], tesla: [skip: [Tesla.Middleware.JSON]]]

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
                  IO.inspect(headers, label: "Headers received without 'location'")
                  {:error, :no_location_header}

                location_url ->
                  # Now, make a fresh, clean request to the Azure URL.
                  case Tesla.get(location_url) do
                    {:ok, %{status: 200, body: logs}} = success_response ->
                      DeployLens.LogCache.put(job_id, logs)
                      success_response

                    error_response ->
                      error_response
                  end
              end

            # Handle cases where GitHub returns an error directly.
            {:error, reason} ->
              {:error, reason}

            # Handle unexpected success (e.g., if logs were in the body).
            {:ok, result} ->
              {:ok, result}
          end
        end)
    end
  end

  def get_deployments(client, owner, repo) do
    safe_request(client, fn client ->
      get(client, "/repos/#{owner}/#{repo}/deployments")
    end)
  end

  defp safe_request(client, fun) do
    with {:ok, rate_limit_info} <- fetch_rate_limit(client),
         :ok <- check_rate_limit(rate_limit_info) do
      fun.(client)
      |> tap(&update_rate_limit_from_response/1)
    else
      error -> error
    end
  end

  defp fetch_rate_limit(client) do
    case DeployLens.RateLimitCache.get() do
      {:ok, data} ->
        {:ok, data}
      {:error, :not_found} ->
        with {:ok, %{body: body}} <- get_rate_limit(client) do
          DeployLens.RateLimitCache.put(body)
          {:ok, body}
        end
    end
  end

  defp check_rate_limit(rate_limit_info) do
    threshold = Application.get_env(:deploy_lens, :github_rate_limit_threshold, 100)
    remaining = get_in(rate_limit_info, ["resources", "core", "remaining"])

    if remaining && remaining < threshold do
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
      {:ok, current_data} = DeployLens.RateLimitCache.get()
      updated_data = 
        current_data
        |> put_in(["resources", "core", "remaining"], remaining)
        |> put_in(["resources", "core", "reset"], reset)

      DeployLens.RateLimitCache.put(updated_data)
    end

    response
  end

  defp update_rate_limit_from_response(other), do: other

  def get_rate_limit(client) do
    get(client, "/rate_limit")
  end
end
