defmodule DeployLens.WorkflowsTest do
  use DeployLens.DataCase

  alias DeployLens.Workflows
  alias DeployLens.WorkflowRun
  alias DeployLens.WorkflowJob



  @moduletag :clear_db_on_exit

  describe "workflow_runs" do
    test "list_workflow_runs/0 returns all workflow_runs" do
      workflow_run = workflow_run_fixture()
      assert Workflows.list_workflow_runs() == [workflow_run]
    end

    test "get_workflow_run!/1 returns the workflow_run with given id" do
      workflow_run = workflow_run_fixture()
      assert Workflows.get_workflow_run!(workflow_run.id) == workflow_run
    end

    test "create_workflow_run/1 with valid data creates a workflow_run" do
      valid_attrs = %{
        github_id: 1,
        repository_id: 1,
        repository_full_name: "repo/name",
        head_branch: "main",
        workflow_name: "CI",
        status: "completed",
        conclusion: "success",
        url: "http://example.com/run/1",
        html_url: "http://example.com/run/1/html",
        run_attempt: 1,
        run_number: 1
      }

      assert {:ok, %WorkflowRun{} = workflow_run} = Workflows.create_workflow_run(valid_attrs)
      assert workflow_run.github_id == 1
      assert workflow_run.repository_full_name == "repo/name"
    end

    test "create_workflow_run/1 with invalid data returns error changeset" do
      invalid_attrs = %{github_id: nil}
      assert {:error, %Ecto.Changeset{}} = Workflows.create_workflow_run(invalid_attrs)
    end

    test "update_workflow_run/2 with valid data updates the workflow_run" do
      workflow_run = workflow_run_fixture()
      update_attrs = %{status: "in_progress"}

      assert {:ok, %WorkflowRun{} = workflow_run} = Workflows.update_workflow_run(workflow_run, update_attrs)
      assert workflow_run.status == "in_progress"
    end

    test "update_workflow_run/2 with invalid data returns error changeset" do
      workflow_run = workflow_run_fixture()
      invalid_attrs = %{status: nil}

      assert {:error, %Ecto.Changeset{}} = Workflows.update_workflow_run(workflow_run, invalid_attrs)
      assert workflow_run.status == "completed"
    end

    test "delete_workflow_run/1 deletes the workflow_run" do
      workflow_run = workflow_run_fixture()
      assert {:ok, %WorkflowRun{}} = Workflows.delete_workflow_run(workflow_run)
      assert_raise Ecto.NoResultsError, fn -> Workflows.get_workflow_run!(workflow_run.id) end
    end

    defp workflow_run_fixture(attrs \\ %{}) do
      {:ok, workflow_run} = Workflows.create_workflow_run(
        %{ 
          github_id: 100 + System.unique_integer([:positive]),
          repository_id: 1,
          repository_full_name: "repo/name",
          head_branch: "main",
          workflow_name: "CI",
          status: "completed",
          conclusion: "success",
          url: "http://example.com/run/1",
          html_url: "http://example.com/run/1/html",
          run_attempt: 1,
          run_number: 1
        }
        |> Map.merge(attrs)
      )
      workflow_run
    end
  end

describe "workflow_jobs" do
    test "list_workflow_jobs/0 returns all workflow_jobs" do
      workflow_job = workflow_job_fixture()
      assert Workflows.list_workflow_jobs() == [workflow_job]
    end

    test "get_workflow_job!/1 returns the workflow_job with given id" do
      workflow_job = workflow_job_fixture()
      assert Workflows.get_workflow_job!(workflow_job.id) == workflow_job
    end

    test "create_workflow_job/1 with valid data creates a workflow_job" do
      valid_attrs = %{
        github_id: 1,
        workflow_run_id: 1,
        name: "build",
        status: "completed",
        conclusion: "success",
        started_at: ~U[2025-01-01 00:00:00Z],
        completed_at: ~U[2025-01-01 00:01:00Z],
        url: "http://example.com/job/1",
        html_url: "http://example.com/job/1/html",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        steps: %{"step1" => "log1"}
      }

      assert {:ok, %WorkflowJob{} = workflow_job} = Workflows.create_workflow_job(valid_attrs)
      assert workflow_job.github_id == 1
      assert workflow_job.name == "build"
    end

    test "create_workflow_job/1 with invalid data returns error changeset" do
      invalid_attrs = %{github_id: nil}
      assert {:error, %Ecto.Changeset{}} = Workflows.create_workflow_job(invalid_attrs)
    end

    test "update_workflow_job/2 with valid data updates the workflow_job" do
      workflow_job = workflow_job_fixture()
      update_attrs = %{status: "in_progress"}

      assert {:ok, %WorkflowJob{} = workflow_job} = Workflows.update_workflow_job(workflow_job, update_attrs)
      assert workflow_job.status == "in_progress"
    end

    test "update_workflow_job/2 with invalid data returns error changeset" do
      workflow_job = workflow_job_fixture()
      invalid_attrs = %{status: nil}

      assert {:error, %Ecto.Changeset{}} = Workflows.update_workflow_job(workflow_job, invalid_attrs)
      assert workflow_job.status == "completed"
    end

    test "delete_workflow_job/1 deletes the workflow_job" do
      workflow_job = workflow_job_fixture()
      assert {:ok, %WorkflowJob{}} = Workflows.delete_workflow_job(workflow_job)
      assert_raise Ecto.NoResultsError, fn -> Workflows.get_workflow_job!(workflow_job.id) end
    end

    defp workflow_job_fixture(attrs \\ %{}) do
      {:ok, workflow_job} = Workflows.create_workflow_job(
        %{ 
          github_id: 200 + System.unique_integer([:positive]),
          workflow_run_id: 1,
          name: "build",
          status: "completed",
          conclusion: "success",
          started_at: ~U[2025-01-01 00:00:00Z],
          completed_at: ~U[2025-01-01 00:01:00Z],
          url: "http://example.com/job/1",
          html_url: "http://example.com/job/1/html",
          runner_name: "GitHub Actions 1",
          runner_group_name: "GitHub Actions",
          steps: %{"step1" => "log1"}
        }
        |> Map.merge(attrs)
      )
      workflow_job
    end
  end
end
