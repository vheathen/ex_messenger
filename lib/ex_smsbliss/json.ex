defmodule ExSmsBliss.Json do
  @moduledoc """
  JSON Api for SmsBliss service
  """
  use Tesla, only: [:post]

  @phone_number_format ~r/\A\+?\d{11,15}\Z/

  plug Tesla.Middleware.BaseUrl, "https://api.smsbliss.net/messages/v2/" # will get from Config
  plug ExSmsBliss.Middleware.Json.Auth

  # this have to be last plug as we work with unencoded body (%{} = body)
  plug Tesla.Middleware.JSON

  @doc """
  Sends up to 200 messages per request

  """
  def send(messages, opts \\ []) when is_list(messages) do
    body = 
      %{messages: messages}
      
    %Tesla.Env{body: body} = post("/send.json", body)

    body
  end

  @doc """
  Checks status of up to 200 messages per request
  """
  def status #(messages, opts \\ [])

  @doc """
  Checks status queue of up to 1000 messages per request
  """
  def status_queue

  @doc """
  Requests account balance
  """
  def balance

  @doc """
  Requests available senders ('from' property)
  """
  def senders

  @doc """
  Request active API version
  """
  def version
  
end