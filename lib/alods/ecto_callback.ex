defmodule Alods.EctoCallback do
  @behaviour Ecto.Type
  def type, do: :string

  def cast(callback) when is_function(callback) do
    {:ok, quoted} = Code.string_to_quoted(Macro.to_string(callback))
    case quoted do
      {:&, _, [{_, _, [{{_, _, [{_, _, module}, function]}, _, _}, 1]}]} -> check_function(callback, module, function)
      other -> :error
    end
  end
  def cast(_), do: :error

  def load(string) when is_binary(string) do
    {function, _} = Code.eval_string(string)
    {:ok, function}
  end

  def dump(data), do: {:ok, data}

  defp check_function(callback, module, function) do
    module = Module.concat(module)
    with {:module, _} <- Code.ensure_loaded(module),
         true <- function_exported?(module, function, 1)
      do
      {:ok, Macro.to_string(callback)}
    else
      _ -> :error
    end
  end
end
