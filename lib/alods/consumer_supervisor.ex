defmodule Alods.ConsumerSupervisor do
  @moduledoc false

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    children = gen_consumers(Application.get_env(:alods, :consumer_amount, 1))
    supervise(children, strategy: :one_for_one)
  end

  defp gen_consumers(amount) do
    import Supervisor.Spec, warn: false
    Enum.map(
      (1..amount),
      fn i ->
        worker(Alods.Consumer, [], id: i)
      end
    )
  end
end
