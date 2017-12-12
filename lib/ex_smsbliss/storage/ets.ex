defmodule ExSmsBliss.Storage.Ets do
  @behaviour ExSmsBliss.Storage
  @moduledoc false

  alias ExSmsBliss.Manager

  # id, 
  # state - internal status: :queued, :working, :sent, :failured, :finished 
  # status - external status from the SMS service
  # phone, 
  # text, 
  # sender, 
  # schedule_at, smsc_id, created_at, updated_at, 
  # subscriber - creator process's pid
  # _id, _state, _status, _phone, _text, _sender, _schedule_at, _smsc_id, _created_at, _updated_at, _subscriber

  # import Ex2ms

  # Fields order is important as it is used to build a tuple to keep in ets table
  @fields  [:id,
            # :state, # moved to a dedicated tables
            :status,
            :phone,
            :text,
            :sender,
            :schedule_at,
            :smsc_id,
            :created_at,
            :updated_at,
            :subscriber]

    # :queued - After message is queued
    # :sending - When it is going to be sent
    # :rejected - If service rejected a message
    # :sent - when a message is sent to the service
    # :failured - when sending is failed (service is unreachable and so on)
    # :finished - after a message came to the last life period from the service point of view
    @states [:queued, :sending, :rejected, :sent, :failured, :finished]

  def storage_init(pref) do
    :ets.new(pref, [:named_table, :set, :public,
                    write_concurrency: true, read_concurrency: true])

    for state <- @states do
      :ets.new(tbl(pref, state), [:named_table, :set, :public,
                                  write_concurrency: true, read_concurrency: true])
    end

    {:ok, pref}
  end

  @doc """
  Returns a message list with a given status or all if :all used as a status
  """
  def get_by_state(:all, pref) do

    # {id, state, status, phone, text, 
    # sender, schedule_at, smsc_id, 
    # created_at, updated_at, subscriber}

    f = fn(rec, acc) -> 
          id = get_id(rec)
          state = get_state(id, pref)
          message = rec
                    |> inject_state(state)
                    |> build_message()
          acc ++ [message]
        end

    :ets.foldl(f, [], pref)
  end
  def get_by_state(state, pref) do
    unless state in @states, do: raise ArgumentError, "No #{state} state in states"

    f = fn({id}, acc) ->
          message = get_message(id, state, pref)
          acc ++ [message]
        end

    :ets.foldl(f, [], tbl(pref, state))
  end

  def add(message, pref) do
    rec = build_record(message, pref)
    id = get_id(rec)

    true = :ets.insert(pref, rec)

    # TODO: weird error with race conditions?
    if [] == :ets.lookup(pref, id) do
      add(message, pref)
    else
      true = :ets.insert(tbl(pref, :queued), {id})

      {:ok, id}
    end  
  end

  def prepare_send_queue(pref) do
    f = fn {id}, acc ->
          update_state(id, :sending, pref)
          message = get_message(id, :sending, pref)
          Manager.notify(id, message.subscriber, :sending, %{})

          acc ++ [message]
        end

    :ets.foldl(f, [], tbl(pref, :queued))
  end
  
  def update_message(id, changes, pref) do

    new_state = Map.get(changes, :state)

    [rec] = :ets.lookup(pref, id)

    new_rec = rec
              |> inject_state(get_state(id, pref))
              |> build_message()
              |> Map.merge(changes)
              |> Map.put(:updated_at, now() |> DateTime.from_unix!(:millisecond))
              |> build_record(pref)

    true = :ets.insert(pref, new_rec)

    update_state(id, new_state, pref)

    Manager.notify(id, get_subscriber(rec), new_state, Map.delete(changes, :state))
  end
  

  def cleanup(0, pref) do
    :ets.delete_all_objects(pref)
    for state <- @states do
      :ets.delete_all_objects(tbl(pref, state))
    end
  end

  defp get_message(id, state, pref) do

    with \
      [rec] <- :ets.lookup(pref, id),
      rec   <- inject_state(rec, state),
      msg   <- build_message(rec)
    do
      msg
    else
      err -> raise "Got error on lookup with id #{id}: #{err}"
    end

    # pref
    # |> :ets.lookup(id)
    # |> Enum.at(0)
    # |> inject_state(state)
    # |> build_message()
  end
  
  defp build_record(message, pref) do
    now = now()

    Enum.reduce(@fields, {}, 
      fn field, acc -> 

        value =
          # credo:disable-for-lines:13
          case field do
            :id -> Map.get(message, :client_id, gen_safe_uuid(pref))
            # :state -> :queued
            :status -> Map.get(message, :status)
            :phone -> Map.get(message, :phone)
            :text -> Map.get(message, :text)
            :sender -> Map.get(message, :sender)
            :schedule_at -> transform_timestamp(Map.get(message, :schedule_at))
            :smsc_id -> Map.get(message, :smsc_id)
            :created_at -> transform_timestamp(Map.get(message, :created_at)) || now
            :updated_at -> transform_timestamp(Map.get(message, :updated_at)) || now
            :subscriber -> Map.get(message, :subscriber)
          end
        
        Tuple.append(acc, value)
      end)
  end

  defp build_message(
    {id, state, status, phone, text, 
    sender, schedule_at, smsc_id, 
    created_at, updated_at, subscriber}
  ) do

    %{client_id: id, 
      state: state, 
      status: status, 
      phone: phone, 
      text: text, 
      sender: sender, 
      schedule_at: (unless is_nil(schedule_at), do: DateTime.from_unix!(schedule_at, :millisecond)),
      smsc_id: smsc_id, 
      created_at: DateTime.from_unix!(created_at, :millisecond),
      updated_at: DateTime.from_unix!(updated_at, :millisecond), 
      subscriber: subscriber}
  end

  defp inject_state(rec, state) 
    when is_tuple(rec) and is_atom(state), 
  do: rec |> Tuple.insert_at(1, state)

  defp get_state(id, pref) do
    Enum.find(@states, fn state -> 
      length(:ets.lookup(tbl(pref, state), id)) > 0
    end)
  end

  defp update_state(id, new_state, pref) do
    unless new_state in @states, do: raise ArgumentError, "No #{new_state} state in states"

    state = get_state(id, pref)
    unless state == new_state do
      :ets.delete(tbl(pref, state), id)
      true = :ets.insert(tbl(pref, new_state), {id})  
    end
  end
 
  defp transform_timestamp(nil), do: nil
  defp transform_timestamp(%DateTime{} = timestamp) do
    timestamp |> DateTime.to_unix(:millisecond)
  end
  defp transform_timestamp(timestamp), do: timestamp
    
  defp now(), do: System.system_time(:millisecond)

  defp get_id({id, _, _, _, _, _, _, _, _, _}), do: id
  defp get_id({id, _, _, _, _, _, _, _, _, _, _}), do: id

  defp get_subscriber({_, _, _, _, _, _, _, _, _, subscriber}), do: subscriber
  defp get_subscriber({_, _, _, _, _, _, _, _, _, _, subscriber}), do: subscriber

  defp gen_safe_uuid(pref) do
    uuid = UUID.uuid4()
    if uuid_exists?(uuid, pref), 
      do: gen_safe_uuid(pref),
      else: uuid
  end

  defp uuid_exists?(uuid, pref) do
    [] != :ets.lookup(pref, uuid)
  end

  # Create a table name from prefix and state
  defp tbl(pref, state) do
    Module.concat(pref, state)
  end
end