defmodule DeployLens.Workflows do
  import Ecto.Query, warn: false
  alias DeployLens.Repo

  alias DeployLens.WorkflowRun
  alias DeployLens.WorkflowJob

  @doc """
  Returns the list of workflow_runs.

  ## Examples

      iex> list_workflow_runs()
      [%WorkflowRun{}, ...]

  """
  def list_workflow_runs do
    Repo.all(WorkflowRun)
  end

  @doc """
  Gets a single workflow_run.

  Raises `Ecto.NoResultsError` if the Workflow run does not exist.

  ## Examples

      iex> get_workflow_run!(123)
      %WorkflowRun{}

      iex> get_workflow_run!(456)
      ** (Ecto.NoResultsError)

  """
  def get_workflow_run!(id), do: Repo.get!(WorkflowRun, id)

  @doc """
  Creates a workflow_run.

  ## Examples

      iex> create_workflow_run(%{field: value})
      {:ok, %WorkflowRun{}}

      iex> create_workflow_run(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_workflow_run(attrs \\ %{}) do
    %WorkflowRun{}
    |> WorkflowRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a workflow_run.

  ## Examples

      iex> update_workflow_run(workflow_run, %{field: new_value})
      {:ok, %WorkflowRun{}}

      iex> update_workflow_run(workflow_run, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_workflow_run(%WorkflowRun{} = workflow_run, attrs) do
    workflow_run
    |> WorkflowRun.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a workflow_run.

  ## Examples

      iex> delete_workflow_run(workflow_run)
      {:ok, %WorkflowRun{}}

      iex> delete_workflow_run(workflow_run)
      {:error, %Ecto.Changeset{}}

  """
  def delete_workflow_run(%WorkflowRun{} = workflow_run) do
    Repo.delete(workflow_run)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workflow_run changes.

  ## Examples

      iex> change_workflow_run(workflow_run)
      %Ecto.Changeset{source: %WorkflowRun{}}

  """
  def change_workflow_run(%WorkflowRun{} = workflow_run, attrs \\ %{}) do
    WorkflowRun.changeset(workflow_run, attrs)
  end

  @doc """
  Returns the list of workflow_jobs.

  ## Examples

      iex> list_workflow_jobs()
      [%WorkflowJob{}, ...]

  """
  def list_workflow_jobs do
    Repo.all(WorkflowJob)
  end

  @doc """
  Gets a single workflow_job.

  Raises `Ecto.NoResultsError` if the Workflow job does not exist.

  ## Examples

      iex> get_workflow_job!(123)
      %WorkflowJob{}

      iex> get_workflow_job!(456)
      ** (Ecto.NoResultsError)

  """
  def get_workflow_job!(id), do: Repo.get!(WorkflowJob, id)

  @doc """
  Creates a workflow_job.

  ## Examples

      iex> create_workflow_job(%{field: value})
      {:ok, %WorkflowJob{}}

      iex> create_workflow_job(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_workflow_job(attrs \\ %{}) do
    %WorkflowJob{}
    |> WorkflowJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a workflow_job.

  ## Examples

      iex> update_workflow_job(workflow_job, %{field: new_value})
      {:ok, %WorkflowJob{}}

      iex> update_workflow_job(workflow_job, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_workflow_job(%WorkflowJob{} = workflow_job, attrs) do
    workflow_job
    |> WorkflowJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a workflow_job.

  ## Examples

      iex> delete_workflow_job(workflow_job)
      {:ok, %WorkflowJob{}}

      iex> delete_workflow_job(workflow_job)
      {:error, %Ecto.Changeset{}}

  """
  def delete_workflow_job(%WorkflowJob{} = workflow_job) do
    Repo.delete(workflow_job)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workflow_job changes.

  ## Examples

      iex> change_workflow_job(workflow_job)
      %Ecto.Changeset{source: %WorkflowJob{}}

  """
  def change_workflow_job(%WorkflowJob{} = workflow_job, attrs \\ %{}) do
    WorkflowJob.changeset(workflow_job, attrs)
  end

  @doc """
  Creates or updates a workflow_run.
  """
  def create_or_update_workflow_run(attrs) do
    %WorkflowRun{}
    |> WorkflowRun.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: :github_id)
  end

  @doc """
  Creates or updates a workflow_job.
  """
  def create_or_update_workflow_job(attrs) do
    %WorkflowJob{}
    |> WorkflowJob.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: :github_id)
  end
end
