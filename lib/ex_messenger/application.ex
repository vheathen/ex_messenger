defmodule ExMessenger.Application do
  @moduledoc false
  use Application

  require Logger

  def start(_type, _args) do

    with \
      login <- System.get_env("EX_SMSBLISS_LOGIN"),
      pass  <- System.get_env("EX_SMSBLISS_PASSWORD"),
      auth  <- Application.get_env(:ex_messenger, :auth) || [],
      auth  <- (if is_nil(login),
                  do: auth, else: Keyword.put(auth, :login, login)),
      auth  <- (if is_nil(pass),
                  do: auth, else: Keyword.put(auth, :password, pass)),
      false <- is_nil(Keyword.get(auth, :login)),
      false <- is_nil(Keyword.get(auth, :password)),
      _     <- Application.put_env(:ex_messenger, :auth, auth)
    do

      # List all child processes to be supervised
      children = 
        case Application.get_env(:ex_messenger, :children) do
          nil ->
            [
              # Starts a worker by calling: ExMessenger.Worker.start_link(arg)
              # {ExMessenger.Worker, arg},
              {ExMessenger.Manager, []}
            ]

          # Do not start children for the tests while developing the library
          children -> children
        end

      # See https://hexdocs.pm/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: ExMessenger.Supervisor]
      Supervisor.start_link(children, opts)

    else
      _ ->

        raise ArgumentError, """
        Can't find :login and\\or :password parameters

        It is a MUST to have these variables set in the config files as:

            config :ex_messenger, :auth
                login:    "yourlogin",
                password: "yourpassword"

        or via environment variables `EX_SMSBLISS_LOGIN` and `EX_SMSBLISS_PASSWORD`. 
        The last option has preference over the configuration file settings.

        Please check documentation at https://hexdocs.pm/ex_messenger
        """
    end

  end
end
