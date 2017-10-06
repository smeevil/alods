defmodule Alods.Queue.RecordTest do
  use ExUnit.Case

  test "it createds a record struct" do
    assert {
      :ok,
      %Alods.Queue.Record{
        created_at: created_at,
        data: %{
          maybe: true
        },
        id: record_id,
        reason: nil,
        method: "post",
        retries: 0,
        status: "pending",
        timestamp: timestamp,
        updated_at: nil,
        url: "http://www.example.com/callback"
      }
    } = Alods.Queue.Record.create(
      method: :post,
      url: "http://www.example.com/callback",
      data: %{
        maybe: true
      }
    )

    assert nil != record_id
    assert nil != created_at
    assert nil != timestamp
  end


end
