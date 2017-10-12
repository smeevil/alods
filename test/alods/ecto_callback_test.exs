defmodule Alods.EctoCallbackTest do
  use ExUnit.Case, async: false

  test "it can cast a function to string" do
    assert {:ok, "&IO.puts/1"} = Alods.EctoCallback.cast(&IO.puts/1)
  end

  test "it will not cast an non existant function" do
    assert :error = Alods.EctoCallback.cast(&Bogus.function/1)
  end

  test "it will not cast an existing function with an arity other then 1" do
    assert :error = Alods.EctoCallback.cast(&IO.inspect/2)
    assert :error = Alods.EctoCallback.cast(&Time.utc_now/0)
  end

  test "it will convert a back to a function on load" do
    {:ok, function} = Alods.EctoCallback.load("&IO.puts/1")
    assert is_function(function)
  end
end

