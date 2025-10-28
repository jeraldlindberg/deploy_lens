defmodule DeployLensWeb.GithubWebhookController do
  use DeployLensWeb, :controller

  alias DeployLens.Workflows

  plug :verify_signature

  def index(conn, _params) do
    event_type = get_req_header(conn, "x-github-event") |> hd()
    payload = Jason.decode!(conn.assigns.raw_body)

    case event_type do
      "workflow_run" -> handle_workflow_run_event(conn, payload)
      "workflow_job" -> handle_workflow_job_event(conn, payload)
      _ -> json(conn, %{status: "ok"}) # Ignore other events for now
    end
  end

  defp handle_workflow_run_event(conn, %{"workflow_run" => run, "repository" => repo}) do
    workflow_run_data = %{
      github_id: run["id"],
      repository_id: repo["id"],
      repository_full_name: repo["full_name"],
      head_branch: run["head_branch"],
      workflow_name: run["name"],
      status: run["status"],
      conclusion: run["conclusion"],
      url: run["url"],
      html_url: run["html_url"],
      run_attempt: run["run_attempt"],
      run_number: run["run_number"]
    }

    case Workflows.create_or_update_workflow_run(workflow_run_data) do
      {:ok, _workflow_run} ->
        json(conn, %{status: "ok"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset.errors})
    end
  end

  defp handle_workflow_job_event(conn, %{"workflow_job" => job, "workflow_run" => run}) do
    steps_data = case job["steps"] do
      list when is_list(list) -> Enum.with_index(list) |> Map.new(fn {item, index} -> {"step_#{index}", item} end)
      map when is_map(map) -> map
      _ -> %{}
    end

    workflow_job_data = %{
      github_id: job["id"],
      workflow_run_id: run["id"],
      name: job["name"],
      status: job["status"],
      conclusion: job["conclusion"],
      started_at: job["started_at"],
      completed_at: job["completed_at"],
      url: job["url"],
      html_url: job["html_url"],
      runner_name: job["runner_name"],
      runner_group_name: job["runner_group_name"],
      steps: steps_data
    }

    case Workflows.create_or_update_workflow_job(workflow_job_data) do
      {:ok, _workflow_job} ->
        json(conn, %{status: "ok"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset.errors})
    end
  end

  defp verify_signature(conn, _opts) do
    secret = Application.fetch_env!(:deploy_lens, :github_webhook_secret)

    case get_req_header(conn, "x-hub-signature-256") do
      [signature] ->
        expected_signature = "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, conn.assigns.raw_body) |> Base.encode16(case: :lower))

        if Plug.Crypto.secure_compare(signature, expected_signature) do
          conn
        else
          conn
          |> put_status(401)
          |> text("Invalid signature")
          |> halt()
        end
      _ ->
        conn
        |> put_status(400)
        |> text("Missing signature")
        |> halt()
    end
  end
end
