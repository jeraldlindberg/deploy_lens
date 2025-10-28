defmodule DeployLens.RateLimitCache do
  use GenServer
  require Logger

  @table_name :rate_limit_cache

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get() do
    case :ets.lookup(@table_name, :rate_limit) do
      [{:rate_limit, data}] ->
        {:ok, data}
      [] ->
        {:error, :not_found}
    end
  end

  def put(data) do
    GenServer.call(__MODULE__, {:put, data})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:named_table, :public, read_concurrency: true])
    Logger.info("RateLimitCache started with ETS table: #{@table_name}")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, data}, _from, state) do
    :ets.insert(@table_name, {:rate_limit, data})
    {:reply, :ok, state}
  end
end
