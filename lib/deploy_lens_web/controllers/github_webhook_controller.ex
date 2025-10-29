defmodule DeployLensWeb.GithubWebhookController do
  use DeployLensWeb, :controller

  alias DeployLens.Workflows

  plug :verify_signature

  def index(conn, _params) do
    event_type = get_req_header(conn, "x-github-event") |> List.first()
    payload = Jason.decode!(conn.assigns.raw_body)

    case event_type do
      "workflow_run" -> handle_workflow_run_event(conn, payload)
      "workflow_job" -> handle_workflow_job_event(conn, payload)
      # Ignore other events
      _ -> json(conn, %{status: "ok"})
    end
  end

  defp handle_workflow_run_event(conn, %{"workflow_run" => run_attrs, "repository" => repo_attrs}) do
    full_attrs = Map.put(run_attrs, "repository", repo_attrs)

    case Workflows.create_or_update_workflow_run(full_attrs) do
      {:ok, _workflow_run} ->
        json(conn, %{status: "ok"})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, &elem(&1, 0))

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end

  # Handle cases where the payload is missing expected keys
  defp handle_workflow_run_event(conn, _payload) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Malformed workflow_run payload"})
  end

  defp handle_workflow_job_event(conn, %{"workflow_job" => job_attrs}) do
    case Workflows.create_or_update_workflow_job(job_attrs) do
      {:ok, _workflow_job} ->
        json(conn, %{status: "ok"})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, &elem(&1, 0))

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end

  # Handle cases where the payload is missing expected keys
  defp handle_workflow_job_event(conn, _payload) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Malformed workflow_job payload"})
  end

  defp verify_signature(conn, _opts) do
    secret = Application.fetch_env!(:deploy_lens, :github_webhook_secret)

    case get_req_header(conn, "x-hub-signature-256") do
      [signature] ->
        # This correctly uses conn.assigns.raw_body, which is assumed
        # to be populated before Plug.Parsers (e.g., in the Endpoint)
        expected_signature =
          "sha256=" <>
            (:crypto.mac(:hmac, :sha256, secret, conn.assigns.raw_body)
             |> Base.encode16(case: :lower))

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
