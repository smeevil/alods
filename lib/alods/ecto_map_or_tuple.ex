defmodule Alods.EctoMapOrTuple do
  @behaviour Ecto.Type
  def type, do: :string

  def cast(value) when is_binary(value), do: {:ok, {:raw, value}}
  def cast(value) when is_map(value), do: {:ok, {:json, value}}
  def cast(value) when is_tuple(value), do: {:ok, value}
  def cast(_), do: :error

  def load(string) when is_binary(string) do
    {function, _} = Code.eval_string(string)
    {:ok, function}
  end

  def dump(data), do: {:ok, data}
end
