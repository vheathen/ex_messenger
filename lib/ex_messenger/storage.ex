defmodule ExMessenger.Storage do
  @moduledoc false

  @type opts :: term
  @type description :: term
  @type message :: map
  @typedoc """
  Generated message id to identificate a message. Same as client_id
  """
  @type message_id :: String.t

  # Init storage
  @callback storage_init(opts) :: {:ok, term} | {:error, description}
  
  # Put a message to queue with :queued status
  @callback add(message, opts) :: {:ok, message_id} | {:error, description}

  # Returns messages with :queued status and changes their status to :working
  @callback prepare_send_queue(opts) :: [message]

  # changes - either smsc_id and\or status. if smsc_id already set it will return error
  @callback update_message(message_id, changes :: map, opts) :: {:ok, message} | {:error, description}

  # request message queue with a given status, :all means all statuses
  @callback get_queue(status :: atom, opts) :: [message]

  # Purge from DB finished messages changed more than 'age' time ago in milliseconds, if 0 - than all objects
  @callback cleanup(age :: integer, opts) :: :ok

end