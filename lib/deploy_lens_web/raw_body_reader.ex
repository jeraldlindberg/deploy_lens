defmodule DeployLensWeb.RawBodyReader do
  def read_body(conn, opts) do
    if conn.request_path == "/api/github/webhook" do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = Plug.Conn.assign(conn, :raw_body, body)
      {:ok, body, conn}
    else
      Plug.Conn.read_body(conn, opts)
    end
  end
end
