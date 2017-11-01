defmodule Alods.Delivered do
  @moduledoc """
    This module takes care of starting a DETS store which will hold delivered messages.
  """

  import Ex2ms
  require Logger

  use Alods.DETS, "delivered"

  @spec init(String.t) :: {:ok, nil}
  def init(name) do
    {:ok, _} = super(name)

    _pid = clean_store()
    twenty_four_hours_in_ms = 1000 * 60 * 60 * 24
    {:ok, _ref} = :timer.apply_interval(twenty_four_hours_in_ms, __MODULE__, :clean_store, [])

    {:ok, nil}
  end

  @doc """
  This function will initiate a DETS table clean, meaning it will remove all entries which are older then the configured store time, which by default is 7 days.
  """
  @spec clean_store :: pid() | {pid(), reference()}
  def clean_store, do: Process.spawn(fn -> GenServer.cast(__MODULE__, {:clean_store}) end, [])

  @doc """
  Stores the given record, updating the delivred at field, resetting the reason, and setting the status to delivered.
  After successful storing, it will be deleted from the Queue.
  """
  @spec success(%Alods.Record{}) :: :ok
  def success(%Alods.Record{} = record) do
    record
    |> Alods.Record.update!(delivered_at: DateTime.utc_now, status: :delivered, reason: nil)
    |> insert_and_maybe_run_callback
  end

  @doc """
  Stores the given record and sets the status to permanent failure.
  After successful storing, it will be deleted from the Queue.
  """
  @spec permanent_failure(%Alods.Record{}, map) :: :ok
  def permanent_failure(%Alods.Record{} = record, reason) do
    record
    |> Alods.Record.update!(delivered_at: nil, status: :permanent_failure, reason: reason)
    |> insert_and_maybe_run_callback
  end

  def handle_cast({:clean_store}, state) do
    query = select_processing_longer_than_days(Application.get_env(:alods, :store_delivered_entries_for_days, 7))
    __MODULE__
    |> :dets.select(query)
    |> Enum.each(fn {_id, record} -> delete(record) end)

    {:noreply, state}
  end

  @spec select_all :: list
  defp select_all do
    fun do{id, record} when id != nil -> record end
  end

  @spec select_processing_longer_than_days(non_neg_integer) :: list
  defp select_processing_longer_than_days(days) do
    time = :os.system_time(:seconds) - (days * 86400)
    Ex2ms.fun do
      {_id, %{timestamp: timestamp, status: status}} = record
      when timestamp <= ^time and status == "delivered" -> record
    end
  end

  defp maybe_run_callback(%Alods.Record{callback: callback} = record) when not is_nil(callback) do
    try do
      {function, _} = Code.eval_string(record.callback)
      function.(record)
    rescue
      error -> Logger.warn("Callback function #{record.callback} failed with #{inspect error}")
    end
  end
  defp maybe_run_callback(_), do: nil

  defp insert_and_maybe_run_callback(record) do
    true = :dets.insert_new(__MODULE__, {record.id, record})
    :ok = Alods.Queue.delete(record.id)

    maybe_run_callback(record)
    :ok
  end
end
