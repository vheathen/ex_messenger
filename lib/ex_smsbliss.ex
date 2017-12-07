defmodule ExSmsBliss do
  @moduledoc """
  Documentation for ExSmsbliss.

  Write a message to the storage with status :queued
  Every N time units start process to push all :queued messages to the service
  Get :queued messages and change their status to :working (in the storage)
  Put similar messages to the batches up to 200 messages
  Send each batch to the server and after receive status change messages' status to the received ones
  and update their smscIds in storage
  Every N time units get :accepted messages and send a 'status' request
  After status changed put status to the storage
  """
end
