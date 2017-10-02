defmodule Alods.Producer do
  @moduledoc """
  This producer will check the Alods.Store for waiting notifications.
  These notifications will then be passed along to the consumers.
  """

  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_options), do: {:producer, []}

  def handle_demand(_demand, []) do
    work = wait_for_work()
    {:noreply, work, []}
  end
  def handle_demand(demand, work) do
    {chunk, rest} = Enum.split(work, demand)
    {:noreply, chunk, rest}
  end

  def wait_for_work do
    case Alods.Store.get_work() do
      work when work != [] -> work
      _no_work ->
        :timer.sleep(Application.get_env(:alods, :check_for_work_delay_in_ms, :timer.seconds(1)))
        wait_for_work()
    end
  end

end