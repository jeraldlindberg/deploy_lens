defmodule DeployLensWeb.GithubWebhookControllerTest do
  use DeployLensWeb.ConnCase, async: true

  alias DeployLens.Repo
  alias DeployLens.WorkflowRun
  alias DeployLens.WorkflowJob

  @secret "my-super-secret-webhook-secret"

  setup do
    Application.put_env(:deploy_lens, :github_webhook_secret, @secret)
    :ok
  end

  describe "POST /api/github/webhook" do
    test "returns 200 for a valid workflow_run event and upserts the run", %{conn: conn} do
      payload = ~s({
        "action": "completed",
        "workflow_run": {
          "id": 123,
          "name": "CI",
          "head_branch": "main",
          "status": "completed",
          "conclusion": "success",
          "url": "http://example.com/run/123",
          "html_url": "http://example.com/run/123/html",
          "run_attempt": 1,
          "run_number": 1
        },
        "repository": {
          "id": 456,
          "full_name": "owner/repo"
        }
      })
      signature = sign_payload(payload)

      conn = conn
             |> put_req_header("x-hub-signature-256", signature)
             |> put_req_header("content-type", "application/json")
             |> put_req_header("x-github-event", "workflow_run")
      conn = post(conn, "/api/github/webhook", payload)

      assert conn.status == 200
      assert conn.resp_body == "{\"status\":\"ok\"}"

      workflow_run = Repo.get_by!(WorkflowRun, github_id: 123)
      assert workflow_run.repository_id == 456
      assert workflow_run.status == "completed"
    end

    test "returns 200 for a valid workflow_job event and upserts the job", %{conn: conn} do
      # Create a workflow_run first, so the job has something to associate with.
      run_attrs = %{
        "id" => 123,
        "name" => "CI",
        "head_branch" => "main",
        "status" => "in_progress",
        "conclusion" => nil,
        "url" => "http://example.com/run/123",
        "html_url" => "http://example.com/run/123/html",
        "run_attempt" => 1,
        "run_number" => 1,
        "repository" => %{
          "id" => 456,
          "full_name" => "owner/repo"
        },
        "created_at" => "2025-01-01T00:00:00Z",
        "updated_at" => "2025-01-01T00:00:00Z"
      }
      {:ok, _} = DeployLens.Workflows.create_or_update_workflow_run(run_attrs)

      payload = ~s({
        "action": "completed",
        "workflow_job": {
          "id": 789,
          "run_id": 123,
          "name": "build",
          "status": "completed",
          "conclusion": "success",
          "started_at": "2025-01-01T00:00:00Z",
          "completed_at": "2025-01-01T00:01:00Z",
          "url": "http://example.com/job/789",
          "html_url": "http://example.com/job/789/html",
          "runner_name": "GitHub Actions 1",
          "runner_group_name": "GitHub Actions",
          "steps": []
        },
        "workflow_run": {
          "id": 123
        }
      })
      signature = sign_payload(payload)

      conn = conn
             |> put_req_header("x-hub-signature-256", signature)
             |> put_req_header("content-type", "application/json")
             |> put_req_header("x-github-event", "workflow_job")
      conn = post(conn, "/api/github/webhook", payload)

      assert conn.status == 200
      assert conn.resp_body == "{\"status\":\"ok\"}"

      workflow_job = Repo.get_by!(WorkflowJob, github_id: 789)
      assert workflow_job.workflow_run_id == 123
      assert workflow_job.status == "completed"
    end

    test "returns 401 for an invalid signature", %{conn: conn} do
      payload = ~s({"workflow_run": {}})
      conn = conn
             |> put_req_header("x-hub-signature-256", "sha256=invalid")
             |> put_req_header("content-type", "application/json")
             |> put_req_header("x-github-event", "workflow_run")
      conn = post(conn, "/api/github/webhook", payload)
      assert conn.status == 401
      assert conn.resp_body == "Invalid signature"
    end

    test "returns 400 for a missing signature", %{conn: conn} do
      payload = ~s({"workflow_run": {}})
      conn = conn
             |> put_req_header("content-type", "application/json")
             |> put_req_header("x-github-event", "workflow_run")
      conn = post(conn, "/api/github/webhook", payload)
      assert conn.status == 400
      assert conn.resp_body == "Missing signature"
    end

    test "returns 200 for a different event", %{conn: conn} do
      payload = ~s({"other_event": {}})
      signature = sign_payload(payload)

      conn = conn
             |> put_req_header("x-hub-signature-256", signature)
             |> put_req_header("content-type", "application/json")
             |> put_req_header("x-github-event", "push") # A different event type

      conn = post(conn, "/api/github/webhook", payload)
      assert conn.status == 200
      assert conn.resp_body == "{\"status\":\"ok\"}"
    end

    defp sign_payload(payload) do
      "sha256=" <> (:crypto.mac(:hmac, :sha256, @secret, payload) |> Base.encode16(case: :lower))
    end
  end
end
