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

  def count_queue(state \\ :all) do
    Ets.count(state, __MODULE__)
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
  # def notify(_id, _subscriber, _state, _changes), do: :ok

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
    Process.flag(:trap_exit, true)

    state = %{poll_interval: 
                Keyword.get(opts, :poll_interval) || Config.get(:poll_interval),
              status_check_interval:
                Keyword.get(opts, :status_check_interval) || Config.get(:status_check_interval),
              # cleanup_interval:
              #   Keyword.get(opts, :cleanup_interval) || Config.get(:cleanup_interval),
              # max_age:
              #   Keyword.get(opts, :max_age) || Config.get(:max_age),
              send_timeout:
                Keyword.get(opts, :send_timeout) || Config.get(:send_timeout),
              }

    {:ok, _} = Ets.storage_init(__MODULE__)

    schedule_poll(state)
    schedule_status_check(state)
    # schedule_clean(state)
    
    {:ok, state}
  end

  def handle_info(:poll, state) do
    spawn_link fn ->
      send()
      expire(state)
      
      schedule_poll(state)
    end

    {:noreply, state}
  end

  def handle_info(:status_check, state) do
    spawn_link fn ->
      status_check()

      schedule_status_check(state)
    end

    {:noreply, state}
  end

  def handle_info({:EXIT, _from, _reason}, state) do
    {:noreply, state}
  end

  # def handle_info(:clean, state) do
  #   spawn_link fn ->
  #     clean_expired(state)
      
  #     schedule_clean(state)
  #   end

  #   {:noreply, state}
  # end

  ##
  # Private part
  ##

  defp expire(%{send_timeout: send_timeout}) do
    Ets.expire(send_timeout, __MODULE__)
  end

  # defp clean_expired(%{max_age: max_age}) do
  #   Ets.clean_finished(max_age, __MODULE__)
  # end

  defp status_check() do
    :sent
    |> Ets.get_by_state(__MODULE__)
    |> prepare_status_request()
    |> request_status()
  end

  # It returns a list with lists 200 messages each
  defp prepare_status_request(queue) when is_list(queue) do
    queue
    |>  Enum.map(fn msg -> 
          %{client_id: msg.client_id, smsc_id: msg.smsc_id}
        end)
    |>  Enum.chunk_every(200)
  end

  defp request_status(bundles) do
    bundles
    |>  Enum.each(fn bundle -> 
          spawn_link fn ->
      
            with \
              {:ok, response} <- sms().status(bundle)
            do
              parse_response(response)
            else
              error ->
                raise ArgumentError, error
            end
                  
          end
        end)
  end

  defp send() do
    __MODULE__
    |> Ets.prepare_send_queue()
    |> prepare_send_bundles()
    |> send_bundles()    
  end

  # TODO: Move to sms adapter ?
  defp prepare_send_bundles(queue) when is_list(queue) do
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
    spawn_link fn -> 

      with \
        {:ok, response} <- sms().send(bundle, prepare_send_opts(schedule_at))
      do
        parse_response(response)
      else
        {:error, description} ->
          react_on_error(bundle, description)
      end
      
    end
  end

  defp parse_response(%{"messages" => messages} = _response) do
    Enum.each(messages, &(update_message(&1)))
  end

  defp react_on_error(bundle, description) do
    bundle
    |>  Enum.each(fn msg -> 
          msg
          |> Map.put(:status, description)
          |> update_message(:error)
        end)
  end

  defp prepare_send_opts(:none), do: []
  defp prepare_send_opts(schedule_at), do: [schedule_at: schedule_at]

  # queued	                     Сообщение находится в очереди
  # delivered          fin          Сообщение доставлено
  # delivery error     fail          Ошибка доставки SMS (абонент в течение времени доставки находился вне зоны действия сети или номер абонента заблокирован)
  # smsc submit                  Сообщение доставлено в SMSC
  # smsc reject        fail          Сообщение отвергнуто SMSC (номер заблокирован или не существует)
  # incorrect id       fail          Неверный идентификатор сообщения


  # TODO: Move to sms adapter ?
  defp get_state(%{"smscId" => _, "status" => "delivered"})
  do
    :finished
  end
  defp get_state(%{"smscId" => _, "status" => status}) 
    when status in ["delivery error", "smsc reject", "incorrect id"]
  do
    :failed
  end
  defp get_state(%{"smscId" => _, "status" => status})
    when status in ["accepted", "smsc submit", "queued"]
  do
    :sent
  end
  defp get_state(_), do: :rejected

  # TODO: Move to sms adapter ?
  defp update_message(%{} = message, state \\ nil) do
    changes = %{}
              |> Map.put(:client_id, message["clientId"] || message[:client_id])
              |> Map.put(:status, message["status"] || message[:status])
              |> Map.put(:smsc_id, message["smscId"] || message[:smsc_id])
              |> Map.put(:state, state || get_state(message))

    Ets.update_message(changes.client_id, changes, __MODULE__)
  end

  defp schedule_poll(%{poll_interval: poll_interval}) do
    Process.send_after(__MODULE__, :poll, poll_interval)
  end

  defp schedule_status_check(%{status_check_interval: status_check_interval}) do
    Process.send_after(__MODULE__, :status_check, status_check_interval)
  end

  # defp schedule_clean(%{cleanup_interval: cleanup_interval}) do
  #   Process.send_after(__MODULE__, :clean, cleanup_interval)
  # end

  defp sms() do
    Config.get(:sms_adapter)
  end

end