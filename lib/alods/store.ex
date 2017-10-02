defmodule Alods.Store do
  @moduledoc """
    This module takes care of starting a DETS store.
  """

  use GenServer
  import Ex2ms

  @valid_methods [:get, :post]
  @valid_statuss [:pending, :processing]

  @reset_after_processing_in_seconds 5

  @spec start_link :: {:ok, pid}
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    Process.flag(:trap_exit, true)
    path = File.cwd! <> "/priv"
    file = "/alods_store_#{Application.get_env(:alods, :env)}.ets"
    unless File.exists?(path), do: File.mkdir_p!(path)
    auto_save = Application.get_env(:alods, :store_auto_save_ms, :timer.seconds(60))

    {:ok, reference} = :dets.open_file(__MODULE__, file: to_charlist(path <> file), auto_save: auto_save)
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

  @spec find(String.t) :: %Alods.Store.Record{}
  def find(id), do: GenServer.call(__MODULE__, {:find, id})

  @spec delete(String.t) :: :ok
  def delete(id), do: GenServer.call(__MODULE__, {:delete, id})

  @spec retry_later(%Alods.Store.Record{}, any) :: :ok | {:error, any}
  def retry_later(record, reason), do: GenServer.call(__MODULE__, {:retry_later, record.id, reason})

  @doc """
  Pushes a record into the store.
  """
  @spec push(atom, String.t, map) :: {:ok, String.t} | {:error, any}
  def push(method, url, data)
  def push(method, url, data)
      when method in @valid_methods and is_map(data) do

    case validate_url(url) do
      {:ok, _} -> GenServer.call(__MODULE__, {:push, Ecto.UUID.generate(), method, url, data})
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
         fn entry -> case update_status(entry.id, :processing) do
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
              |> Enum.map(&to_struct/1)

    {:reply, records, state}
  end

  def handle_call({:retry_later, id, reason}, _caller, state) do
    {:ok, record} = find_record(id)
    IO.puts "record #{inspect record}"
    retry_at = :os.system_time(:seconds) + (2 * record.retries)
    data = {record.id, record.method, record.url, record.data, retry_at, :pending, (record.retries + 1), reason}
    :ok = :dets.insert(__MODULE__, data)
    {:reply, {:ok, to_struct(data)}, state}
  end

  def handle_call({:push, id, method, url, data}, _caller, state) do
    case :dets.insert_new(__MODULE__, {id, method, url, data, :os.system_time(:seconds), :pending, 0, nil}) do
      true -> {:reply, {:ok, id}, state}
      error -> error
    end
  end

  def handle_call({:get_pending_entries}, _caller, state) do
    records = __MODULE__
              |> :dets.select(select_pending_older_than_or_equal_to_now())
              |> Enum.map(&to_struct/1)

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

  def handle_call({:update_status, id, status}, _caller, state) when status in @valid_statuss do
    case find_record(id) do
      {:ok, record} ->
        data = {
          record.id,
          record.method,
          record.url,
          record.data,
          :os.system_time(:seconds),
          status,
          record.retries,
          record.last_failure_reason
        }
        :ok = :dets.insert(__MODULE__, data)
        {:reply, {:ok, to_struct(data)}, state}
      error -> {:reply, error, state}
    end
  end

  @spec validate_url(String.t) :: {:ok, String.t} | {:error, atom}
  defp validate_url(host) do
    case URI.parse(host) do
      %{scheme: scheme} when not scheme in ["http", "https"] -> {:error, :invalid_or_missing_protocol}
      %{host: nil} -> {:error, :invalid_host}
      _ -> {:ok, host}
    end
  end

  defp select_all do
    fun do{id, method, url, data, timestamp, status, retries, reason} when id != nil ->
      {id, method, url, data, timestamp, status, retries, reason} end
  end

  defp select_pending_older_than_or_equal_to_now do
    now = :os.system_time(:seconds)
    fun do
      {id, method, url, data, timestamp, status, retries, reason} when timestamp <= ^now and status == :pending ->
        {id, method, url, data, timestamp, status, retries, reason}
    end
  end

  defp select_processing_longer_than_or_equal_to_seconds(seconds) do
    time = :os.system_time(:seconds) - seconds
    fun do
      {id, method, url, data, timestamp, status, retries, reason} when timestamp <= ^time and status == :processing ->
        {id, method, url, data, timestamp, status, retries, reason}
    end
  end

  defp update_status(id, status) when status in @valid_statuss,
       do: GenServer.call(__MODULE__, {:update_status, id, status})

  defp to_struct({id, method, url, data, timestamp, status, retries, reason}) do
    %Alods.Store.Record{
      id: id,
      method: method,
      url: url,
      data: data,
      timestamp: timestamp,
      status: status,
      retries: retries,
      last_failure_reason: reason
    }
  end

  defp find_record(id) do
    case :dets.lookup(__MODULE__, id) do
      empty_list when empty_list == [] -> {:error, :record_not_found}
      [record] -> {:ok, to_struct(record)}
    end
  end

  defp reset_entries_stuck_in_processing do
    __MODULE__
    |> :dets.select(select_processing_longer_than_or_equal_to_seconds(@reset_after_processing_in_seconds))
    |> Enum.map(&to_struct/1)
    |> Enum.each(&(update_status(&1.id, :pending)))
  end
end