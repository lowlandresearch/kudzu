defmodule Fping.Server do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  # ------------------------------------------------------------
  # Client API
  # ------------------------------------------------------------
  def fetch(name) do
    GenServer.call(__MODULE__, {:fetch, name})
  end

  def status(name) do
    GenServer.call(__MODULE__, {:status, name})
  end
  def status() do
    GenServer.call(__MODULE__, :status)
  end

  def start(name, args) do
    GenServer.cast(__MODULE__, {:start, name, args}) 
  end

  def halt(name) do
    GenServer.call(__MODULE__, {:halt, name})
  end

  def flush() do
    GenServer.call(__MODULE__, :flush)
  end

  # ------------------------------------------------------------
  # Server API
  # ------------------------------------------------------------

  @impl true
  def init(:ok) do
    processes = %{}
    monitors = %{}
    {:ok, {processes, monitors}}
  end

  @impl true
  def handle_call(:flush, _from, {processes, _} = state) do
    # IO.inspect(processes)
    finished = processes
    |> Enum.filter(
      fn({_, pid}) ->
        case Fping.Process.status(pid) do
          {:success, _} -> true
          {:failure, _} -> true
          _ -> false
        end
      end
    )
    |> Enum.map(fn({_, pid}) -> Fping.Process.halt(pid) end)
    
    {:reply, {:ok, finished}, state}
  end

  @impl true
  def handle_call({:fetch, name}, _from, {processes, _} = state) do
    # IO.inspect(processes)
    {:reply, Map.fetch(processes, name), state}
  end

  @impl true
  def handle_call({:status, name}, _from, {processes, _} = state) do
    # IO.inspect(processes)
    case Map.fetch(processes, name) do
      {:ok, pid} -> {:reply, Fping.Process.status(pid), state}
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call(:status, _from, {processes, _} = state) do
    status = processes
    |> Enum.map(
      fn({name, pid}) ->
        case Fping.Process.status(pid) do
          {:running, nil} -> {name, "Starting..."}
          {:running, _} -> {name, "Running..."}
          {:success, ips} -> {name, "Done. #{Enum.count(ips)} IPs found."}
          {:failure, _} -> {name, "FAILED."}
        end
      end
    )
    |> Enum.into(%{})
    {:reply, status, state}
  end

  @impl true
  def handle_call({:halt, name}, _from, {processes, _} = state) do
    pid = Map.get(processes, name)
    case Fping.Process.halt(pid) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_cast({:start, name, args}, {processes, monitors}) do
    if Map.has_key?(processes, name) do
      {:noreply, {processes, monitors}}
    else
      # IO.inspect(args)
      {:ok, pid} = DynamicSupervisor.start_child(
        Fping.ProcessSupervisor, {Fping.Process, args}
      )
      ref = Process.monitor(pid)
      monitors = Map.put(monitors, ref, name)
      processes = Map.put(processes, name, pid)
      {:noreply, {processes, monitors}}
    end
  end

  @impl true
  def handle_info(
    {:DOWN, ref, :process, _pid, _reason}, {processes, monitors}
  ) do
    {name, monitors} = Map.pop(monitors, ref)
    Logger.info("Process down: #{name}")

    {_pid, processes} = Map.pop(processes, name)
    # if Process.alive?(pid) do
    #   case Fping.Process.status(pid) do
    #     {:running, _} -> GenServer.stop(pid)
    #     _ -> 1
    #   end
    
    {:noreply, {processes, monitors}}
  end  

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

end
