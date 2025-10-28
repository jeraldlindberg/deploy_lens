defmodule LogCacheTest do
  use ExUnit.Case
  alias DeployLens.LogCache
  
  setup do
    # Ensure clean state
    :ets.delete_all_objects(:log_cache)
    :ok
  end

  test "stores and retrieves logs" do
    job_id = "job123"
    logs = ["log1", "log2"]
    
    assert :ok = LogCache.put(job_id, logs)
    assert {:ok, ^logs} = LogCache.get(job_id)
  end

  test "returns error for non-existent job" do
    assert {:error, :not_found} = LogCache.get("nonexistent")
  end

  test "deletes logs" do
    job_id = "job456"
    logs = ["log1"]
    
    LogCache.put(job_id, logs)
    assert :ok = LogCache.delete(job_id)
    assert {:error, :not_found} = LogCache.get(job_id)
  end

  test "expires logs after TTL" do
    job_id = "job789"
    logs = ["log1"]
    
    # Set very short TTL
    LogCache.put(job_id, logs, 100)
    assert {:ok, ^logs} = LogCache.get(job_id)
    
    # Wait for expiration
    Process.sleep(150)
    
    # Trigger cleanup manually
    send(LogCache, :cleanup_expired)
    Process.sleep(50)
    
    assert {:error, :not_found} = LogCache.get(job_id)
  end

  test "survives process restart" do
    job_id = "job999"
    logs = ["log1"]
    
    LogCache.put(job_id, logs)
    
    # Kill the GenServer
    pid = Process.whereis(LogCache)
    Process.exit(pid, :kill)
    
    # Wait for supervisor to restart
    Process.sleep(100)
    
    # Data is lost (ETS is process-bound), but process is back
    assert is_pid(Process.whereis(LogCache))
  end
end