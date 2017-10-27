defmodule Alods.RecordTest do
  use ExUnit.Case

  test "validations" do
    assert {
             :error,
             [
               data: "can't be blank",
               method: "can't be blank",
               url: "can't be blank"
             ]
           } == Alods.Record.create()
  end

  test "it createds a record struct with raw data" do
    assert {
             :ok,
             %Alods.Record{
               created_at: created_at,
               data: {:raw, "maybe: true"},
               id: record_id,
               reason: nil,
               method: "post",
               retries: 0,
               status: "pending",
               timestamp: timestamp,
               updated_at: nil,
               url: "http://www.example.com/callback"
             }
           } = Alods.Record.create(
             method: :post,
             url: "http://www.example.com/callback",
             data: "maybe: true"
           )

    assert nil != record_id
    assert nil != created_at
    assert nil != timestamp
  end

  test "it createds a record struct with json" do
    assert {
             :ok,
             %Alods.Record{
               created_at: created_at,
               data: {:json, %{
                 maybe: true
               }},
               id: record_id,
               reason: nil,
               method: "post",
               retries: 0,
               status: "pending",
               timestamp: timestamp,
               updated_at: nil,
               url: "http://www.example.com/callback"
             }
           } = Alods.Record.create(
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

  test "it createds a record struct with xml" do
    assert {
             :ok,
             %Alods.Record{
               created_at: created_at,
               data: {:xml, "<root><foo>bar</foo></root>"},
               id: record_id,
               reason: nil,
               method: "post",
               retries: 0,
               status: "pending",
               timestamp: timestamp,
               updated_at: nil,
               url: "http://www.example.com/callback"
             }
           } = Alods.Record.create(
             method: :post,
             url: "http://www.example.com/callback",
             data: {:xml, "<root><foo>bar</foo></root>"}
           )

    assert nil != record_id
    assert nil != created_at
    assert nil != timestamp
  end

  test "it checks the url" do
    assert  {:error, [url: "invalid_host"]} == Alods.Record.create(
              method: :post,
              url: "http://examp!@#$#%^%&%*^&le.com",
              data: %{
                maybe: true
              }
            )
  end

  test "it validates updates" do
    {:ok, record} = Alods.Record.create(
      %{
        method: :post,
        url: "http://www.example.com/callback",
        data: %{
          maybe: true
        }
      }
    )

    assert {
             :error,
             [status: "should be one of delivered, pending, permanent_failure, processing"]
           } == Alods.Record.update(record, status: :wrong)

  end
end
