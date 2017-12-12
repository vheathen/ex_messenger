defmodule ExSmsBlissTest.ManagerTest do
  use ExUnit.Case, async: false

  import ExSmsBliss.ApiTestHelper
  alias ExSmsBliss.TeslaMockJson

  alias ExSmsBliss.Manager
  alias ExSmsBliss.Config

  setup_all do
    TeslaMockJson.prepare_global()
    :ok
  end

  setup [:manager]

  setup context do
    msgs = gen_messages(context)

    on_exit fn -> 
      Process.sleep(200)
      # Manager.clean() 
    end

    {:ok, msgs: msgs}
  end

  describe "get_queue" do
    test "should return empty list initially" do
      assert Manager.get_queue == []
    end
  end

  describe "queue/1" do

    @tag amount: 1, sender: "SKB", schedule_at: DateTime.utc_now
    test "must return {:ok, client_id} on a message and put it to DB", %{msgs: [msg]} do
      assert {:ok, id} = Manager.queue(msg)

      assert [new_msg] = Manager.get_queue()

      assert new_msg.client_id == id
      assert new_msg.state == :queued
      assert new_msg.phone == msg.phone
      assert new_msg.text == msg.text
      assert new_msg.sender == msg.sender
      assert DateTime.diff(new_msg.schedule_at, msg.schedule_at) == 0

    end

    @tag amount: 100, sender: "SKB100" #, schedule_at: DateTime.utc_now
    test "must queue more than one message without probs", %{msgs: msgs} do
      for msg <- msgs do
        assert {:ok, _} = Manager.queue(msg)
      end

      assert 100 == Manager.count_queue()
    end

  end

  describe "sending" do

    setup [:queue_msgs]

    @tag amount: 1, sender: "SKB", schedule_at: DateTime.utc_now
    test "after sending state, status and smsc_id only must be changed", %{msgs: [msg]} do
      Manager.clean()
      assert {:ok, id} = Manager.queue(msg)

      Process.sleep(200)
      assert [new_msg] = Manager.get_queue()

      assert new_msg.client_id == id
      assert new_msg.state == :sent
      assert new_msg.phone == msg.phone
      assert new_msg.text == msg.text
      assert new_msg.sender == msg.sender
      assert new_msg.smsc_id
      assert DateTime.diff(new_msg.schedule_at, msg.schedule_at) == 0

    end

    @tag amount: 10, sender: "SKB10"
    test "every X timeunits it must change all :queued messages to :sending", %{amount: amount} do

      assert amount == Manager.count_queue(:queued)
      assert 0 == Manager.count_queue(:sending)

      for i <- 1..2 do
        Process.sleep(40)
        msgs = gen_messages(%{amount: amount})
        Enum.each(msgs, &(Manager.queue(&1)))

        assert amount == Manager.count_queue(:queued)
        assert amount * i == Manager.count_queue(:sending)
      end

      Process.sleep(200)
    end

    @tag amount: 500, sender: "SKB1"
    test "it must send queued messages, change their state to :sent and write back received status", %{amount: amount} do
      assert queue = Manager.get_queue()
      assert length(queue) == amount
      Enum.each(queue, fn msg ->
        refute msg.smsc_id
        refute msg.status
        refute msg.state == :sent
      end)
      Process.sleep(250)
      

      assert queue = Manager.get_queue()
      assert length(queue) == amount
      Enum.each(queue, fn msg ->
        assert msg.smsc_id
        assert msg.status == "accepted"
        assert msg.state == :sent
      end)

    end

  end

  describe "push" do
    setup [:save_restore_globals, :queue_msgs]

    @tag amount: 1, sender: "SKB1"
    test "it must push changes back if :push == true", %{qids: [id]} do
      Application.put_env(:ex_smsbliss, :push, true)

      refute_receive {:ex_smsbliss, _id, _new_state, _additional_changes_map}, 1
      Process.sleep(40)
      assert_receive {:ex_smsbliss, ^id, :sending, %{}}, 20
      Process.sleep(120)
      assert_receive {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, 20
    end

  end

  describe "work with balance" do
    
  end

  describe "work with status" do
    
  end

  describe "check performace" do
    setup [:save_restore_globals, :queue_msgs]
    
    # setup do
    #   on_exit fn -> Process.sleep(1000) end
    # end

    # @tag amount: 50000, timeout: 120_000
    # test "try to send many messages", %{amount: amount} do
    #   refute_received {:ex_smsbliss, _, :sending, _}
    #   assert Manager.count_queue() == amount

    #   assert_receive {:ex_smsbliss, _, :sending, _}, 10000
    #   assert Manager.count_queue() == amount

    #   refute_receive {:ex_smsbliss, _, :sent, _}, 20000

    #   assert Manager.count_queue() == amount
    # end

  end

  describe "check for race" do
    setup [:save_restore_globals, :fake_sms, :queue_msgs]

    @tag amount: 5_000, timeout: 120_000, poll_interval: 500
    test "check queue length", %{amount: amount} do
      assert Manager.count_queue() == amount
      Process.sleep(600)
      assert Manager.count_queue() == amount
    end

  end

  defp manager(context) do
    poll_interval = Map.get(context, :poll_interval, 30)
    {:ok, pid} = Manager.start_link(poll_interval: poll_interval)

    on_exit fn -> Process.sleep(200) end

    [manager_pid: pid]
  end

  defp queue_msgs(%{msgs: msgs}) do
    [qids:  Enum.map(msgs, fn msg -> 
              {:ok, id} = Manager.queue(msg) 
              id
            end)]
  end

  defp fake_sms(_) do
    Application.put_env(:ex_smsbliss, :sms_adapter, FakeSmsAdapter)
  end

  defp save_restore_globals(_) do
    globals = Application.get_all_env(:ex_smsbliss)
    on_exit fn ->
      globals
      |>  Enum.each(fn {k, v} -> 
            Application.put_env(:ex_smsbliss, k, v)
          end)
    end
  end  

end

defmodule FakeSmsAdapter do
  def send(_, _) do
    Process.sleep(100)
    {:ok, %{"messages" => []}}
  end
end