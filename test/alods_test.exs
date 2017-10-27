defmodule AlodsTest do

  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest Alods

  setup_all do
    ExVCR.Config.cassette_library_dir("test/fixture/vcr_cassettes")
    :ok
  end

  setup do
    Alods.Queue.clear!()
    Alods.Delivered.clear!()
  end

  test "it will store a delivered request by get" do
    use_cassette "store_test_get_success" do
      Alods.notify_by_get("http://www.example.com", %{returned: true})
      assert 1 = Alods.Queue.size
      record = List.first(Alods.Queue.list)
      assert nil == record.delivered_at
      assert 0 = Alods.Delivered.size
      {:ok, ^record} = Alods.Queue.find(record.id)
      {:error, :record_not_found} = Alods.Delivered.find(record.id)

      assert %{delivered: 0, queued: 1} == Alods.queue_sizes()
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)

      assert 0 = Alods.Queue.size
      assert 1 = Alods.Delivered.size

      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
      {:error, :record_not_found} = Alods.Queue.find(record.id)
      {:ok, ^record} = Alods.Delivered.find(record.id)
      assert %{delivered: 1, queued: 0} == Alods.queue_sizes()
    end
  end

  test "it can return queue sizes" do
    assert %{delivered: 0, queued: 0} == Alods.queue_sizes()
  end

  test "it can list queued records" do
    assert [] == Alods.list_queued()
  end

  test "it can list delivered records" do
    assert [] == Alods.list_delivered()
  end

  test "it will store a delivered request by post" do
    use_cassette "store_test_post_success" do
      Alods.notify_by_post("http://www.example.com", %{returned: true})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
  end

  test "it will post raw form data" do
    use_cassette "post_raw_form_data_success" do
      Alods.notify_by_post("http://www.example.com", "returned=true")
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
  end

  test "it will post raw map data" do
    use_cassette "post_raw_map_data_success" do
      Alods.notify_by_post("http://www.example.com", {:raw, %{returned: true}})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(2000)
      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
  end

  test "it will post json data" do
    use_cassette "post_json_data_success" do
      Alods.notify_by_post("http://www.example.com", {:json, %{returned: true}})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
  end

  test "it will post xml data" do
    use_cassette "post_xml_data_success" do
      Alods.notify_by_post("http://www.example.com", {:xml, "<root><foo>bar</foo></root>"})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
  end


  test "it will post json data with basic authorization " do
    use_cassette "post_json_data_with_authorization_success" do
      Alods.notify_by_post("http://user:pass@www.example.com", %{returned: true})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
  end


  test "it will retry a failed request by get" do
    use_cassette "store_test_get_failure" do
      Alods.notify_by_get("http://www.example.com/404", %{returned: true})
      assert 1 = Alods.Queue.size
      record = List.first(Alods.Queue.list)
      assert nil == record.delivered_at
      assert 0 = Alods.Delivered.size

      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)

      assert 1 = Alods.Queue.size
      assert 0 = Alods.Delivered.size

      record = List.first(Alods.Queue.list)
      assert nil == record.delivered_at
      assert record.retries == 2
      assert %{status_code: 404, body: _} = record.reason
    end
  end

  test "it will retry a failed request by post" do
    use_cassette "store_test_post_failure" do
      Alods.notify_by_get("http://www.example.com/404", %{returned: true})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Queue.list)
      assert nil == record.delivered_at
      assert record.retries == 2
      assert %{status_code: 404, body: _} = record.reason
    end
  end

  #NOTE this should only show a warning, not raise, no idea how to test it actually did emit the warning without mocking it.
  test "incorrect callback result" do
    use_cassette "store_test_post_success" do
      Alods.notify_by_post("http://www.example.com", %{returned: true}, &IO.puts/1)
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
    end
  end

  test "should store permanent failures immediatly" do
    use_cassette "store_test_nxdomain" do
      Alods.notify_by_post("http://www.thisdomainshouldreallynotexists123abc.com", %{})
      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)
      record = List.first(Alods.Delivered.list)
      assert nil == record.delivered_at
      assert "permanent_failure" == record.status
      assert  %{
                error: %HTTPoison.Error{
                  id: nil,
                  reason: "nxdomain"
                }
              } = record.reason
    end
  end
end
