defmodule ExSmsBliss.Manager do
  @moduledoc false
  use GenServer

  require Logger
  
  alias ExSmsBliss.Config
  alias ExSmsBliss.Storage.Ets
  
  @doc """
  Returns queue: a message list # TODO: with a given status and higher
  """
  def get_queue(state \\ :all) do
    Ets.get_by_state(state, __MODULE__)
  end

  def queue(%{} = message) do
    Ets.add(Map.put(message, :subscriber, self()), __MODULE__)
  end

  def clean do
    Ets.cleanup(0, __MODULE__)
  end

  def notify(id, subscriber, state, changes) when is_pid(subscriber) do
    if Config.get(:push) do
      Process.send(subscriber, {:ex_smsbliss, id, state, changes}, [])
    end

    :ok
  end
  def notify(_id, _subscriber, _state, _changes), do: :ok

  ####################
  # GenServer staff

  @doc """
  Starts the storage table and all supporting processes
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def init(opts \\ []) do
    
    state = %{poll_interval: 
                Keyword.get(opts, :poll_interval) || Config.get(:poll_interval)}

    {:ok, _} = Ets.storage_init(__MODULE__)

    schedule_sending(state)

    {:ok, state}
  end

  def handle_info(:send, state) do
    spawn fn ->
      __MODULE__
      |> Ets.prepare_send_queue()
      |> prepare_bundles()
      |> send_bundles()

      schedule_sending(state)
    end

    {:noreply, state}
  end

  ##
  # Private part
  ##

  # TODO: Move to sms adapter ?
  defp prepare_bundles(queue) when is_list(queue) do
    queue
    |>  Enum.reduce(%{}, fn msg, bundles -> 
          schedule_at = Map.get(msg, :schedule_at) || :none
          Map.update(bundles, schedule_at, [msg], &(&1 ++ [msg]))
        end)
    |>  Enum.reduce(%{}, fn {k, bundle}, bundles ->
          Map.put(bundles, k, Enum.chunk_every(bundle, 200))
        end)
  end

  # TODO: Move to sms adapter ?
  defp send_bundles(%{} = bundles) do
    
    Enum.each(bundles, fn {schedule_at, bundle_sets} -> 
          Enum.each(bundle_sets, fn bundle ->
            send_bundle(schedule_at, bundle)
          end)
    end)
  end

  defp send_bundle(schedule_at, bundle) do
    spawn fn -> 
      
      with \
        {:ok, %{"messages" => messages}} <- sms().send(bundle, prepare_send_opts(schedule_at))
      do
        # IO.inspect "Msgs: #{inspect messages}"
        Enum.each(messages, &(update_message(&1)))
      else
        error ->
          raise ArgumentError, error
      end
      
    end
  end

  defp prepare_send_opts(:none), do: []
  defp prepare_send_opts(schedule_at), do: [schedule_at: schedule_at]

  # TODO: Move to sms adapter ?
  defp update_message(%{} = message) do
    changes = %{}
              |> Map.put(:client_id, message["clientId"])
              |> Map.put(:smsc_id, message["smscId"])
              |> Map.put(:status, message["status"])
              |> Map.put(:state, :sent)

    Ets.update_message(changes.client_id, changes, __MODULE__)
  end

  defp schedule_sending(%{poll_interval: poll_interval}) do
    Process.send_after(__MODULE__, :send, poll_interval)
  end

  defp sms() do
    Config.get(:sms_adapter)
  end
end