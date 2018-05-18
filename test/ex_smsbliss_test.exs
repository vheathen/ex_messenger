defmodule ExSmsBlissTest do
  use ExUnit.Case
  doctest ExSmsBliss

  describe "global application test" do
    test "make sure ExManager.Manager doesn't start on tests" do
      {:ok, _pid} = ExSmsBliss.Manager.start_link()
    end
  end

end
