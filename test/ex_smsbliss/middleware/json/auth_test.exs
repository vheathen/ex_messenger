defmodule ExSmsBliss.Middleware.Json.AuthTest do
  use ExUnit.Case

  defmodule JsonAuthClient do
    use Tesla

    plug ExSmsBliss.Middleware.Json.Auth
    plug Tesla.Middleware.JSON

    adapter fn env ->
      case env.url do
        "/json-auth" -> %Tesla.Env{body: ~s({"original_body":#{env.body}}), headers: env.headers}
        # "/json-reply" -> 
      end
    end


  end

  alias ExSmsBliss.Middleware.Json.Auth

  test "login\\pass must be set from config settings" do
    auth = Application.get_env(:ex_smsbliss, :auth)
    login = auth |> Keyword.get(:login)
    password = auth |> Keyword.get(:password)
    
    %{body: %{"original_body" => o_body}} = JsonAuthClient.post("/json-auth", %{some_key: "some_value"})
    assert Map.has_key?(o_body, "login")
    assert Map.has_key?(o_body, "password")
    assert login == Map.get(o_body, "login")
    assert password == Map.get(o_body, "password")
  end

  test "login\\pass must not be changed if they are already in the body" do
    login = "new_opted_login"
    password = "new_opted_password"
    
    %{body: %{"original_body" => o_body}} = JsonAuthClient.post("/json-auth", %{some_key: "some_value", login: login, password: password})
    assert Map.has_key?(o_body, "login")
    assert Map.has_key?(o_body, "password")
    assert login == Map.get(o_body, "login")
    assert password == Map.get(o_body, "password")
  end

  test "login\\pass must not exist in the answer" do    
    %{body: r_body} = JsonAuthClient.post("/json-auth", %{some_key: "some_value"})

    refute Map.has_key?(r_body, "login")
    refute Map.has_key?(r_body, "password")
  end

  test "add_auth/2: login\\pass must be set from opts if they are there" do
    login = "new_opted_login"
    password = "new_opted_password"
    
    %{} = body = Auth.add(%{some_key: "some_value"}, login: login, password: password)

    assert Map.has_key?(body, :login)
    assert Map.has_key?(body, :password)
    assert login == Map.get(body, :login)
    assert password == Map.get(body, :password)
  end
  
end