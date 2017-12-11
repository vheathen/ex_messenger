defmodule ExSmsBliss.Json do
  @moduledoc """
  JSON Api for SmsBliss service
  """
  use Tesla, only: [:post]

  alias ExSmsBliss.Config

  @message_fields ~w(text phone sender client_id)a

  # @send_pre_checks ~w(message_count)a
  @send_fields ~w(messages schedule_at request_billing queue_name login password)a
  @send_post_checks ~w(client_id_uniq)a

  @message_status_fields ~w(client_id smsc_id)a
  @status_fields ~w(messages login password)a
  @status_post_checks ~w(client_id_uniq)a

  @phone_int_format ~r/\A\+?\d{11,15}\Z/m
  @phone_ru_match ~r/\A\+?7.*\Z/m
  @phone_ru_format ~r/\A\+?\d{11}\Z/m
  @client_id_format ~r/\A[\w\d\-]{1,72}\Z/m

  plug Tesla.Middleware.BaseUrl, "https://api.smsbliss.net/messages/v2/" # will get from Config
  plug ExSmsBliss.Middleware.Json.Auth

  # this have to be last plug as we work with unencoded body (%{} = body)
  plug Tesla.Middleware.JSON

  @doc """
  Sends up to 200 messages per request.
  Returns {:ok, respond} tuple of everything went fine or {:error, details} in the opposite case.

  `opts` can include:
    * `:request_billing` - override global `:request_billing_on_send` parameter
    * `:sender` - set sender for all messages in a package; this setting will NOT override 
        per-message sender if it is set
    * `:schedule_at` - a DateTime structure or a properly formatted ISO8601 string
    * `:queue_name` - status queue name

  """
  def send(messages, opts \\ []) do
    try do
      {:ok, send!(messages, opts)}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  A "danger" version of the `send/2`.
  """
  def send!(messages, opts \\ []) do

    with \
      opts <-     Keyword.put(opts, :messages, messages),
      request <-  %{},
      # request <-  Enum.reduce(@send_pre_checks, request, &(send_pre_check(&1, &2, opts))),
      request <-  Enum.reduce(@send_fields, request, &(prepare_send_field(&1, &2, opts))),
      request <-  Enum.reduce(@send_post_checks, request, &(send_post_check(&1, &2, opts))),

      %Tesla.Env{body: body} <- post("/send.json", request)
    do
      body
    else
      error -> error
    end

  end

#  send result
#   {:ok,
#  %{"balance" => [%{"balance" => 14839.09, "credit" => 0.0, "type" => "RUB"}],
#    "messages" => [%{"clientId" => "None", "msgCost" => 1.64, "smsCount" => 1,
#       "smscId" => 2593129081, "status" => "accepted"},
#     %{"clientId" => "None", "msgCost" => 1.64, "smsCount" => 1,
#       "smscId" => 2593129080, "status" => "accepted"}], "status" => "ok"}}

  @doc """
  Checks status of up to 200 messages per request
  """
  def status(messages, opts \\ []) do
    try do
      {:ok, status!(messages, opts)}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  A "danger" version of the `status/2`
  """
  def status!(messages, opts \\ []) do
    with \
      opts <-     Keyword.put(opts, :messages, messages),
      request <-  %{},
      request <-  Enum.reduce(@status_fields, request, &(prepare_status_field(&1, &2, opts))),
      request <-  Enum.reduce(@status_post_checks, request, &(status_post_check(&1, &2, opts))),

      %Tesla.Env{body: body} <- post("/status.json", request)
    do
      body
    else
      error -> error
    end
    
  end

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

  #########################################
  # common
  #########################################
  ##
  # :login
  ##
  defp prepare_send_field(:login, request, opts) do
    login = Keyword.get(opts, :login)

    if login && byte_size(login) > 0, 
      do: Map.put(request, :login, login), 
      else: request
  end

  ##
  # :password
  ##
  defp prepare_send_field(:password, request, opts) do
    password = Keyword.get(opts, :password)

    if password && byte_size(password) > 0, 
      do: Map.put(request, :password, password), 
      else: request
  end

  #########################################
  # send
  #########################################

  ###
  # prepare_send_field
  ##

  ##
  # :messages
  ##
  defp prepare_send_field(:messages, request, opts) do
    messages = opts
               |> Keyword.get(:messages)
               |> prepare_messages(opts)

    request
    |> Map.put(:messages, messages)
  end

  ##
  # :schedule_at
  ##
  defp prepare_send_field(:schedule_at, request, opts) do
    schedule_at =
      if Keyword.has_key?(opts, :schedule_at), 
        do: format_schedule(Keyword.get(opts, :schedule_at)),
        else: false

    if schedule_at, 
      do: Map.put(request, "scheduleTime", schedule_at), 
      else: request
  end

  ##
  # :request_billing
  ##
  defp prepare_send_field(:request_billing, request, opts) do
    request_billing =
      if Keyword.has_key?(opts, :request_billing), 
        do: Keyword.get(opts, :request_billing),
        else: request_billing?

    if request_billing, 
      do: Map.put(request, "showBillingDetails", true), 
      else: request
  end

  ##
  # :queue_name
  ##
  defp prepare_send_field(:queue_name, request, opts) do
    queue_name = Keyword.get(opts, :queue_name)

    if queue_name, 
      do: Map.put(request, "statusQueueName", queue_name), 
      else: request
  end

  ##
  # any other options not ready yet
  ##
  # defp prepare_send_field(_, request, _), do: request

  defp prepare_messages(messages, opts) 
    when is_list(messages) and length(messages) > 0 and length(messages) <= 200 
  do
    messages
    |> Enum.map(&prepare_message(&1, opts))
  end
  defp prepare_messages(message, opts) when is_map(message) do
    prepare_messages([message], opts)
  end
  defp prepare_messages(_, _opts) do
    raise ArgumentError, "It is possible to send from 1 up to 200 messages in a batch"
  end

  defp prepare_message(message, opts) when is_map(message) do
    @message_fields
    |> Enum.reduce(%{}, &(prepare_message_field(&1, &2, message, opts)))
  end
  defp prepare_message(_, _) do
    raise ArgumentError, "A message must be a map"
  end

  ###
  # prepare_message_field
  ##

  #
  # :text
  #
  defp prepare_message_field(:text, new, %{text: text}, _opts) 
    when is_binary(text) and byte_size(text) > 0 
  do
    new |> Map.put(:text, text)
  end
  defp prepare_message_field(:text, _new, _message, _opts) do
    raise ArgumentError, ~s(Each message must contain :text field with a non-empty string value)
  end

  #
  # :phone
  #
  defp prepare_message_field(:phone, new, %{phone: phone} = message, opts) 
    when is_integer(phone) 
  do
    prepare_message_field(:phone, new, %{message | phone: Integer.to_string(phone)}, opts)
  end
  defp prepare_message_field(:phone, new, %{phone: phone}, opts) 
    when is_binary(phone) 
  do

    phone_re = if Regex.match?(@phone_ru_match, phone), 
                do: @phone_ru_format, 
                else: @phone_int_format

    if Regex.match?(phone_re, phone), 
      do: new |> Map.put(:phone, phone),
      else: prepare_message_field(:phone, new, nil, opts)
  end
  defp prepare_message_field(:phone, _new, _, _opts) do
    raise ArgumentError, ~s{Each message must contain :phone field as an integer or as a string in a proper international format (E.164)}
  end

  #
  # :sender
  #
  defp prepare_message_field(:sender, new, %{sender: sender}, _opts)
    when is_binary(sender) and byte_size(sender) > 0 
  do
    new |> Map.put(:sender, sender)
  end
  defp prepare_message_field(:sender, _new, %{sender: sender}, _opts) 
    when is_binary(sender) and byte_size(sender) == 0 
  do
    raise ArgumentError, ~s(If a message or options list contains a :sender it must be a non-empty string)
  end
  defp prepare_message_field(:sender, new, message, opts) do
    if sender = Keyword.get(opts, :sender), 
      do: prepare_message_field(:sender, new, Map.put(message, :sender, sender), []),
      else: new
  end

  #
  # :client_id
  #
  defp prepare_message_field(:client_id, new, %{client_id: client_id}, _opts)
    when is_integer(client_id) 
  do
    new |> Map.put("clientId", client_id)
  end
  defp prepare_message_field(:client_id, new, %{client_id: client_id}, opts) 
    when is_binary(client_id) 
  do
    if Regex.match?(@client_id_format, client_id), 
      do: new |> Map.put("clientId", client_id),
      else: prepare_message_field(:client_id, new, nil, opts)
  end
  defp prepare_message_field(:client_id, _new, nil, _opts) do
    raise ArgumentError, ":client_id must be an integer or a non-empty string no longer than 72 characters containing symbols A-Z, '-' and 0-1"
  end
  defp prepare_message_field(:client_id, new, _message, _opts), do: new

  ###
  # send_post_check
  ###

  #
  # :client_id_uniq
  #
  defp send_post_check(:client_id_uniq, request, _opts) do
    client_id_uniq?(request.messages, [], request)
  end

  # check for client id repeats in a message list: all magic is here
  defp client_id_uniq?([%{"clientId" => client_id} | tail], acc, request) do
    if Enum.find_value(acc, &(&1 == client_id)), 
      do: raise(ArgumentError, ~s(Each message :client_id must be unique for the message list)),
      else: client_id_uniq?(tail, acc ++ [client_id], request)
  end
  defp client_id_uniq?([_ | tail], acc, request), do: client_id_uniq?(tail, acc, request)
  defp client_id_uniq?([], _, request), do: request


  defp format_schedule(str) when is_binary(str) do
    utc_dt =
      case DateTime.from_iso8601(str) do
        {:ok, utc_dt, _} -> utc_dt
        _ -> 0
      end

    format_schedule(utc_dt)
  end
  defp format_schedule(%DateTime{} = utc_dt) do
    utc_dt
    |> DateTime.to_iso8601()
    |> String.replace(~r/\.\d+Z/, "Z")
  end
  defp format_schedule(_) do
    raise ArgumentError, """
    :schedule_at parameter is in a wrong format. Please use either DateTime or a string properly formated according to ISO8601.
    """
  end

  ############################################
  # status
  ############################################
  defp prepare_status_field(:password, request, opts), do: prepare_send_field(:password, request, opts)
  defp prepare_status_field(:login, request, opts), do: prepare_send_field(:login, request, opts)

  defp prepare_status_field(:messages, request, opts) do
    messages = opts
               |> Keyword.get(:messages)
               |> prepare_status_requests(opts)

    request
    |> Map.put(:messages, messages)
  end

  defp prepare_status_requests(messages, opts) 
    when is_list(messages) and length(messages) > 0 and length(messages) <= 200 
  do
    messages
    |> Enum.map(&prepare_status_request(&1, opts))
  end
  defp prepare_status_requests(message, opts) when is_map(message) do
    prepare_status_requests([message], opts)
  end
  defp prepare_status_requests(_, _opts) do
    raise ArgumentError, "It is possible to request status of from 1 up to 200 messages in a batch"
  end

  defp prepare_status_request(message_status, opts) when is_map(message_status) do
    @message_status_fields
    |> Enum.reduce(%{}, &(prepare_status_field(&1, &2, message_status, opts)))
  end
  defp prepare_status_request(_, _) do
    raise ArgumentError, "A message opts to request status must be a map"
  end

  defp prepare_status_field(:smsc_id, new, %{smsc_id: smsc_id}, _opts) 
    when (is_binary(smsc_id) and byte_size(smsc_id) > 0) or is_integer(smsc_id) 
  do
    new |> Map.put(:smscId, smsc_id)
  end
  defp prepare_status_field(:smsc_id, _new, _, _opts) do
    raise ArgumentError, "A status request must have :smsc_id field as a non-empty string or integer"
  end

  defp prepare_status_field(:client_id, new, status_request, opts) do
    prepare_message_field(:client_id, new, status_request, opts)
  end

  defp status_post_check(:client_id_uniq, request, _opts) do
    client_id_uniq?(request.messages, [], request)
  end

  defp request_billing?() do
    Config.get(__MODULE__)
    |> Keyword.get(:request_billing_on_send)
  end
end