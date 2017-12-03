defmodule ExSmsBliss.JsonTest do
  use ExUnit.Case
  doctest ExSmsBliss.Json

  alias ExSmsBliss.Config
  alias ExSmsBliss.Json
  # alias ExSmsBliss.TeslaMockJson

  import ExSmsBliss.MessagesTestHelper
  
  setup do
    Tesla.Mock.mock fn env ->
      case {env.method, env.url, env.body} do

        {:post, "https://api.smsbliss.net/messages/v2/send.json", body} ->

          %Tesla.Env{status: 200, body: ~s({"orig":#{body}})}
          |> Tesla.Middleware.Headers.call([], %{"content-type" => "application/json"})

      end
    end

    :ok
  end

  describe "/send" do

    setup context do
      msgs = 
        case Map.get(context, :msgs_type) do
          :id -> messages(10, client_id: true)
          :sender -> messages(10, client_id: false, sender: "SKB")
          :id_sender -> messages(10, client_id: true, sender: "SKB")
          _ -> messages(10, client_id: false)
        end

      {:ok, msgs: msgs}
    end

    test "it must has login/password fields", %{msgs: msgs} do
      assert {:ok, reply} = Json.send(msgs)

      assert %{"orig" => request} = reply
      assert Map.get(request, "login")
      assert Map.get(request, "password")
    end

    test "it must request billing details if config option :request_billing_on_send is true", %{msgs: msgs} do
      current_state = Config.get(:request_billing_on_send)

      Application.put_env(:ex_smsbliss, :request_billing_on_send, true)
      assert {:ok, reply} = Json.send(msgs)
      Application.put_env(:ex_smsbliss, :request_billing_on_send, current_state)

      assert %{"orig" => request} = reply
      assert true == Map.get(request, "showBillingDetails")
      
    end

    test "it must NOT request billing details if config option :request_billing_on_send is false", %{msgs: msgs} do
      current_state = Config.get(:request_billing_on_send)

      Application.put_env(:ex_smsbliss, :request_billing_on_send, false)
      assert {:ok, reply} = Json.send(msgs)
      Application.put_env(:ex_smsbliss, :request_billing_on_send, current_state)

      assert %{"orig" => request} = reply
      refute Map.get(request, "showBillingDetails")
      
    end

    test "it must request billing details if config option :request_billing_on_send is false but true in opts", %{msgs: msgs} do
      current_state = Config.get(:request_billing_on_send)

      Application.put_env(:ex_smsbliss, :request_billing_on_send, false)
      assert {:ok, reply} = Json.send(msgs, request_billing: true)
      Application.put_env(:ex_smsbliss, :request_billing_on_send, current_state)

      assert %{"orig" => request} = reply
      assert true == Map.get(request, "showBillingDetails")
      
    end

    test "it must NOT request billing details if config option :request_billing_on_send is true but false in opts", %{msgs: msgs} do
      current_state = Config.get(:request_billing_on_send)

      Application.put_env(:ex_smsbliss, :request_billing_on_send, true)
      assert {:ok, reply} = Json.send(msgs, request_billing: false)
      Application.put_env(:ex_smsbliss, :request_billing_on_send, current_state)

      assert %{"orig" => request} = reply
      refute Map.get(request, "showBillingDetails")
      
    end

    # test "it must set schedule time if its in the second parameter", %{msgs: msgs} do
      
    # end

  end
end