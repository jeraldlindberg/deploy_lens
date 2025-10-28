defmodule DeployLens.WorkflowJob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_jobs" do
    field :github_id, :integer
    field :workflow_run_id, :integer
    field :name, :string
    field :status, :string
    field :conclusion, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :url, :string
    field :html_url, :string
    field :runner_name, :string
    field :runner_group_name, :string
    field :steps, :map

    timestamps()
  end

  @doc false
  def changeset(workflow_job, attrs) do
    workflow_job
    |> cast(attrs, [:github_id, :workflow_run_id, :name, :status, :conclusion,
                    :started_at, :completed_at, :url, :html_url,
                    :runner_name, :runner_group_name, :steps])
    |> validate_required([:github_id, :workflow_run_id, :name, :status,
                          :started_at, :url, :html_url])
    |> unique_constraint(:github_id)
  end
end
