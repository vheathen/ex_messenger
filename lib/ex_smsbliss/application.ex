defmodule ExSmsBliss.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    with \
      login <- System.get_env("EX_SMSBLISS_LOGIN"),
      pass  <- System.get_env("EX_SMSBLISS_PASSWORD"),
      auth  <- Application.get_env(:ex_smsbliss, :auth) || [],
      auth  <- (if is_nil(login), do: auth, else: Keyword.put(auth, :login, login)),
      auth  <- (if is_nil(pass), do: auth, else: Keyword.put(auth, :password, pass)),
      false <- is_nil(Keyword.get(auth, :login)),
      false <- is_nil(Keyword.get(auth, :password)),
      _     <- Application.put_env(:ex_smsbliss, :auth, auth)
    do

      # List all child processes to be supervised
      children = 
          [
            supervisor(ExSmsBliss.Storage.Postgrsql.Repo, []),
            # Starts a worker by calling: ExSmsBliss.Worker.start_link(arg)
            # {ExSmsBliss.Worker, arg},
          ]

      # See https://hexdocs.pm/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: ExSmsBliss.Supervisor]
      Supervisor.start_link(children, opts)

    else
      _ ->

        raise ArgumentError, """
        Can't find :login and\\or :password parameters

        It is a MUST to have these variables set in the config files as:

            config :ex_smsbliss, :auth
                login:    "yourlogin",
                password: "yourpassword"

        or via environment variables `EX_SMSBLISS_LOGIN` and `EX_SMSBLISS_PASSWORD`. 
        The last option has preference over the configuration file settings.

        Please check documentation at https://hexdocs.pm/ex_smsbliss
        """      
    end

  end
end