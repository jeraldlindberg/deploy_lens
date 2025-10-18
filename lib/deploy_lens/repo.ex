defmodule DeployLens.Repo do
  use Ecto.Repo,
    otp_app: :deploy_lens,
    adapter: Ecto.Adapters.Postgres
end
