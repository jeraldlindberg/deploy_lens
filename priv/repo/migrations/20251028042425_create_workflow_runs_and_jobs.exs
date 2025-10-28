defmodule DeployLens.Repo.Migrations.CreateWorkflowRunsAndJobs do
  use Ecto.Migration

  def change do
    create table(:workflow_runs) do
      add :github_id, :bigint, null: false
      add :repository_id, :bigint, null: false
      add :repository_full_name, :string, null: false
      add :head_branch, :string, null: false
      add :workflow_name, :string, null: false
      add :status, :string, null: false
      add :conclusion, :string
      add :url, :string, null: false
      add :html_url, :string, null: false
      add :run_attempt, :integer, null: false
      add :run_number, :integer, null: false

      timestamps()
    end

    create unique_index(:workflow_runs, [:github_id])

    create table(:workflow_jobs) do
      add :github_id, :bigint, null: false
      add :workflow_run_id, :bigint, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :conclusion, :string
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :url, :string, null: false
      add :html_url, :string, null: false
      add :runner_name, :string
      add :runner_group_name, :string
      add :steps, :jsonb

      timestamps()
    end

    create unique_index(:workflow_jobs, [:github_id])
    create index(:workflow_jobs, [:workflow_run_id])
  end
end
