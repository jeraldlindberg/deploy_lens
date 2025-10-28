defmodule DeployLensWeb.GithubWebhookControllerTest do
  use DeployLensWeb.ConnCase, async: true

  @secret "my-super-secret-webhook-secret"

  setup do
    Application.put_env(:deploy_lens, :github_webhook_secret, @secret)
    :ok
  end

  describe "POST /api/github/webhook" do
    test "returns 200 for a valid workflow_run event", %{conn: conn} do
      payload = ~s({"workflow_run": {}})
      signature = sign_payload(payload)

      conn = conn
             |> put_req_header("x-hub-signature-256", signature)
             |> put_req_header("content-type", "application/json")
      conn = post(conn, "/api/github/webhook", payload)

      assert conn.status == 200
      assert conn.resp_body == "{\"status\":\"ok\"}"
    end

    test "returns 200 for a valid workflow_job event", %{conn: conn} do
      payload = ~s({"workflow_job": {}})
      signature = sign_payload(payload)

      conn = conn
             |> put_req_header("x-hub-signature-256", signature)
             |> put_req_header("content-type", "application/json")
      conn = post(conn, "/api/github/webhook", payload)

      assert conn.status == 200
      assert conn.resp_body == "{\"status\":\"ok\"}"
    end

    test "returns 401 for an invalid signature", %{conn: conn} do
      payload = ~s({"workflow_run": {}})
      conn = conn
             |> put_req_header("x-hub-signature-256", "sha256=invalid")
             |> put_req_header("content-type", "application/json")
      conn = post(conn, "/api/github/webhook", payload)
      assert conn.status == 401
      assert conn.resp_body == "Invalid signature"
    end

    test "returns 400 for a missing signature", %{conn: conn} do
      payload = ~s({"workflow_run": {}})
      conn = conn |> put_req_header("content-type", "application/json")
      conn = post(conn, "/api/github/webhook", payload)
      assert conn.status == 400
      assert conn.resp_body == "Missing signature"
    end

    test "raises for a different event", %{conn: conn} do
      payload = ~s({"other_event": {}})
      signature = sign_payload(payload)

      conn = conn
             |> put_req_header("x-hub-signature-256", signature)
             |> put_req_header("content-type", "application/json")

      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, "/api/github/webhook", payload)
      end
    end

    defp sign_payload(payload) do
      "sha256=" <> (:crypto.mac(:hmac, :sha256, @secret, payload) |> Base.encode16(case: :lower))
    end
  end
end
