defmodule Alods.Consumer do
  @moduledoc """
  This comsumer will request exactly 1 record from the producer
  It will then take care of it by posting or getting the notifications to its respective endpoint
  The only acceptable success code is an HTTP status 200
  """

  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, nil)
  end

  def init(state) do
    {:consumer, state, subscribe_to: [{Alods.Producer, max_demand: 1}]}
  end

  def handle_events(records, _from, state) do
    Enum.each(records, &process/1)
    {:noreply, [], state}
  end

  defp process(%Alods.Store.Record{method: :get} = record) do
    IO.puts "processing GET record #{inspect record}"
    uri = URI.parse(record.url)

    (uri.scheme || "http") <> "://" <> uri.host <> (uri.path || "/") <> "?" <> URI.encode_query(record.data)
    |> HTTPoison.get
    |> handle_response(record)
  end

  defp process(%Alods.Store.Record{method: :post} = record) do
    IO.puts "processing POST record #{inspect record}"
    data = Poison.encode!(record.data)

    record.url
    |> HTTPoison.post(data, [{"Content-Type", "application/json; charset=utf-8"}])
    |> handle_response(record)
  end

  defp handle_response({:ok, %{status_code: 200}}, record), do: Alods.Store.delete(record.id)
  defp handle_response({:ok, response}, record),
       do: Alods.Store.retry_later(record, %{status_code: response.status_code, body: response.body})
  defp handle_response(error, record), do: Alods.Store.retry_later(record, error)

end