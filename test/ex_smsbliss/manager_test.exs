defmodule ExSmsBlissTest.ManagerTest do
  use ExUnit.Case, async: false

  import ExSmsBliss.ApiTestHelper
  alias ExSmsBliss.TeslaMockJson

  alias ExSmsBliss.Manager

  @poll 50
  @check 100
  @clean 100

  setup_all do
    TeslaMockJson.prepare_global()
    :ok
  end

  setup [:save_restore_globals, :fake_sms, :sleep, :manager, :generate_msgs]

  describe "get_queue" do
    test "should return empty list initially" do
      assert Manager.get_queue == []
    end
  end

  describe "queue/1" do

    @tag amount: 1, sender: "SKB", schedule_at: DateTime.utc_now, sms_adapter: FakeSmsSendNoReply
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

    @tag amount: 20, sender: "SKB100" #, schedule_at: DateTime.utc_now
    test "must queue more than one message without probs", %{msgs: msgs, amount: amount} do
      for msg <- msgs do
        assert {:ok, _} = Manager.queue(msg)
      end

      assert amount == Manager.count_queue(:queued)
    end

  end

  describe "sending:" do

    setup [:fake_sms, :queue_msgs]

    @tag amount: 1, sender: "SKB", schedule_at: DateTime.utc_now
    test "after sending state, status and smsc_id only must be changed", %{msgs: [msg], qids: [id]} do
      Process.sleep(95)
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
    test "every X timeunits it must change all :queued messages to :sending", %{amount: amount, msgs: msgs, qids: ids} do

      assert amount == Manager.count_queue(:queued)
      assert 0 == Manager.count_queue(:sending)

      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :sending, _}, round(@poll * 1.3)
      end
      
      Enum.each(msgs, &(Manager.queue(&1)))
      
      for _ <- 1..amount do
        assert_receive {:ex_smsbliss, _, :sending, _}, round(@poll * 1.3)
        assert_received {:ex_smsbliss, _, :sent, _}        
      end
    end

    @tag amount: 50, sender: "SKB1"
    test "it must send queued messages, change their state to :sent and write back received status", %{amount: amount} do
      assert queue = Manager.get_queue()
      assert length(queue) == amount
      Enum.each(queue, fn msg ->
        refute msg.smsc_id
        refute msg.status
        refute msg.state == :sent
      end)
      Process.sleep(round(@poll * 1.2))

      assert queue = Manager.get_queue()
      assert length(queue) == amount
      Enum.each(queue, fn msg ->
        assert msg.smsc_id
        assert msg.status == "accepted"
        assert msg.state == :sent
      end)

    end

  end

  describe "push:" do
    setup [:fake_sms, :queue_msgs] # :push

    @tag amount: 1, sender: "SKB1"
    test "it must push changes back if :push == true", %{qids: [id]} do      
      refute_receive {:ex_smsbliss, _id, _new_state, _additional_changes_map}, 1
      assert_receive {:ex_smsbliss, ^id, :sending, %{}}, 80
      assert_receive {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, 150
    end

    @tag amount: 10, sms_adapter: FakeSmsRejected
    test "on rejected messages notification must have appropriate status", %{qids: ids} do
      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :rejected, %{smsc_id: _, status: _}}, @poll * 4
      end

      assert 0 == Manager.count_queue()
    end

    test "it must remove finished messages after notification sent", %{qids: ids} do
      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :sending, _}, @poll + 5
        assert_receive {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, round(@check * 1.2)
      end

      Process.sleep(500)
      assert 0 == Manager.count_queue()
      assert 0 == Manager.count_queue(:queued)
      assert 0 == Manager.count_queue(:sending)
      assert 0 == Manager.count_queue(:sent)
      assert 0 == Manager.count_queue(:rejected)
      assert 0 == Manager.count_queue(:finished)
      assert 0 == Manager.count_queue(:failed)
    end
  end

  describe "work with balance" do
    
  end

  describe "work with status:" do
    setup [:queue_msgs]
    
    @tag amount: 20
    test "every Y timeunits it must check if there are sent messages available and request their status", %{qids: qids} do
      for id <- qids do
        assert_receive {:ex_smsbliss, ^id, :sending, _}, round(@poll * 1.2)
        assert_receive {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, @poll * 2
        assert_receive {:ex_smsbliss, ^id, :finished, %{smsc_id: _, status: "delivered"}}, @check * 2
      end

      assert 0 == Manager.count_queue()
    end

    # , sms_adapter: FakeSmsStatus50x50
    @tag amount: 15, sms_adapter: FakeSmsStatusFailed
    test "must deal with failed statuses", %{qids: ids} do
      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :sending, _}, round(@poll * 1.2)
        assert_receive {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, @poll * 2
        assert_receive {:ex_smsbliss, ^id, :failed, %{smsc_id: _, status: "delivery error"}}, @check * 2
      end

      assert 0 == Manager.count_queue()
    end

    @tag amount: 1, sms_adapter: FakeSmsStatusQueued
    test "finished: it must continue to request statuses if messages are not delivered yet", %{qids: ids} do
      Process.sleep(@check * 4)
      
      for id <- ids do
        assert_received {:ex_smsbliss, ^id, :sending, _}, round(@poll * 1.2)
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, round(@poll * 1.2)
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "queued"}}
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "queued"}}
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "queued"}}
        refute_received {:ex_smsbliss, ^id, :finished, %{smsc_id: _, status: "delivered"}}
        refute_received {:ex_smsbliss, ^id, :failed, %{smsc_id: _, status: _}}
      end

      fake_sms(%{sms_adapter: FakeSms})
      
      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :finished, %{smsc_id: _, status: "delivered"}}, @check * 2
      end

      assert 0 == Manager.count_queue()
    end

    @tag amount: 1, sms_adapter: FakeSmsStatusQueued
    test "failed: it must continue to request statuses if messages are not delivered yet", %{qids: ids} do
      Process.sleep(@check * 4)
      
      for id <- ids do
        assert_received {:ex_smsbliss, ^id, :sending, _}, round(@poll * 1.2)
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "accepted"}}, round(@poll * 1.2)
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "queued"}}
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "queued"}}
        assert_received {:ex_smsbliss, ^id, :sent, %{smsc_id: _, status: "queued"}}
        refute_received {:ex_smsbliss, ^id, :finished, %{smsc_id: _, status: "delivered"}}
        refute_received {:ex_smsbliss, ^id, :failed, %{smsc_id: _, status: _}}
      end

      fake_sms(%{sms_adapter: FakeSmsStatusFailed})
      
      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :failed, %{smsc_id: _, status: _}}, @check * 2
      end

      assert 0 == Manager.count_queue()
    end

  end

  describe "send error:" do
    setup [:queue_msgs]
    
    @tag amount: 10, sms_adapter: FakeSmsError
    test "must deal with send error", %{qids: ids} do
      for id <- ids do
        assert_receive {:ex_smsbliss, ^id, :sending, _}, round(@poll * 1.2)
        assert_receive {:ex_smsbliss, ^id, :error, _}, @poll * 2
      end

      assert 0 == Manager.count_queue()
    end

  end

  describe "expire messages:" do
    # setup 
  end

  # TODO: Return to this after important parts
  # It's better to use Stream
  describe "check performace" do
    # setup [:save_restore_globals, :queue_msgs]
    
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

  defp manager(context) do
    poll_interval = Map.get(context, :poll_interval, @poll)
    status_check_interval = Map.get(context, :status_check_interval, @clean)
    cleanup_interval = Map.get(context, :cleanup_interval, @check)
    max_age = Map.get(context, :max_age, 120)

    {:ok, pid} = Manager.start_link(poll_interval: poll_interval, 
                                    status_check_interval: status_check_interval,
                                    cleanup_interval: cleanup_interval,
                                    max_age: max_age)

    on_exit fn -> Process.sleep(200) end

    [manager_pid: pid]
  end

  defp generate_msgs(context) do
    [msgs: gen_messages(context)]
  end

  defp sleep(context) do
    # on_exit fn -> Process.sleep(200) end
    context
  end

  defp push(context) do
    Application.put_env(:ex_smsbliss, :push, true)
    context
  end

  defp queue_msgs(%{msgs: msgs}) do
    [qids:  Enum.map(msgs, fn msg -> 
              {:ok, id} = Manager.queue(msg)
              id
            end)]
  end

  defp fake_sms(context) do
    sms_adapter = Map.get(context, :sms_adapter) || FakeSms
    Application.put_env(:ex_smsbliss, :sms_adapter, sms_adapter)
    context
  end

  defp save_restore_globals(context) do
    globals = Application.get_all_env(:ex_smsbliss)
    on_exit fn ->
      globals
      |>  Enum.each(fn {k, v} -> 
            Application.put_env(:ex_smsbliss, k, v)
          end)
    end

    context
  end  

end