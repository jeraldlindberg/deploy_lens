defmodule DeployLens.Repo.Migrations.AddRunAttemptToWorkflowJobs do
  use Ecto.Migration

  def change do
    alter table(:workflow_jobs) do
      add :run_attempt, :integer, null: false, default: 1
    end
  end
end
