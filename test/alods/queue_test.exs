defmodule Alods.QueueTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir("test/fixture/vcr_cassettes")
    :ok
  end

  setup do
    Alods.Queue.clear!()
    Alods.Delivered.clear!()
  end

  test "the store is empty" do
    assert 0 = Alods.Queue.length
    assert 0 = Alods.Queue.size
  end

  test "it stores a GET entry" do
    assert 0 = Alods.Queue.size
    assert {:ok, _} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{maybe: true})
    assert 1 = Alods.Queue.size
  end

  test "it stores a POST entry" do
    assert 0 = Alods.Queue.size
    assert {:ok, _} = Alods.Queue.push(:post, "http://www.example.com/callback", %{maybe: true})
    assert 1 = Alods.Queue.size
  end

  test "it stores an entry with data as list" do
    assert 0 = Alods.Queue.size
    assert {:ok, _} = Alods.Queue.push(:get, "http://www.example.com/call_me", maybe: true)
    assert 1 = Alods.Queue.size
  end

  test "it will not store a PUT entry" do
    assert  {:error, "put is not valid, must be one of get, post"} = Alods.Queue.push(
              :put,
              "http://www.example.com/callback",
              %{maybe: true}
            )
  end

  test "it requires a protocol" do
    assert  {:error, [url: "invalid_or_missing_protocol"]} = Alods.Queue.push(:get, "www.example.com", %{maybe: true})
  end

  test "it will not store a FTP protocol" do
    assert  {:error, [url: "invalid_or_missing_protocol"]} = Alods.Queue.push(
              :get,
              "ftp://www.example.com",
              %{maybe: true}
            )
  end

  test "it clears all the records" do
    assert 0 = Alods.Queue.size
    assert {:ok, _} = Alods.Queue.push(:get, "http://www.example.com/call_me", maybe: true)
    assert {:ok, _} = Alods.Queue.push(:get, "http://www.example.com/call_me", maybe: true)
    assert 2 = Alods.Queue.size
    Alods.Queue.clear!()
    assert 0 = Alods.Queue.size
  end

  test "it can list all records" do
    assert 0 = Alods.Queue.size
    assert {:ok, _} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert {:ok, _} = Alods.Queue.push(
             :get,
             "http://www.example.com/call_me",
             [returned: true]
           )
    assert {:ok, _} = Alods.Queue.push(
             :get,
             "http://www.example.com/call_me",
             %{returned: false}
           )
    assert 3 = Alods.Queue.size

    records = Alods.Queue.list()
    assert 3 = Enum.count(records)
  end

  test "it can return waiting entries" do
    assert 0 = Alods.Queue.size
    assert records = Alods.Queue.get_pending_entries()
    assert 0 = Enum.count(records)

    assert {:ok, _} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert {:ok, _} = Alods.Queue.push(
             :get,
             "http://www.example.com/call_me",
             [returned: true]
           )
    assert {:ok, _} = Alods.Queue.push(
             :get,
             "http://www.example.com/call_me",
             %{returned: false}
           )
    assert 3 = Alods.Queue.size

    records = Alods.Queue.get_pending_entries()
    assert 3 = Enum.count(records)
  end

  test "it can find a record" do
    assert 0 = Alods.Queue.size
    {:ok, id} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    record = Alods.Queue.find(id)
    assert {
             :ok,
             %Alods.Record{
               data: {:json, %{
                 returned: true
               }},
               id: ^id,
               method: "get",
               status: "pending",
               timestamp: _ts,
               url: "http://www.example.com/call_me"
             }
           } = record
  end

  test "it should be able to get work" do
    assert 0 = Alods.Queue.size
    Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert 3 = Enum.count(Alods.Queue.get_pending_entries())
    assert 3 = Enum.count(Alods.Queue.get_work())

    assert 0 = Enum.count(Alods.Queue.get_pending_entries())
    assert 0 = Enum.count(Alods.Queue.get_work())
  end

  test "it can delete a record" do
    assert 0 = Alods.Queue.size
    {:ok, id} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    assert 1 = Alods.Queue.size
    assert :ok = Alods.Queue.delete(id)
    assert 0 = Alods.Queue.size
  end

  test "it can retry a record later" do
    {:ok, id} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    {:ok, original_record} = Alods.Queue.find(id)
    {:ok, updated_id} = Alods.Queue.retry_later(original_record, %{my_reason: "testing"})

    assert id == updated_id

    {:ok, updated_record} = Alods.Queue.find(updated_id)
    assert %{
             reason: %{
               my_reason: "testing"
             },
             retries: 1
           } = updated_record
  end

  test "it can't store the same record twice" do
    {:ok, id} = Alods.Queue.push(:get, "http://www.example.com/call_me", %{returned: true})
    {:ok, record} = Alods.Queue.find(id)
    :ok = Alods.Delivered.success(record)
    assert_raise MatchError, fn -> Alods.Delivered.success(record) end
  end
end
