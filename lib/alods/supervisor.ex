defmodule Alods.Supervisor do
  @moduledoc false

  use Supervisor

  def start(_, _) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    start_producers_and_consumers = Application.get_env(:alods, :start_producers_and_consumers, true)

    children = [
                 worker(Alods.Queue, []),
                 worker(Alods.Delivered, [])
               ] ++ maybe_add_producer_and_consumers(start_producers_and_consumers)

    supervise(children, strategy: :one_for_one)
  end

  defp maybe_add_producer_and_consumers(false), do: []
  defp maybe_add_producer_and_consumers(_) do
    [
      worker(Alods.Producer, []),
      worker(Alods.ConsumerSupervisor, []),
    ]
  end
end
