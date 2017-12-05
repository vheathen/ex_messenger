defmodule ExSmsBliss.TeslaMockJson do

@statuses  ["accepted",
            "invalid mobile phone",
            "text is empty",
            "sender address invalid",
            "wapurl invalid",
            "invalid schedule time format",
            "invalid status queue name",
            "not enough balance"]

  def prepare do
    Tesla.Mock.mock fn env ->
      case {env.method, env.url, env.body} do

        {:post, "https://api.smsbliss.net/messages/v2/send.json", body} ->

          %Tesla.Env{status: 200, body: reply_to_send(Poison.decode!(body))}
          |> Tesla.Middleware.Headers.call([], %{"content-type" => "application/json"})

        {:post, "https://api.smsbliss.net/messages/v2/status.json", body} ->

          %Tesla.Env{status: 200, body: reply_to_status(Poison.decode!(body))}
          |> Tesla.Middleware.Headers.call([], %{"content-type" => "application/json"})

      end
    end
  end

  def reply_to_send(body) do
    %{}
    |> Map.put(:orig, body)
    |> Map.put(:messages, answer_the_messages(body["messages"]))
    |> Map.put(:status, "ok")
    |> Map.put(:balance, [%{credit: 0, balance: 15155.37, type: "RUB"}])
    |> Poison.encode!()
  end

  def answer_the_messages(messages) do
    messages
    |> Enum.map(&answer_the_message(&1))
  end

  def answer_the_message(%{"clientId" => clientId} = message) do
    message
    |> Map.delete("clientId")
    |> answer_the_message()
    |> Map.put(:clientId, clientId)
  end
  def answer_the_message(%{"text" => text}) do
    count = text |> byte_size() |> div(140) |> Kernel.+(1)
    cost = 1.64 * count

    %{
      status: "accepted",
      smscId: :rand.uniform(100000000),
      smsCount: count,
      msgCost: cost
    }
  end

  def reply_to_status(body) do
    %{}
    |> Map.put(:orig, body)
    |> Map.put(:messages, status_of_the_messages(body["messages"]))    
    |> Map.put(:status, "ok")
    |> Poison.encode!()
  end

  def status_of_the_messages(messages) when is_list(messages) do
    messages
    |> Enum.map(&status_of_the_message(&1))    
  end
  def status_of_the_messages(_), do: []
  

  def status_of_the_message(%{"clientId" => clientId} = message) do
    message
    |> Map.delete("clientId")
    |> status_of_the_message()
    |> Map.put(:clientId, clientId)
  end
  def status_of_the_message(%{"smscId" => smscId}) do
    %{
      "status" => Enum.random(@statuses),
      "smscId" => smscId
    }
  end

  # defp send_reply do
  #   """
  #   {
  #       "status": "ok",
  #       "balance": [
  #           {
  #               "credit": 0,
  #               "balance": 15155.37,
  #               "type": "RUB"
  #           }
  #       ],
  #       "messages": [
  #           {
  #               "status": "accepted",
  #               "smscId": 2592608030,
  #               "smsCount": 1,
  #               "clientId": "4bf13f4b-ffaa-44bb-90c1-6ed26f047dba",
  #               "msgCost": 1.64
  #           }
  #       ]
  #   }
  #   """
  # end
end
