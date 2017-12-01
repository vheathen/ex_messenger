defmodule ExSmsBlissTest do
  use ExUnit.Case
  doctest ExSmsBliss

  test "greets the world" do
    assert ExSmsBliss.hello() == :world
  end
end
