defmodule ExSmsBliss.Config do
  @moduledoc false

  @defaults %{
        api_base: "http://api.smsbliss.net/messages/v2/",
        request_billing_on_send: true, # should it request billing details on each send message\messages?

        push: false,    # do not reply to the sender by default (wait for a result request)
        auth: []
    }

  @spec get(atom) :: term
  def get(key) when is_atom(key) do
    get(:ex_smsbliss, key)
  end

  @doc """
  Fetches a value from the config, or from the environment if {:system, "VAR"}
  is provided.
  An optional default value can be provided if desired.
  ## Example
      iex> {test_var, expected_value} = System.get_env |> Enum.take(1) |> List.first
      ...> Application.put_env(:myapp, :test_var, {:system, test_var})
      ...> ^expected_value = #{__MODULE__}.get(:myapp, :test_var)
      ...> :ok
      :ok
      iex> Application.put_env(:myapp, :test_var2, 1)
      ...> 1 = #{__MODULE__}.get(:myapp, :test_var2)
      1
      iex> :default = #{__MODULE__}.get(:myapp, :missing_var, :default)
      :default
  """
  @spec get(atom, atom, term | nil) :: term
  def get(app, key, default \\ nil) when is_atom(app) and is_atom(key),
    do: get_cases(Application.get_env(app, key), key, default)

  defp get_cases({:system, env_var}, _, default) do
    case System.get_env(env_var) do
      nil -> default
      val -> val
    end    
  end
  defp get_cases({:system, env_var, preconfigured_default}, _, _) do
    case System.get_env(env_var) do
      nil -> preconfigured_default
      val -> val
    end
  end
  defp get_cases(nil, key, default), do: if is_nil(default), do: Map.get(@defaults, key)
  defp get_cases(val, _key, _default), do: val

  @doc """
  Same as get/3, but returns the result as an integer.
  If the value cannot be converted to an integer, the
  default is returned instead.
  """
  @spec get_integer(atom(), atom(), integer()) :: integer
  def get_integer(app, key, default \\ nil) do
    case get(app, key, nil) do
      nil -> default
      n when is_integer(n) -> n
      n ->
        case Integer.parse(n) do
          {i, _} -> i
          :error -> default
        end
    end
  end

  def get_integer(key) do
    get_integer(:ex_smsbliss, key)
  end

  defp get_all_env do
    @defaults
    |> Enum.map(fn({k, _}) -> {k, get(k)} end)
  end

end
