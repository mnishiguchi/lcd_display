defmodule LcdDisplayTest do
  use ExUnit.Case
  doctest LcdDisplay

  test "greets the world" do
    assert LcdDisplay.hello() == :world
  end
end
