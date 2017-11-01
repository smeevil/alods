defmodule Alods.Consumer do
  @moduledoc """
  This comsumer will request exactly 1 record from the producer.
  It will then take care of it by posting or getting the notifications to its respective endpoint.
  The only acceptable success code is an HTTP status 200
  """

  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, nil)
  end

  def init(state) do
    {:consumer, state, subscribe_to: [{Alods.Producer, max_demand: 1}]}
  end

  def handle_events(records, _from, state) do
    Enum.each(records, &process/1)
    {:noreply, [], state}
  end

  defp process(%Alods.Record{method: "get", data: {:json, data}} = record) do
    record.url
    |> construct_url
    |> Kernel.<>("?")
    |> Kernel.<>(URI.encode_query(data))
    |> HTTPoison.get
    |> handle_response(record)
  end

  defp process(%Alods.Record{method: "post"} = record) do
    data = maybe_encode_data(record.data)

    record.url
    |> construct_url
    |> HTTPoison.post(data, headers_for(record))
    |> handle_response(record)
  end

  defp headers_for(%Alods.Record{data: data, url: url}) do
    headers = [{"Content-Type", content_type_for_data(data)}]
    case URI.parse(url) do
      %URI{userinfo: nil} -> headers
      %URI{userinfo: user_pass} -> [{"Authorization", "Basic #{Base.encode64(user_pass)}"} | headers]
    end
  end

  defp maybe_encode_data({:json, data}) when is_map(data), do: Poison.encode!(data)
  defp maybe_encode_data({:xml, data}) when is_binary(data), do: data
  defp maybe_encode_data({:raw, data}), do: Macro.to_string(data)

  defp content_type_for_data({:json, data}) when is_map(data), do: "application/json; charset=utf-8"
  defp content_type_for_data({:xml, data}) when is_binary(data), do: "application/xml; charset=utf-8"
  defp content_type_for_data(data) when is_map(data), do: "application/json; charset=utf-8"
  defp content_type_for_data(_), do: "application/x-www-form-urlencoded; charset=utf-8"

  defp handle_response({:ok, %{status_code: 200}}, record), do: Alods.Delivered.success(record)
  defp handle_response({:ok, response}, record),
       do: Alods.Queue.retry_later(record, %{status_code: response.status_code, body: response.body})
  defp handle_response({:error, %HTTPoison.Error{reason: reason} = error}, record)
       when reason == :nxdomain or reason == "nxdomain",
       do: Alods.Delivered.permanent_failure(record, %{error: error})
  defp handle_response(error, record), do: Alods.Queue.retry_later(record, %{unhandled_error: error})

  defp construct_url(url) do
    uri = URI.parse(url)

    uri
    |> Map.put(:path, uri.path || "/")
    |> URI.to_string
  end
end
