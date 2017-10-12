defmodule Alods.Queue do
  @moduledoc """
    This module takes care of starting a DETS store which will hold the message to be delivered.
  """

  import Ex2ms
  use Alods.DETS, "queue"

  @valid_methods [:get, :post]
  @valid_statuses [:pending, :processing]

  @doc """
  Returns all entries of which their timestamp are smaller then the current time
  """
  @spec get_pending_entries :: {:ok, [{String.t, atom, String.t, map, number, atom}]}
  def get_pending_entries, do: GenServer.call(__MODULE__, {:get_pending_entries})

  @spec retry_later(%Alods.Record{}, any) :: :ok | {:error, any}
  def retry_later(record, reason), do: GenServer.call(__MODULE__, {:retry_later, record.id, reason})

  @doc """
  Pushes a record into the store.
  """
  @spec push(atom, String.t, map | list, function | nil) :: {:ok, String.t} | {:error, any}
  def push(method, url, data, callback \\ nil)
  def push(method, url, data, callback)
      when method in @valid_methods and is_map(data) do

    case Alods.Record.create(%{method: method, url: url, data: data, callback: callback}) do
      {:ok, record} ->
        case :dets.insert_new(__MODULE__, {record.id, record}) do
          true -> {:ok, record.id}
          error -> error
        end
      error -> error
    end
  end
  def push(method, url, data, callback) when is_list(data) do
    push(method, url, Enum.into(data, %{}), callback)
  end
  def push(method, _url, data, callback) when is_map(data) do
    {:error, "#{method} is not valid, must be one of #{Enum.join(@valid_methods, ", ")}"}
  end
  def push(_method, _url, data, callback) when not is_map(data) do
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

  #  defp update_status({_id, %Alods.Record{} = record}, status), do: update_status(record, status)
  defp update_status(%Alods.Record{} = record, status) when status in @valid_statuses,
       do: GenServer.call(__MODULE__, {:update_status, record, status})

  defp reset_entries_stuck_in_processing do
    seconds = Application.get_env(:alods, :reset_after_processing_in_seconds, 60)

    __MODULE__
    |> :dets.select(select_processing_longer_than_or_equal_to_seconds(seconds))
    |> Enum.each(&(update_status(&1, :pending)))
  end

  @spec select_all :: list
  defp select_all do
    fun do{id, record} when id != nil -> record end
  end

  @spec select_pending_older_than_or_equal_to_now :: list
  defp select_pending_older_than_or_equal_to_now do
    now = :os.system_time(:seconds)
    Ex2ms.fun do
      {_id, %{timestamp: timestamp, status: status}} = record when timestamp <= ^now and status == "pending" ->
        record
    end
  end

  @spec select_processing_longer_than_or_equal_to_seconds(non_neg_integer) :: list
  defp select_processing_longer_than_or_equal_to_seconds(seconds) do
    time = :os.system_time(:seconds) - seconds
    Ex2ms.fun do
      {_id, %{timestamp: timestamp, status: status}} = record
      when timestamp <= ^time and status == "processing" -> record
    end
  end

  def handle_call({:retry_later, id, reason}, _caller, state) do
    {:ok, record} = find(id)
    delay = (2 * record.retries)
    delay = if delay > 3600, do: 3600, else: delay
    retry_at = :os.system_time(:seconds) + delay

    record = Alods.Record.update!(
      record,
      %{timestamp: retry_at, status: :pending, retries: (record.retries + 1), reason: reason}
    )
    :ok = :dets.insert(__MODULE__, {record.id, record})
    {:reply, {:ok, record.id}, state}
  end

  def handle_call({:get_pending_entries}, _caller, state) do
    records = __MODULE__
              |> :dets.select(select_pending_older_than_or_equal_to_now())
              |> Enum.map(fn {_id, record} -> record end)
    {:reply, records, state}
  end

  def handle_call({:update_status, record, status}, _caller, state) when status in @valid_statuses do
    #    case find_record(id) do
    #      {:ok, record} ->
    record = Alods.Record.update!(record, %{status: status})
    :ok = :dets.insert(__MODULE__, {record.id, record})
    {:reply, {:ok, record}, state}

    #      error -> {:reply, error, state}
    #  end
  end

end
