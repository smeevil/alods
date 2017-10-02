defmodule Alods.StoreTest do
  use ExUnit.Case
  doctest Alods

  setup do
    Alods.Store.clear!()
  end

  test "the store is empty" do
    assert 0 = Alods.Store.length
    assert 0 = Alods.Store.size
  end

  test "it stores a GET entry" do
    assert 0 = Alods.Store.size
    assert {:ok, _} = Alods.Store.push(:get, "http://www.example.com/call_me", %{maybe: true})
    assert 1 = Alods.Store.size
  end

  test "it stores a POST entry" do
    assert 0 = Alods.Store.size
    assert {:ok, _} = Alods.Store.push(:post, "http://www.example.com/callback", %{maybe: true})
    assert 1 = Alods.Store.size
  end

  test "it stores an entry with data as list" do
    assert 0 = Alods.Store.size
    assert {:ok, _} = Alods.Store.push(:get, "http://www.example.com/call_me", maybe: true)
    assert 1 = Alods.Store.size
  end

  test "it will throw an error when the data argument is not a map or list" do
    assert {:error, "data \"this=wrong\" is not valid, this should be either a map or list"} = Alods.Store.push(
             :put,
             "http://www.example.com/callback",
             "this=wrong"
           )
  end

  test "it will not store a PUT entry" do
    assert  {:error, "put is not valid, must be one of get, post"} = Alods.Store.push(
              :put,
              "http://www.example.com/callback",
              %{maybe: true}
            )
  end

  test "it clears all the records" do
    assert 0 = Alods.Store.size
    assert {:ok, _} = Alods.Store.push(:get, "http://www.example.com/call_me", maybe: true)
    assert {:ok, _} = Alods.Store.push(:get, "http://www.example.com/call_me", maybe: true)
    assert 2 = Alods.Store.size
    Alods.Store.clear!()
    assert 0 = Alods.Store.size
  end

  test "it can list all records" do
    assert 0 = Alods.Store.size
    assert {:ok, _} = Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert {:ok, _} = Alods.Store.push(
             :get,
             "http://www.example.com/call_me",
             [returned: true]
           )
    assert {:ok, _} = Alods.Store.push(
             :get,
             "http://www.example.com/call_me",
             %{returned: false}
           )
    assert 3 = Alods.Store.size

    records = Alods.Store.list()
    assert 3 = Enum.count(records)
  end

  test "it can return waiting entries" do
    assert 0 = Alods.Store.size
    assert records = Alods.Store.get_pending_entries()
    assert 0 = Enum.count(records)

    assert {:ok, _} = Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert {:ok, _} = Alods.Store.push(
             :get,
             "http://www.example.com/call_me",
             [returned: true]
           )
    assert {:ok, _} = Alods.Store.push(
             :get,
             "http://www.example.com/call_me",
             %{returned: false}
           )
    assert 3 = Alods.Store.size

    records = Alods.Store.get_pending_entries()
    assert 3 = Enum.count(records)
  end

  test "it can find a record" do
    assert 0 = Alods.Store.size
    {:ok, id} = Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    record = Alods.Store.find(id)
    assert {
             :ok,
             %Alods.Store.Record{
               data: %{
                 returned: true
               },
               id: ^id,
               method: :get,
               status: :pending,
               timestamp: _ts,
               url: "http://www.example.com/call_me"
             }
           } = record
  end

  test "it should be able to get work" do
    assert 0 = Alods.Store.size
    Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert 3 = Enum.count(Alods.Store.get_pending_entries())
    assert 3 = Enum.count(Alods.Store.get_work())

    assert 0 = Enum.count(Alods.Store.get_pending_entries())
    assert 0 = Enum.count(Alods.Store.get_work())
  end

  test "it can delete a record" do
    assert 0 = Alods.Store.size
    {:ok, id} = Alods.Store.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert 1 = Alods.Store.size
    assert :ok = Alods.Store.delete(id)
    assert 0 = Alods.Store.size

  end
end
