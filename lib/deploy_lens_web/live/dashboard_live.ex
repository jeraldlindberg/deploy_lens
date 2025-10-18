defmodule DeployLensWeb.DashboardLive do
  use DeployLensWeb, :live_view

  alias DeployLens.GitHubClient

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       # Existing state
       workflow_runs: [],
       loading: false,
       # New state
       owner: nil,
       repo: nil,
       jobs_cache: %{},
       log_cache: %{},
       expanded_runs: MapSet.new(),
       loading_jobs: MapSet.new(),
       loading_logs: MapSet.new()
     )}
  end

  @impl true
  def handle_event("fetch_runs", %{"owner" => owner, "repo" => repo}, socket) do
    token = Application.get_env(:deploy_lens, :github_token)
    client = GitHubClient.new(token)
    socket = assign(socket, loading: true, owner: owner, repo: repo)

    case GitHubClient.get_workflow_runs(client, owner, repo) do
      {:ok, %{body: %{"workflow_runs" => runs}}} ->
        {:noreply, assign(socket, workflow_runs: runs, loading: false)}

      {:ok, %{status: status, body: body}} ->
        error_msg = "GitHub API returned status #{status}: #{inspect(body)}"
        {:noreply, socket |> put_flash(:error, error_msg) |> assign(loading: false)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to fetch workflow runs")}
    end
  end

  # --- This function remains the same ---
  def handle_event("toggle_jobs", %{"run-id" => run_id}, socket) do
    run_id = String.to_integer(run_id)

    if Map.has_key?(socket.assigns.jobs_cache, run_id) do
      socket = update(socket, :expanded_runs, &MapSet.toggle(&1, run_id))
      {:noreply, socket}
    else
      socket = update(socket, :loading_jobs, &MapSet.put(&1, run_id))
      token = Application.get_env(:deploy_lens, :github_token)
      client = GitHubClient.new(token)
      %{owner: owner, repo: repo} = socket.assigns

      # This Task.async call sends a message like {#Reference, result}
      Task.async(fn ->
        case GitHubClient.get_workflow_run_jobs(client, owner, repo, run_id) do
          {:ok, %{body: %{"jobs" => jobs}}} -> {:jobs_fetched, run_id, jobs}
          {:error, reason} -> {:jobs_failed, run_id, reason}
        end
      end)

      {:noreply, socket}
    end
  end

  # --- This function remains the same, but the task now returns the message ---
def handle_event("fetch_logs", %{"job-id" => job_id}, socket) do
  job_id = String.to_integer(job_id)

  if Map.has_key?(socket.assigns.log_cache, job_id) do
    {:noreply, socket}
  else
    socket = update(socket, :loading_logs, &MapSet.put(&1, job_id))
    token = Application.get_env(:deploy_lens, :github_token)
    client = GitHubClient.new(token)
    %{owner: owner, repo: repo} = socket.assigns

    Task.async(fn ->
      # --- MODIFICATION START ---
      # Call the API once, store the result, and print it to the console
      result = GitHubClient.get_job_logs(client, owner, repo, job_id)
      IO.inspect(result, label: "GitHub LOGS API RESPONSE")

      # Now, use the stored result in the case statement
      case result do
      # --- MODIFICATION END ---
        {:ok, %{body: logs}} -> {:logs_fetched, job_id, logs}
        {:error, reason} -> {:logs_failed, job_id, reason}
      end
    end)
    {:noreply, socket}
  end
end
  # --- CORRECTED ---
  # Handles successful job fetch.
  def handle_info({_ref, {:jobs_fetched, run_id, jobs}}, socket) do
    socket =
      socket
      |> update(:jobs_cache, &Map.put(&1, run_id, jobs))
      |> update(:loading_jobs, &MapSet.delete(&1, run_id))
      |> update(:expanded_runs, &MapSet.put(&1, run_id)) # Auto-expand when loaded

    {:noreply, socket}
  end

  # --- CORRECTED ---
  # Handles successful log fetch.
  def handle_info({_ref, {:logs_fetched, job_id, logs}}, socket) do
    socket =
      socket
      |> update(:log_cache, &Map.put(&1, job_id, logs))
      |> update(:loading_logs, &MapSet.delete(&1, job_id))

    {:noreply, socket}
  end

  # --- CORRECTED ---
  # Generic handler for failed async fetches.
  def handle_info({_ref, {:jobs_failed, run_id, _reason}}, socket) do
    socket =
      socket
      |> put_flash(:error, "Failed to fetch jobs for run ##{run_id}")
      |> update(:loading_jobs, &MapSet.delete(&1, run_id))

    {:noreply, socket}
  end

  # --- CORRECTED ---
  def handle_info({_ref, {:logs_failed, job_id, _reason}}, socket) do
    socket =
      socket
      |> put_flash(:error, "Failed to fetch logs for job ##{job_id}")
      |> update(:loading_logs, &MapSet.delete(&1, job_id))

    {:noreply, socket}
  end
  # Catch-all to ignore any other messages the process receives
  def handle_info(_msg, socket), do: {:noreply, socket}
end
