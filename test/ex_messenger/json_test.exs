defmodule ExMessenger.JsonTest do
  use ExUnit.Case, async: false
  doctest ExMessenger.Json

  alias ExMessenger.Config
  alias ExMessenger.Json
  alias ExMessenger.TeslaMockJson

  import ExMessenger.ApiTestHelper
  
  setup do
    TeslaMockJson.prepare()

    :ok
  end

  describe "/send" do

    setup context do

      msgs = gen_messages(context)

      {:ok, msgs: msgs}
    end

    test "it must be able to send a list of messages", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs)
      assert %{"orig" => request} = reply

      assert Map.has_key?(request, "messages")
      assert msgs |> Enum.count() == Map.get(request, "messages") |> Enum.count()
    end

    test "it must be able to send a message" do
      msg = gen_message()

      assert {:ok, reply} = Json.send(msg)
      assert %{"orig" => request} = reply

      assert Map.has_key?(request, "messages")
      assert 1 == Map.get(request, "messages") |> Enum.count()
    end

    test "it must return :error is ones trying to send an empty list as a message list" do
      assert {:error, _} = Json.send([])
    end

    @tag amount: 201
    test "it must return :error is ones trying to send more than 200 messages at a time", %{msgs: msgs} do
      assert 201 == Enum.count(msgs)

      assert {:error, _} = Json.send(msgs)      
    end

    test "it must put correct login/password if it is opts", %{msgs: msgs} do
      login = "OptedLoginAgain"
      password = "OptedPasswordAgain"

      assert {:ok, reply} = Json.send(msgs, login: login, password: password)
      assert %{"orig" => request} = reply

      assert login == Map.get(request, "login")
      assert password == Map.get(request, "password")      
    end

    test "it must check a message to have :text field" do
      msg = %{phone: "79121234567"}

      assert {:error, _} = Json.send(msg)      
    end

    test "it must check a message to have :text field as a non-emtpy string" do
      msg = %{phone: "79121234567", text: ""}
      
      assert {:error, _} = Json.send(msg)      
    end

    test "it must check a message to have :phone field" do
      msg = %{text: "something"}
      
      assert {:error, _} = Json.send(msg)      
    end

    test "it must check a message to have :phone field as an integer or a string in a proper international format (E.164)" do
      msg = %{phone: "791212345678", text: "text"}      
      assert {:error, _} = Json.send(msg)

      msg = %{phone: 791212345678, text: "text"}      
      assert {:error, _} = Json.send(msg)

      msg = %{phone: "abc1928345", text: "text"}      
      assert {:error, _} = Json.send(msg)

      msg = %{phone: "79121234567", text: "text"}
      assert {:ok, _} = Json.send(msg)

      msg = %{phone: 79121234567, text: "text"}
      assert {:ok, _} = Json.send(msg)
    end

    @tag :client_id
    test "it must put client_id to the result message", %{msgs: msgs} do

      assert {:ok, reply} = Json.send(msgs)
      assert %{"orig" => %{"messages" => messages}} = reply

      messages
      |> Enum.each(&(assert byte_size(Map.get(&1, "clientId")) > 0))
    end

    test "it must a messages :client_id to be a non-empty string no more than 72 characters long" do
      client_id = ""
      msg = %{phone: "79121234567", text: "text", client_id: client_id}
      assert {:error, _} = Json.send(msg)

      client_id = String.duplicate("12567", 20)
      msg = %{phone: "79121234567", text: "text", client_id: client_id}
      assert {:error, _} = Json.send(msg)
    end

    test "it must check messages list to NOT have more than one message with the same :client_id", %{msgs: msgs} do
      msgs = msgs |> Enum.map(&Map.put(&1, :client_id, "the_same_value"))

      assert {:error, _} = Json.send(msgs)
    end

    test "it must has login/password fields", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs)

      assert %{"orig" => request} = reply
      assert Map.get(request, "login")
      assert Map.get(request, "password")
    end

    test "it must NOT set schedule time by default", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs)
      assert %{"orig" => request} = reply
      refute Map.has_key?(request, "scheduleTime")
    end

    test "it must set schedule time if it is in opts", %{msgs: msgs} do
      dt_str = DateTime.utc_now |> DateTime.to_iso8601 |> String.replace(~r/\.\d+Z/, "Z")

      assert {:ok, reply} = Json.send(msgs, schedule_at: dt_str)
      assert %{"orig" => request} = reply
      assert dt_str == Map.get(request, "scheduleTime")
    end

    test "it must set schedule time and properly format it if it is in opts", %{msgs: msgs} do
      dt_str_req = DateTime.utc_now() |> DateTime.to_iso8601()
      dt_str = dt_str_req |> String.replace(~r/\.\d+Z/, "Z")

      assert {:ok, reply} = Json.send(msgs, schedule_at: dt_str_req)
      assert %{"orig" => request} = reply
      assert dt_str == Map.get(request, "scheduleTime")
    end

    test "it must return {:error, description} if schedule_at is in the wrong format", %{msgs: msgs} do
      dt_str = "2017-12-03 13:07:08.442228"
      assert {:error, _} = Json.send(msgs, schedule_at: dt_str)

      dt_str = nil
      assert {:error, _} = Json.send(msgs, schedule_at: dt_str)
    end

    test "it must add sender to every message if :sender is set in opts", %{msgs: msgs} do
      sender = "NEW_SENDER"

      assert {:ok, reply} = Json.send(msgs, sender: sender)
      assert %{"orig" => request} = reply

      request
      |> Map.get("messages")
      |> Enum.each(&(assert sender == Map.get(&1, "sender")))
    end

    test "it must check :sender is a non-empty string" do
      sender = ""
      msg = %{phone: "79121234567", text: "some", sender: sender}
      assert {:error, _} = Json.send(msg)

      msg = %{phone: "79121234567", text: "some"}
      assert {:error, _} = Json.send(msg, sender: sender)
    end

    @tag sender: "SKB"
    test "it must not replace message's :sender with an opts's value", %{msgs: msgs} do
      sender = "ANOTHER_ONE_SENDER"

      assert {:ok, reply} = Json.send(msgs, sender: sender)
      assert %{"orig" => %{"messages" => messages}} = reply

      messages
      |> Enum.each(&(refute sender == Map.get(&1, "sender")))

    end

    test "it must set :queue_name if there is such option on opts", %{msgs: msgs} do
      queue_name = "NormalName"
      assert {:ok, reply} = Json.send(msgs, queue_name: queue_name)
      assert %{"orig" => request} = reply

      assert queue_name == Map.get(request, "statusQueueName")
    end

  end

  describe ":request_billing_on_send" do
    setup %{req_bill?: req_bill} = context do
      current_state = Config.get(ExMessenger.Json)
      on_exit fn ->
        Application.put_env(:ex_messenger, ExMessenger.Json, current_state)
      end    

      opts = Keyword.put(current_state, :request_billing_on_send, req_bill)
      Application.put_env(:ex_messenger, ExMessenger.Json, opts)


      msgs = gen_messages(context)      
      {:ok, msgs: msgs}
    end

    @tag req_bill?: true
    test "it must request billing details if config option :request_billing_on_send is true", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs)

      assert %{"orig" => request} = reply
      assert true == Map.get(request, "showBillingDetails")      
    end

    @tag req_bill?: false
    test "it must NOT request billing details if config option :request_billing_on_send is false", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs)

      assert %{"orig" => request} = reply
      refute Map.get(request, "showBillingDetails")      
    end

    @tag req_bill?: false
    test "it must request billing details if config option :request_billing_on_send is false but true in opts", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs, request_billing: true)

      assert %{"orig" => request} = reply
      assert true == Map.get(request, "showBillingDetails")      
    end

    @tag req_bill?: true
    test "it must NOT request billing details if config option :request_billing_on_send is true but false in opts", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs, request_billing: false)

      assert %{"orig" => request} = reply
      refute Map.get(request, "showBillingDetails")      
    end
  end

  describe "/status" do
    setup context do
      msgs = gen_message_statuses(context)

      {:ok, msgs: msgs}
    end

    test "it must be able to request a list of messages status", %{msgs: msgs} do
      assert {:ok, reply} = Json.status(msgs)
      assert %{"orig" => _} = reply
    end

    test "it must be able to request a message status" do
      msg = gen_message_status()

      assert {:ok, reply} = Json.status(msg)
      assert %{"orig" => request} = reply

      assert Map.has_key?(request, "messages")
      assert 1 == Map.get(request, "messages") |> Enum.count()
    end

    test "it must return :error is ones trying to request a status an empty list" do
      assert {:error, _} = Json.status([])
    end

    @tag amount: 201
    test "it must return :error is ones trying to request a status of more than 200 messages at a time", %{msgs: msgs} do
      assert 201 == Enum.count(msgs)

      assert {:error, _} = Json.status(msgs)      
    end

    test "it must put correct login/password if it is opts", %{msgs: msgs} do
      login = "OptedLoginAgain"
      password = "OptedPasswordAgain"

      assert {:ok, reply} = Json.status(msgs, login: login, password: password)
      assert %{"orig" => request} = reply

      assert login == Map.get(request, "login")
      assert password == Map.get(request, "password")      
    end

    test "it must check a status request to have :smsc_id field" do
      msg = %{}
      assert {:error, _} = Json.status(msg)
    end

    test "it must check a request status to have :smsc_id field as a non-emtpy string or an integer" do
      msg = %{smsc_id: ""}      
      assert {:error, _} = Json.status(msg)

      msg = %{smsc_id: 123456}
      assert {:ok, _} = Json.status(msg)
    end

    test "it must send a status request with :smscId field", %{msgs: msgs} do
      assert {:ok, reply} = Json.status(msgs)
      assert %{"orig" => %{"messages" => statuses}} = reply

      statuses
      |> Enum.each(&(assert Map.get(&1, "smscId")))
    end

    @tag :client_id
    test "it must put client_id to the result message", %{msgs: msgs} do

      assert {:ok, reply} = Json.status(msgs)
      assert %{"orig" => %{"messages" => messages}} = reply

      messages
      |> Enum.each(&(assert byte_size(Map.get(&1, "clientId")) > 0))
    end

    test "it must check a messages :client_id to be a non-empty string no more than 72 characters long" do
      client_id = ""
      msg = %{smsc_id: "79121234567", client_id: client_id}
      assert {:error, _} = Json.status(msg)

      client_id = String.duplicate("12567", 20)
      msg = %{smsc_id: "79121234567", client_id: client_id}
      assert {:error, _} = Json.status(msg)
    end

    test "it must check messages list to NOT have more than one message with the same :client_id", %{msgs: msgs} do
      msgs = msgs |> Enum.map(&Map.put(&1, :client_id, "the_same_value"))

      assert {:error, _} = Json.status(msgs)
    end

  end

end