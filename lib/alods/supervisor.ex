defmodule Alods.Supervisor do
  @moduledoc false

  use Supervisor

  def start(_, _) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    children = [worker(Alods.Queue, [])]
    children = maybe_add_producer_and_consumers(
      children,
      Application.get_env(:alods, :start_producers_and_consumers, true)
    )
    supervise(children, strategy: :one_for_one)
  end

  defp maybe_add_producer_and_consumers(children, false), do: children
  defp maybe_add_producer_and_consumers(children, _) do
    children ++ [
      worker(Alods.Producer, []),
      worker(Alods.ConsumerSupervisor, []),
    ]
  end
end
