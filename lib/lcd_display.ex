defmodule LcdDisplay do
  @moduledoc """
  A collection of utility functions to use this library.
  """

  @deprecated "Use LcdDisplay.CharacterLcd.start_link/1 instead."
  def start_link(config) do
    LcdDisplay.CharacterLcd.start_link(config)
  end

  @deprecated "Use LcdDisplay.CharacterLcd.execute/2 instead."
  def execute(pid, command) do
    LcdDisplay.CharacterLcd.execute(pid, command)
  end
end
