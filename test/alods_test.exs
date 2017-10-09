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

      Alods.Producer.start_link()
      Alods.ConsumerSupervisor.start_link()
      :timer.sleep(110)

      assert 0 = Alods.Queue.size
      assert 1 = Alods.Delivered.size

      record = List.first(Alods.Delivered.list)
      refute nil == record.delivered_at
      assert record.status == "delivered"
    end
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
end
