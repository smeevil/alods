defmodule Alods.Store.Record do
  @moduledoc """
  A Simple struct which we can use as a return value
  """

  @enforce_keys [:id, :method, :url, :data, :timestamp, :status]
  defstruct [:id, :method, :url, :data, :timestamp, :status, retries: 0, last_failure_reason: nil]
end