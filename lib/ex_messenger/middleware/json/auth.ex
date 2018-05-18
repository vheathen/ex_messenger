defmodule ExMessenger.Middleware.Json.Auth do
  @moduledoc false

  @behaviour Tesla.Middleware

  alias ExMessenger.Config
  
  def call(env, next, opts) do
    opts = opts || []

    env
    |> proceed(opts)
    |> Tesla.run(next)
  end

  def proceed(env, opts) do
    env
    |> Map.update!(:body, &add(&1, opts))
  end

  def add(body, opts \\ [])
  def add(%{} = body, opts) do
    body
    |> add_login(opts)
    |> add_password(opts)
  end
  def add(body, _opts), do: body

  defp add_login(%{login: _} = body, _opts), do: body
  defp add_login(%{} = body, opts) do
    add_field(body, :login, opts)
  end

  defp add_password(%{password: _} = body, _opts), do: body
  defp add_password(%{} = body, opts) do
    add_field(body, :password, opts)
  end

  defp add_field(%{} = map, key, opts) do
    value = Keyword.get(opts, 
                        key, 
                        :auth |> Config.get() |> Keyword.get(key)
                        )
    
    map
    |> Map.put(key, value)
  end

end