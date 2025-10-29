defmodule DeployLens.Repo.Migrations.AddLogsToWorkflowJobs do
  use Ecto.Migration

  def change do
    alter table(:workflow_jobs) do
      add :logs, :text
    end
  end
end
