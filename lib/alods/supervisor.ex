defmodule Alods.Supervisor do
  @moduledoc false

  use Supervisor

  def start(_, _) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    children = [
      worker(Alods.Store, []),
    ]
    children = if Application.get_env(:alods, :env) != :test do
      children ++ [
        worker(Alods.Producer, []),
        worker(Alods.ConsumerSupervisor, []),
      ]
    else
      children
    end
    supervise(children, strategy: :one_for_one)
  end

end