defmodule DeployLensWeb.DashboardLive do
  use DeployLensWeb, :live_view

  alias DeployLens.GitHubClient

  @impl true
  def mount(_params, _session, socket) do
    socket = 
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
        expanded_logs: MapSet.new(),
        loading_jobs: MapSet.new(),
        loading_logs: MapSet.new(),
        rate_limit: nil,
        page: 1
      )
    {:ok, fetch_and_assign_rate_limit(socket)}
  end

  defp fetch_and_assign_rate_limit(socket) do
    token = Application.get_env(:deploy_lens, :github_pat)
    client = GitHubClient.new(token)
    case GitHubClient.get_rate_limit(client) do
      {:ok, %{body: rate_limit}} ->
        assign(socket, :rate_limit, rate_limit)
      _ ->
        socket
    end
  end

  @impl true
  def handle_event("fetch_runs", %{"owner" => owner, "repo" => repo}, socket) do
    socket = assign(socket, owner: owner, repo: repo, page: 1)
    fetch_and_assign_workflow_runs(socket)
  end

  def handle_event("next_page", _, socket) do
    socket = update(socket, :page, &(&1 + 1))
    fetch_and_assign_workflow_runs(socket)
  end

  def handle_event("prev_page", _, socket) do
    socket = update(socket, :page, &(&1 - 1))
    fetch_and_assign_workflow_runs(socket)
  end

  def handle_event("toggle_jobs", %{"run-id" => run_id}, socket) do
    run_id = String.to_integer(run_id)

    if Map.has_key?(socket.assigns.jobs_cache, run_id) do
      # If cached, manually toggle the run_id in the expanded_runs set.
      socket =
        update(socket, :expanded_runs, fn expanded_runs ->
          if MapSet.member?(expanded_runs, run_id) do
            MapSet.delete(expanded_runs, run_id)
          else
            MapSet.put(expanded_runs, run_id)
          end
        end)

      {:noreply, socket}
    else
      # Fetch the jobs asynchronously if not in cache
      token = Application.get_env(:deploy_lens, :github_pat)
      client = GitHubClient.new(token)
      %{owner: owner, repo: repo} = socket.assigns

      Task.async(fn ->
        case GitHubClient.get_workflow_run_jobs(client, owner, repo, run_id) do
          {:ok, %{body: %{"jobs" => jobs}}} -> {:jobs_fetched, run_id, jobs}
          {:error, :rate_limit_low} -> {:jobs_failed, run_id, :rate_limit_low}
          {:error, reason} -> {:jobs_failed, run_id, reason}
        end
      end)

      {:noreply, socket}
    end
  end

  def handle_event("toggle_logs", %{"job-id" => job_id}, socket) do
    job_id = String.to_integer(job_id)

    socket =
      update(socket, :expanded_logs, fn expanded_logs ->
        if MapSet.member?(expanded_logs, job_id) do
          MapSet.delete(expanded_logs, job_id)
        else
          MapSet.put(expanded_logs, job_id)
        end
      end)

    {:noreply, socket}
  end

  def handle_event("fetch_logs", %{"job-id" => job_id}, socket) do
    job_id = String.to_integer(job_id)

    if Map.has_key?(socket.assigns.log_cache, job_id) do
      {:noreply, socket}
    else
      socket = update(socket, :loading_logs, &MapSet.put(&1, job_id))
      token = Application.get_env(:deploy_lens, :github_pat)
      client = GitHubClient.new(token)
      %{owner: owner, repo: repo} = socket.assigns

      Task.async(fn ->
        # --- MODIFICATION START ---
        # Call the API once, store the result, and print it to the console
        result = GitHubClient.get_job_logs(client, owner, repo, job_id)
        IO.inspect(result, label: "GitHub LOGS API RESPONSE")

        # Now, use the stored result in the case statement
        case result do
          {:ok, %{body: logs}} -> {:logs_fetched, job_id, logs}
          {:ok, logs} when is_binary(logs) -> {:logs_fetched, job_id, logs}
          {:error, :rate_limit_low} -> {:logs_failed, job_id, :rate_limit_low}
          {:error, reason} -> {:logs_failed, job_id, reason}
        end
      end)

      {:noreply, socket}
    end
  end

  defp fetch_and_assign_workflow_runs(socket) do
    token = Application.get_env(:deploy_lens, :github_pat)
    client = GitHubClient.new(token)
    per_page = Application.get_env(:deploy_lens, :workflow_runs_page_size, 10)
    %{owner: owner, repo: repo, page: page} = socket.assigns

    socket = assign(socket, loading: true)

    case GitHubClient.get_workflow_runs(client, owner, repo, page, per_page) do
      {:ok, %{body: %{"workflow_runs" => runs}}} ->
        socket = 
          socket
          |> assign(workflow_runs: runs, loading: false)
          |> fetch_and_assign_rate_limit()
        {:noreply, socket}

      {:error, :rate_limit_low} ->
        {:noreply, put_flash(socket, :error, "GitHub API rate limit is low. Please try again later.")}

      {:ok, %{status: status, body: body}} ->
        error_msg = "GitHub API returned status #{status}: #{inspect(body)}"
        {:noreply, socket |> put_flash(:error, error_msg) |> assign(loading: false)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to fetch workflow runs")}
    end
  end

  # --- CORRECTED ---
  # Handles successful job fetch.
  @impl true
  def handle_info({_ref, {:jobs_fetched, run_id, jobs}}, socket) do
    socket =
      socket
      |> update(:jobs_cache, &Map.put(&1, run_id, jobs))
      |> update(:loading_jobs, &MapSet.delete(&1, run_id))
      # Auto-expand when loaded
      |> update(:expanded_runs, &MapSet.put(&1, run_id))
      |> fetch_and_assign_rate_limit()

    {:noreply, socket}
  end

  # Handles successful log fetch.
  @impl true
  def handle_info({_ref, {:logs_fetched, job_id, logs}}, socket) do
    socket =
      socket
      |> update(:log_cache, &Map.put(&1, job_id, logs))
      |> update(:loading_logs, &MapSet.delete(&1, job_id))
      |> update(:expanded_logs, &MapSet.put(&1, job_id))
      |> fetch_and_assign_rate_limit()

    {:noreply, socket}
  end

  def handle_info({_ref, {:jobs_failed, run_id, :rate_limit_low}}, socket) do
    socket =
      socket
      |> put_flash(:error, "GitHub API rate limit is low. Please try again later.")
      |> update(:loading_jobs, &MapSet.delete(&1, run_id))

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

  def handle_info({_ref, {:logs_failed, job_id, :rate_limit_low}}, socket) do
    socket =
      socket
      |> put_flash(:error, "GitHub API rate limit is low. Please try again later.")
      |> update(:loading_logs, &MapSet.delete(&1, job_id))

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

  defp format_reset_time(reset_timestamp) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    remaining_seconds = reset_timestamp - now

    if remaining_seconds <= 0 do
      "now"
    else
      remaining_minutes = div(remaining_seconds, 60)
      "in #{remaining_minutes} minutes"
    end
  end

  defp format_log(log) do
    ~r/(\[(?<timestamp>.*?)\]) (\<(?<level>.*?)\>) (?<message>.*)/s
    |> Regex.named_captures(log)
    |> case do
      %{"timestamp" => ts, "level" => level, "message" => msg} ->
        [~s(<span class="text-green-400">[), ~s(#{ts}), ~s(]</span> ),
         ~s(<span class="text-blue-400">&lt;), ~s(#{level}), ~s(&gt;</span> ),
         msg]
      _ ->
        log
    end
  end
end
