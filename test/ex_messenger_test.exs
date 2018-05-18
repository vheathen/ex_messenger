defmodule ExMessengerTest do
  use ExUnit.Case
  doctest ExMessenger

  describe "global application test" do
    test "make sure ExManager.Manager doesn't start on tests" do
      {:ok, _pid} = ExMessenger.Manager.start_link()
    end
  end

end
