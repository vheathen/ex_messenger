defmodule ExMessenger.ConfigTest do
  use ExUnit.Case, async: false

  alias ExMessenger.Config

  test "application ENV must have OS populated env values" do
    unless is_nil(System.get_env("EX_SMSBLISS_LOGIN")) do
      assert System.get_env("EX_SMSBLISS_LOGIN") == Application.get_env(:ex_messenger, :auth) |> Keyword.get(:login)
      assert System.get_env("EX_SMSBLISS_PASSWORD") == Application.get_env(:ex_messenger, :auth) |> Keyword.get(:password)
    end
  end

  test "Config.get must return correct values" do
    assert Config.get(:auth) == Application.get_env(:ex_messenger, :auth)
  end

  test "general config must have correct defaults" do
    assert 2_000 == Config.get(:poll_interval)
    assert 2_000 == Config.get(:status_check_interval)
    assert 2_000 == Config.get(:cleanup_interval)

    assert 120_000 == Config.get(:send_timeout)
    assert 300_000 == Config.get(:max_age)

    assert true == Config.get(:push)

    assert ExMessenger.Json == Config.get(:sms_adapter)
  end

  test "sms adapter specific settings must have correct defaults" do
    opts = Config.get(ExMessenger.Json)

    assert Keyword.get(opts, :api_base) == "http://api.smsbliss.net/messages/v2/"
    assert Keyword.get(opts, :request_billing_on_send) == true
  end
  
end