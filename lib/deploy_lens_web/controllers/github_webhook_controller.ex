defmodule DeployLensWeb.GithubWebhookController do
  use DeployLensWeb, :controller

  plug :verify_signature

  def index(conn, %{"workflow_run" => _workflow_run}) do
    json(conn, %{status: "ok"})
  end

  defp verify_signature(conn, _opts) do
    secret = Application.fetch_env!(:deploy_lens, :github_webhook_secret)

    case get_req_header(conn, "x-hub-signature-256") do
      [signature] ->
        expected_signature = "sha256=" <> :crypto.mac(:hmac, :sha256, secret, conn.assigns.raw_body) |> Base.encode16(case: :lower)

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
