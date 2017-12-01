defmodule ExSmsblissTest do
  use ExUnit.Case
  doctest ExSmsbliss

  test "greets the world" do
    assert ExSmsbliss.hello() == :world
  end
end
