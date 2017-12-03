defmodule ExSmsBliss.ConfigTest do
  use ExUnit.Case, async: false

  alias ExSmsBliss.Config

  test "application ENV must have OS populated env values" do
    unless is_nil(System.get_env("EX_SMSBLISS_LOGIN")) do
      assert System.get_env("EX_SMSBLISS_LOGIN") == Application.get_env(:ex_smsbliss, :auth) |> Keyword.get(:login)
      assert System.get_env("EX_SMSBLISS_PASSWORD") == Application.get_env(:ex_smsbliss, :auth) |> Keyword.get(:password)
    end
  end

  test "Config.get must return correct values" do
    assert Config.get(:auth) == Application.get_env(:ex_smsbliss, :auth)
  end

  test ":request_billing_on_send should be true by default" do
    assert true == Config.get(:request_billing_on_send)
  end
  
end