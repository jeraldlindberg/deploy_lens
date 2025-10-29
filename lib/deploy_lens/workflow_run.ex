defmodule DeployLens.WorkflowRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_runs" do
    field :github_id, :integer
    field :repository_id, :integer
    field :repository_full_name, :string
    field :head_branch, :string
    field :workflow_name, :string
    field :status, :string
    field :conclusion, :string
    field :url, :string
    field :html_url, :string
    field :run_attempt, :integer
    field :run_number, :integer

    timestamps()
  end

  @doc false
  def changeset(workflow_run, attrs) do
    workflow_run
    |> cast(attrs, [:github_id, :repository_id, :repository_full_name, :head_branch,
                    :workflow_name, :status, :conclusion, :url, :html_url,
                    :run_attempt, :run_number])
    |> validate_required([:github_id, :repository_id, :repository_full_name, :head_branch,
                          :workflow_name, :status, :url, :html_url,
                          :run_attempt, :run_number])
  end
end
