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
    get(client, "/repos/#{owner}/#{repo}/actions/runs")
  end

  def get_workflow_run_jobs(client, owner, repo, run_id) do
    get(client, "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs")
  end

  # Gets the raw log content for a specific job by handling redirects manually.
  def get_job_logs(client, owner, repo, job_id) do
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
            Tesla.get(location_url)
        end

      # Handle cases where GitHub returns an error directly.
      {:error, reason} ->
        {:error, reason}

      # Handle unexpected success (e.g., if logs were in the body).
      {:ok, result} ->
        {:ok, result}
    end
  end

  def get_deployments(client, owner, repo) do
    get(client, "/repos/#{owner}/#{repo}/deployments")
  end
end
