defmodule ExSmsBliss.Json do
  @moduledoc """
  JSON Api for SmsBliss service
  """
  use Tesla, only: [:post]

  alias ExSmsBliss.Config

  @phone_number_format ~r/\A\+?\d{11,15}\Z/

  plug Tesla.Middleware.BaseUrl, "https://api.smsbliss.net/messages/v2/" # will get from Config
  plug ExSmsBliss.Middleware.Json.Auth

  # this have to be last plug as we work with unencoded body (%{} = body)
  plug Tesla.Middleware.JSON

  @doc """
  Sends up to 200 messages per request

  `opts` can be:
  *  `:request_billing` - override global `:request_billing_on_send` parameter

  """
  def send(messages, opts \\ []) when is_list(messages) do
    req_bill? =
      if Keyword.has_key?(opts, :request_billing), do: Keyword.get(opts, :request_billing),
      else: Config.get(:request_billing_on_send)

    body = %{messages: messages}
    body = if req_bill?, do: Map.put(body, "showBillingDetails", true), else: body
      
    %Tesla.Env{body: body} = post("/send.json", body)

    {:ok, body}
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