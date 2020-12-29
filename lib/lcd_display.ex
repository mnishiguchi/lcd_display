defmodule LcdDisplay do
  @moduledoc """
  [LcdDisplay](https://github.com/mnishiguchi/lcd_display) is a simple
  [Elixir](https://elixir-lang.org/) library that allows you to control an
  [Liquid-crystal display (LCD)](https://en.wikipedia.org/wiki/Liquid-crystal_display) like
  [Hitachi HD44780](https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller).

  ## Examples

  As an example, if you want to control a Hitachi HD44780 type display through
  [I²C](https://en.wikipedia.org/wiki/I%C2%B2C), you can use `LcdDisplay.HD44780.I2C` module as a
  display driver.

      # Start the LCD driver and get the initial display state.
      pid = LcdDisplay.start_display(LcdDisplay.HD44780.I2C, %{display_name: "Display 1"})

      # Run a command.
      LcdDisplay.execute(pid, {:print, "Hello world"})
      LcdDisplay.execute(pid, :clear)
  """

  alias LcdDisplay.{DisplaySupervisor, DisplayController}

  @doc """
  Finds or starts a supervised display controller process.
  """
  def start_display(driver_module, config) when is_atom(driver_module) and is_map(config) do
    apply(DisplaySupervisor, :display_controller, [driver_module, config])
  end

  @doc """
  Executes a supported command that is specified.
  """
  def execute(pid, command) when is_pid(pid) do
    apply(DisplayController, :execute, [pid, command])
  end
end
