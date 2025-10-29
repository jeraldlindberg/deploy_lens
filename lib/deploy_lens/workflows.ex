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
    # 1. Map the raw attributes from the GitHub payload (string keys)
    #    to your Ecto schema's atom keys.
    mapped_attrs = %{
      :github_id => attrs["id"],
      :repository_id => get_in(attrs, ["repository", "id"]),
      :repository_full_name => get_in(attrs, ["repository", "full_name"]),
      :head_branch => attrs["head_branch"],
      :workflow_name => attrs["name"],
      :status => attrs["status"],
      :conclusion => attrs["conclusion"],
      :url => attrs["url"],
      :html_url => attrs["html_url"],
      :run_attempt => attrs["run_attempt"],
      :run_number => attrs["run_number"],
      :inserted_at => parse_timestamp(attrs["created_at"]),
      :updated_at => parse_timestamp(attrs["updated_at"])
    }

    # 2. Find the existing run by its unique github_id
    # Build a new struct if not found
    existing_run =
      case mapped_attrs.github_id do
        nil -> nil
        github_id -> Repo.get_by(WorkflowRun, github_id: github_id)
      end || %WorkflowRun{}

    # 3. Create a changeset and upsert the data
    existing_run
    |> WorkflowRun.changeset(mapped_attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Creates or updates a workflow_job.
  """
  def create_or_update_workflow_job(attrs) do
    # 1. Map string keys to atom keys
    mapped_attrs = %{
      :github_id => attrs["id"],
      # Handle both keys
      :workflow_run_id => attrs["run_id"] || attrs["workflow_run_id"],
      :name => attrs["name"],
      :status => attrs["status"],
      :conclusion => attrs["conclusion"],
      :started_at => parse_timestamp(attrs["started_at"]),
      :completed_at => parse_timestamp(attrs["completed_at"]),
      :url => attrs["url"],
      :html_url => attrs["html_url"],
      :runner_name => attrs["runner_name"],
      :runner_group_name => attrs["runner_group_name"],
      # Store steps as a map, even if it comes in as an empty list
      :steps =>
        (attrs["steps"] || %{})
        |> case do
          [] -> %{}
          # Or handle better
          list when is_list(list) -> %{"steps" => list}
          map -> map
        end
    }

    # 2. Find existing job by its unique github_id
    # Build a new struct if not found
    existing_job =
      case mapped_attrs.github_id do
        nil -> nil
        github_id -> Repo.get_by(WorkflowJob, github_id: github_id)
      end || %WorkflowJob{}

    # 3. Create a changeset and upsert
    existing_job
    |> WorkflowJob.changeset(mapped_attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Returns a paginated list of workflow runs for a given repository.
  """
  def get_workflow_runs_by_repo(owner, repo, page, per_page) do
    offset = (page - 1) * per_page

    WorkflowRun
    |> where(
      [wr],
      wr.repository_full_name == ^"#{owner}/#{repo}"
    )
    |> order_by([wr], desc: wr.github_id)
    |> limit(^per_page)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Returns the list of workflow jobs for a given workflow run's GitHub ID.
  """
  def get_workflow_jobs_by_run_id(workflow_run_github_id) do
    WorkflowJob
    |> where([wj], wj.workflow_run_id == ^workflow_run_github_id)
    |> order_by([wj], desc: wj.github_id)
    |> Repo.all()
  end

  @doc """
  Gets a single workflow_job by its GitHub ID.
  """
  def get_workflow_job_by_github_id(github_id) do
    Repo.get_by(WorkflowJob, github_id: github_id)
  end

  # --- Helpers ---

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp_str) when is_binary(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  # Handle cases where it might already be a DateTime
  defp parse_timestamp(datetime), do: datetime
end
