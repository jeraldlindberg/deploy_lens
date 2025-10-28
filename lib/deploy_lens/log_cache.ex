defmodule DeployLens.LogCache do
  use GenServer
  require Logger

  @table_name :log_cache
  @ttl_ms 3_600_000 # 1 hour default TTL

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieve logs for a given job_id.
  Returns {:ok, logs} if found, {:error, :not_found} otherwise.
  """
  def get(job_id) do
    case :ets.lookup( @table_name, job_id) do
      [{^job_id, logs, _expires_at}] ->
        {:ok, logs}
      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Store logs for a given job_id with optional TTL.
  """
  def put(job_id, logs, ttl_ms \\ @ttl_ms) do
    GenServer.call(__MODULE__, {:put, job_id, logs, ttl_ms})
  end

  @doc """
  Delete logs for a given job_id.
  """
  def delete(job_id) do
    GenServer.call(__MODULE__, {:delete, job_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new( @table_name, [:named_table, :set, :public, read_concurrency: true])
    schedule_cleanup()
    Logger.info("LogCache started with ETS table: #{ @table_name}")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:put, job_id, logs, ttl_ms}, _from, state) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert( @table_name, {job_id, logs, expires_at})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, job_id}, _from, state) do
    :ets.delete( @table_name, job_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    now = System.monotonic_time(:millisecond)
    expired_count = 
      @table_name
      |> :ets.select([{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
      |> length()

    :ets.select_delete( @table_name, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    
    if expired_count > 0 do
      Logger.debug("Cleaned up #{expired_count} expired entries from LogCache")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, 60_000) # Run every minute
  end
end
