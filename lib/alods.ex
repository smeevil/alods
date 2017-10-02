defmodule Alods do
  @moduledoc """
  Documentation for Alods.
  """

  @doc """
  Deliver a notification via an HTTP GET request to the given url
  the data will be url-encoded and attached as query string to the url
  """
  @spec notify_by_get(String.t, map | list) :: {:ok, String.t}
  def notify_by_get(url, data), do: notify(:get, url, data)

  @doc """
  Deliver a notification via an HTTP POST request to the given url.
  The data will be JSON encoded and be attached to the body
  """
  @spec notify_by_post(String.t, map | list) :: {:ok, String.t}
  def notify_by_post(url, data), do: notify(:post, url, data)

  @doc """
  Returns a list of all current notifications that are waiting for delivery
  """
  @spec list_queue() :: [%Alods.Store.Record{}]
  def list_queue, do: Alods.Store.list

  @doc """
  Returns the number of notifications that are waiting for delivery
  """
  @spec queue_size() :: non_neg_integer
  def queue_size, do: Alods.Store.size

  #TODO For demo purpose only, remove me later
  def stress do
    Enum.each(0..99, fn _ ->
#      Alods.Store.push(Enum.random([:get, :post]), "http://0.0.0.0/success", %{foo: "bar", bar: false})
      Alods.Store.push(Enum.random([:get, :post]), "http://0.0.0.0/random", %{foo: "bar", bar: false})
    end)
  end

  defp notify(method, url, data), do: Alods.Store.push(method, url, data)
end
