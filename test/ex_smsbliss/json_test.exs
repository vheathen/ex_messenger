defmodule ExSmsBliss.JsonTest do
  use ExUnit.Case
  doctest ExSmsBliss.Json

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
      assert %{"orig" => request} = Json.send(msgs)
      assert Map.get(request, "login")
      assert Map.get(request, "password")
    end

  end
end