defmodule Alods.Delivered do
  @moduledoc """
    This module takes care of starting a DETS store which will hold delivered messages.
  """

  import Ex2ms
  use GenServer
  use Alods.DETS, "delivered"

  def init(name) do
    result = super(name)

    _pid = clean_store()
    twenty_four_hours_in_ms = 1000 * 60 * 60 * 24
    {:ok, _ref} = :timer.apply_interval(twenty_four_hours_in_ms, __MODULE__, :clean_store, [])

    result
  end

  @spec store(%Alods.Record{}) :: :ok
  def store(%Alods.Record{} = record) do
    {:ok, record_id} = push(record)
    :ok = Alods.Queue.delete(record_id)
  end

  @spec push(%Alods.Record{}) :: {:ok, String.t} | {:error, String.t}
  defp push(%Alods.Record{} = record) do
    record = Alods.Record.update!(
      record,
      delivered_at: DateTime.utc_now,
      status: :delivered,
      reason: nil,
      timestamp: :os.system_time(:seconds)
    )
    GenServer.call(__MODULE__, {:push, record})
  end

  @spec select_all :: list
  defp select_all do
    fun do{id, record} when id != nil -> record end
  end

  def clean_store, do: Process.spawn(fn -> GenServer.cast(__MODULE__, {:clean_store}) end, [])

  def handle_cast({:clean_store}, state) do
    query = select_processing_longer_than_days(Application.get_env(:alods, :store_delivered_entries_for_days, 7))
    __MODULE__
    |> :dets.select(query)
    |> Enum.each(fn {_id, record} -> delete(record) end)

    {:noreply, state}
  end

  @spec select_processing_longer_than_days(non_neg_integer) :: list
  defp select_processing_longer_than_days(days) do
    time = :os.system_time(:seconds) - (days * 86400)
    Ex2ms.fun do
      {_id, %{timestamp: timestamp, status: status}} = record
      when timestamp <= ^time and status == "delivered" -> record
    end
  end
end
