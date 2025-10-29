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
    data_source_mode = Application.get_env(:deploy_lens, :data_source_mode, :local_first)

    case data_source_mode do
      :api_only ->
        fetch_jobs_from_api(socket, run_id)

      :local_first ->
        case DeployLens.Workflows.get_workflow_jobs_by_run_id(run_id) do
          [] ->
            # No local data, fetch from API
            fetch_jobs_from_api(socket, run_id)

          local_jobs ->
            # Local data found
            socket =
              socket
              |> update(:jobs_cache, &Map.put(&1, run_id, local_jobs))
              |> update(:expanded_runs, fn expanded_runs ->
                if MapSet.member?(expanded_runs, run_id) do
                  MapSet.delete(expanded_runs, run_id)
                else
                  MapSet.put(expanded_runs, run_id)
                end
              end)

            {:noreply, socket}
        end
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
    data_source_mode = Application.get_env(:deploy_lens, :data_source_mode, :local_first)

    case data_source_mode do
      :api_only ->
        fetch_logs_from_api(socket, job_id)

      :local_first ->
        case DeployLens.Workflows.get_workflow_job_by_github_id(job_id) do
          %DeployLens.WorkflowJob{steps: steps} when steps != %{} ->
            # Local data found
            socket =
              socket
              |> update(:log_cache, &Map.put(&1, job_id, steps))
              |> update(:expanded_logs, &MapSet.put(&1, job_id))

            {:noreply, socket}

          _ ->
            # No local data or empty steps, fetch from API
            fetch_logs_from_api(socket, job_id)
        end
    end
  end

  defp fetch_jobs_from_api(socket, run_id) do
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

  defp fetch_logs_from_api(socket, job_id) do
    socket = update(socket, :loading_logs, &MapSet.put(&1, job_id))
    token = Application.get_env(:deploy_lens, :github_pat)
    client = GitHubClient.new(token)
    %{owner: owner, repo: repo} = socket.assigns

    Task.async(fn ->
      result = GitHubClient.get_job_logs(client, owner, repo, job_id)
      IO.inspect(result, label: "GitHub LOGS API RESPONSE")

      case result do
        {:ok, %{body: logs}} -> {:logs_fetched, job_id, logs}
        {:ok, logs} when is_binary(logs) -> {:logs_fetched, job_id, logs}
        {:error, :rate_limit_low} -> {:logs_failed, job_id, :rate_limit_low}
        {:error, reason} -> {:logs_failed, job_id, reason}
      end
    end)

    {:noreply, socket}
  end

  defp fetch_and_assign_workflow_runs(socket) do
    data_source_mode = Application.get_env(:deploy_lens, :data_source_mode, :local_first)
    per_page = Application.get_env(:deploy_lens, :workflow_runs_page_size, 10)
    %{owner: owner, repo: repo, page: page} = socket.assigns

    socket = assign(socket, loading: true)

    case data_source_mode do
      :api_only ->
        fetch_from_api(socket, owner, repo, page, per_page)

      :local_first ->
        case DeployLens.Workflows.get_workflow_runs_by_repo(owner, repo, page, per_page) do
          [] ->
            # No local data, fetch from API
            fetch_from_api(socket, owner, repo, page, per_page)

          local_runs ->
            # Local data found
            socket =
              socket
              |> assign(workflow_runs: local_runs, loading: false)
              |> fetch_and_assign_rate_limit()

            {:noreply, socket}
        end
    end
  end

  defp fetch_from_api(socket, owner, repo, page, per_page) do
    token = Application.get_env(:deploy_lens, :github_pat)
    client = GitHubClient.new(token)

    case GitHubClient.get_workflow_runs(client, owner, repo, page, per_page) do
      {:ok, %{body: %{"workflow_runs" => runs}}} ->
        socket =
          socket
          |> assign(workflow_runs: runs, loading: false)
          |> fetch_and_assign_rate_limit()

        {:noreply, socket}

      {:error, :rate_limit_low} ->
        {:noreply,
         put_flash(socket, :error, "GitHub API rate limit is low. Please try again later.")}

      {:ok, %{status: status, body: body}} ->
        error_msg = "GitHub API returned status #{status}: #{inspect(body)}"
        {:noreply, socket |> put_flash(:error, error_msg) |> assign(loading: false)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to fetch workflow runs from API")}
    end
  end

  # Handles successful job fetch.
  @impl true
  def handle_info({_ref, {:jobs_fetched, run_id, jobs}}, socket) do
    # Upsert jobs to local database
    Enum.each(jobs, fn job ->
      workflow_job_data =
        job
        |> Map.put("workflow_run_id", run_id)
        |> Map.put("steps", job["steps"] || %{})

      DeployLens.Workflows.create_or_update_workflow_job(workflow_job_data)
    end)

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
    if is_map(log) do
      # Format steps map from local database
      log
      |> Enum.map(fn {key, value} ->
        "#{key}: #{inspect(value)}"
      end)
      |> Enum.join("\n")
    else
      # Existing logic for string logs from GitHub API
      ~r/(\[(?<timestamp>.*?)\]) (\<(?<level>.*?)\>) (?<message>.*)/s
      |> Regex.named_captures(log)
      |> case do
        %{"timestamp" => ts, "level" => level, "message" => msg} ->
          [
            ~s(<span class="text-green-400">[),
            ~s(#{ts}),
            ~s(]</span> ),
            ~s(<span class="text-blue-400">&lt;),
            ~s(#{level}),
            ~s(&gt;</span> ),
            msg
          ]

        _ ->
          log
      end
    end
  end
end
