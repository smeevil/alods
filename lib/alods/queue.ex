defmodule Alods.Queue do
  @moduledoc """
    This module takes care of starting a DETS store.
  """

  use GenServer
  import Ex2ms

  @valid_methods [:get, :post]
  @valid_statuses [:pending, :processing]

  @spec start_link :: {:ok, pid}
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    env = Application.get_env(:alods, :env)
    if env == nil do
      raise("Please make sure you define alods env in your config/dev.exs with `config :alods, env: :dev` for example")
    end

    Process.flag(:trap_exit, true)
    path = File.cwd! <> "/priv"
    file = "/alods_store_#{env}.ets"
    unless File.exists?(path), do: File.mkdir_p!(path)
    auto_save = Application.get_env(:alods, :store_auto_save_ms, :timer.seconds(60))

    {:ok, _reference} = :dets.open_file(__MODULE__, file: to_charlist(path <> file), auto_save: auto_save)
    {:ok, nil}
  end

  #TODO seems not to trigger for mix test, in IEX when running :init.stop it works fine...
  def terminate(_reason, _status) do
    IO.puts "Closing DETS"
    :ok = :dets.close(__MODULE__)
    :normal
  end

  @doc """
  Get the current amount of record entries in the store
  """
  @spec length :: number
  def length, do: :dets.info(__MODULE__)[:size]

  @doc """
  Alias for lenth/1
  """
  @spec size :: number
  def size, do: length()

  @doc """
  Clears the store, WARNING this removes all records!
  """
  @spec clear! :: :ok
  def clear!, do: GenServer.call(__MODULE__, {:clear})

  @doc """
  Returns all entries of which their timestamp are smaller then the current time
  """
  @spec get_pending_entries :: {:ok, [{String.t, atom, String.t, map, number, atom}]}
  def get_pending_entries, do: GenServer.call(__MODULE__, {:get_pending_entries})

  @doc """
  Will return all records in the store
  """
  @spec list :: list
  def list, do: GenServer.call(__MODULE__, {:list})

  @spec find(String.t) :: %Alods.Queue.Record{}
  def find(id), do: GenServer.call(__MODULE__, {:find, id})

  @spec delete(String.t) :: :ok
  def delete(id), do: GenServer.call(__MODULE__, {:delete, id})

  @spec retry_later(%Alods.Queue.Record{}, any) :: :ok | {:error, any}
  def retry_later(record, reason), do: GenServer.call(__MODULE__, {:retry_later, record.id, reason})

  @doc """
  Pushes a record into the store.
  """
  @spec push(atom, String.t, map) :: {:ok, String.t} | {:error, any}
  def push(method, url, data)
  def push(method, url, data)
      when method in @valid_methods and is_map(data) do

    case Alods.Queue.Record.create(%{method: method, url: url, data: data}) do
      {:ok, record} -> GenServer.call(__MODULE__, {:push, record})
      error -> error
    end
  end
  def push(method, url, data) when is_list(data) do
    push(method, url, Enum.into(data, %{}))
  end
  def push(method, _url, data) when is_map(data) do
    {:error, "#{method} is not valid, must be one of #{Enum.join(@valid_methods, ", ")}"}
  end
  def push(_method, _url, data) when not is_map(data) do
    {:error, "data #{inspect data} is not valid, this should be either a map or list"}
  end

  def get_work do
    reset_entries_stuck_in_processing()

    get_pending_entries()
    |> Enum.map(
         fn entry -> case update_status(entry, :processing) do
                       {:ok, record} -> record
                       _ -> nil
                     end
         end
       )
    |> Enum.filter(&(&1 != nil))
  end

  def handle_call({:list}, _caller, state) do
    records = __MODULE__
              |> :dets.select(select_all())

    {:reply, records, state}
  end

  def handle_call({:retry_later, id, reason}, _caller, state) do
    {:ok, record} = find_record(id)
    IO.puts "record #{inspect record}"
    delay = (2 * record.retries)
    delay = if delay > 3600, do: 3600, else: delay
    retry_at = :os.system_time(:seconds) + delay

    record = Alods.Queue.Record.update!(
      record,
      %{timestamp: retry_at, status: :pending, retries: (record.retries + 1), reason: reason}
    )
    :ok = :dets.insert(__MODULE__, {record.id, record})
    {:reply, {:ok, record.id}, state}
  end

  def handle_call({:push, %Alods.Queue.Record{} = record}, _caller, state) do
    case :dets.insert_new(__MODULE__, {record.id, record}) do
      true -> {:reply, {:ok, record.id}, state}
      error -> error
    end
  end

  def handle_call({:get_pending_entries}, _caller, state) do
    records = __MODULE__
              |> :dets.select(select_pending_older_than_or_equal_to_now())
              |> Enum.map(fn {_id, record} -> record end)
    {:reply, records, state}
  end

  def handle_call({:clear}, _caller, state) do
    :ok = :dets.delete_all_objects(__MODULE__)
    {:reply, :ok, state}
  end

  def handle_call({:find, id}, _caller, state) do
    result = find_record(id)
    {:reply, result, state}
  end

  def handle_call({:delete, id}, _caller, state) do
    result = :dets.delete(__MODULE__, id)
    {:reply, result, state}
  end

  def handle_call({:update_status, id, status}, _caller, state) when status in @valid_statuses do
    case find_record(id) do
      {:ok, record} ->
        record = Alods.Queue.Record.update!(record, %{status: status})
        :ok = :dets.insert(__MODULE__, {record.id, record})
        {:reply, {:ok, record}, state}

      error -> {:reply, error, state}
    end
  end

  defp select_all do
    fun do{id, record} when id != nil -> record end
  end

  defp select_pending_older_than_or_equal_to_now do
    now = :os.system_time(:seconds)
    Ex2ms.fun do
      {_id, %{timestamp: timestamp, status: status}} = record when timestamp <= ^now and status == "pending" -> record
    end
  end

  defp select_processing_longer_than_or_equal_to_seconds(seconds) do
    time = :os.system_time(:seconds) - seconds
    Ex2ms.fun do
      {_id, %{timestamp: timestamp, status: status}} = record
      when timestamp <= ^time and status == "processing" -> record
    end
  end

  defp update_status(%Alods.Queue.Record{id: id}, status) when status in @valid_statuses,
       do: GenServer.call(__MODULE__, {:update_status, id, status})

  defp find_record(id) do
    case :dets.lookup(__MODULE__, id) do
      empty_list when empty_list == [] -> {:error, :record_not_found}
      [{_id, record}] -> {:ok, record}
    end
  end

  defp reset_entries_stuck_in_processing do
    seconds = Application.get_env(:alods, :reset_after_processing_in_seconds, 60)
    __MODULE__
    |> :dets.select(select_processing_longer_than_or_equal_to_seconds(seconds))
    |> Enum.each(&(update_status(&1.id, :pending)))
  end
end
