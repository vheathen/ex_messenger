defmodule ExSmsBlissTest.ManagerTest do
  use ExSmsBliss.DataCase
  import ExSmsBliss.ApiTestHelper

  alias ExSmsBlissTest.Manager

  setup context do
    msgs = gen_messages(context)

    {:ok, msgs: msgs}
  end

  describe "queue/1" do

    @tag amount: 1, sender: "SKB", schedule_at: DateTime.utc_now
    test "must return {:ok, client_id} on a message and put it to DB", %{msgs: [msg]} do
      assert {:ok, qm} = Manager.queue(msg)

      assert [qm_ret] = Manager.get_queue()

      assert qm_ret == qm
    end
    
    # @tag num: 12, opts: [sender: "SKB", schedule_at: DateTime.utc_now]
    # test "must return {:ok, [client_id0, client_id1, ...]} on a message list and put messages to DB", %{msgs: msgs} do
    #   assert {:ok, qms} = Manager.queue(msgs)

    #   qms = Map.values(qms)

    #   assert qms_ret = Manager.get_queue()
    #   assert length(qms) == (qms_ret |> length())

    #   for i <- 0..length(Map.keys(qms))-1 do
    #     assert Enum.at(qms, i) == Enum.at(qms_ret, i)
    #   end

    # end


  end

  describe "get_queue" do
    test "should return empty list initially" do
      assert Manager.get_queue == []
    end
  end
  
end