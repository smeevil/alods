defmodule Alods.EctoAtom do
  @behaviour Ecto.Type
  def type, do: :string

  def cast(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def cast(_), do: :error

  def load(string) when is_binary(string) do
    {:ok, String.to_atom(string)}
  end

  def dump(data), do: {:ok, data}
end
