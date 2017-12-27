defmodule FakeSms do
  def reply_send(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "accepted",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => (:rand.uniform(10000000) + 100000000)
          }
        end)  
  end
  def reply_status(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "delivered",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => Map.get(msg, :smsc_id)
          }
        end)  
  end

  def send(msgs, _ \\ []) do
    {:ok, %{"messages" => reply_send(msgs)}}
  end
  def status(msgs, _opts \\ []) do
    {:ok, %{"messages" => reply_status(msgs)}}
  end
end

defmodule FakeSmsSendNoReply do
  def reply_send(_) do
    []    
  end
  defp reply_status(_) do
    []
  end
  
  def send(msgs, _) do
    {:ok, %{"messages" => reply_send(msgs)}}
  end
  def status(msgs, _opts \\ []) do
    {:ok, %{"messages" => reply_status(msgs)}}
  end
end

defmodule FakeSmsRejected do
  def reply_send(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "invalid mobile phone",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => (:rand.uniform(10000000) + 100000000)
          }
        end)  
  end
  def reply_status(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "delivery error",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => Map.get(msg, :smsc_id)
          }
        end)  
  end

  def send(msgs, _ \\ []) do
    {:ok, %{"messages" => reply_send(msgs)}}
  end
  def status(msgs, _opts \\ []) do
    {:ok, %{"messages" => reply_status(msgs)}}
  end
end

defmodule FakeSmsStatus50x50 do
  def reply_send(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "accepted",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => (:rand.uniform(10000000) + 100000000)
          }
        end)  
  end

  def reply_status(msgs) do
    st = ["delivered", "delivery error"]

    msgs
    |> Enum.with_index
    |>  Enum.map(fn {msg, i} -> 
          %{
            "status" => Enum.at(st, rem(i, 2)),
            "clientId" => Map.get(msg, :client_id),
            "smscId" => Map.get(msg, :smsc_id)
          }
        end)  
  end

  def send(msgs, _ \\ []) do
    {:ok, %{"messages" => reply_send(msgs)}}
  end
  def status(msgs, _opts \\ []) do
    {:ok, %{"messages" => reply_status(msgs)}}
  end
end

defmodule FakeSmsStatusFailed do
  def reply_send(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "accepted",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => (:rand.uniform(10000000) + 100000000)
          }
        end)  
  end

  def reply_status(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          %{
            "status" => "delivery error",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => Map.get(msg, :smsc_id)
          }
        end)  
  end

  def send(msgs, _ \\ []) do
    {:ok, %{"messages" => reply_send(msgs)}}
  end
  def status(msgs, _opts \\ []) do
    {:ok, %{"messages" => reply_status(msgs)}}
  end
end


defmodule FakeSmsError do
  def send(_, _ \\ []) do
    {:error, "any send description you can imagine"}
  end
  def status(_, _opts \\ []) do
    {:error, "any status description you can imagine"}
  end
end

defmodule FakeSmsGlobalError do
  def send(_, _ \\ []) do
    {:ok, ~S({"status": "error", "description": "error authorization"})}
  end
  def status(_, _opts \\ []) do
    {:ok, ~S({"status": "error", "description": "error authorization"})}
  end
end

defmodule FakeSmsStatusQueued do
  use GenServer

  def reply_send(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          GenServer.cast(__MODULE__, {:send, Map.get(msg, :client_id)})
          %{
            "status" => "accepted",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => (:rand.uniform(10000000) + 100000000)
          }
        end)  
  end
  def reply_status(msgs) do
    msgs
    |>  Enum.map(fn msg -> 
          GenServer.cast(__MODULE__, {:status, Map.get(msg, :client_id)})
          %{
            "status" => "queued",
            "clientId" => Map.get(msg, :client_id),
            "smscId" => Map.get(msg, :smsc_id)
          }
        end)  
  end

  def send(msgs, _ \\ []) do
    {:ok, %{"messages" => reply_send(msgs)}}
  end
  def status(msgs, _opts \\ []) do
    {:ok, %{"messages" => reply_status(msgs)}}
  end

  # GenServer server part
  def start_link(pid) when is_pid(pid) do
    GenServer.start_link(__MODULE__, pid, name: __MODULE__)
  end

  def init(pid) when is_pid(pid) do
    {:ok, pid}
  end

  def handle_cast({:send, id}, pid) do
    Process.send(pid, {:send, id}, [])

    {:noreply, pid}
  end

  def handle_cast({:status, id}, pid) do
    Process.send(pid, {:status, id}, [])

    {:noreply, pid}
  end

end
