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

  defp notify(method, url, data), do: Alods.Queue.push(method, url, data)

  #  For demo purpose only, remove me later
  #  def stress do
  #    Enum.each(
  #      0..99,
  #      fn _ ->
  #        #      Alods.Queue.push(Enum.random([:get, :post]), "http://0.0.0.0/success", %{foo: "bar", bar: false})
  #        Alods.Queue.push(Enum.random([:get, :post]), "http://0.0.0.0/random", %{foo: "bar", bar: false})
  #      end
  #    )
  #  end

end
