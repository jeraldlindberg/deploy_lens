defmodule DeployLensWeb.PageController do
  use DeployLensWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
