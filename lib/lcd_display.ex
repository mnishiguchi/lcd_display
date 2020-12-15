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

      alias LcdDisplay.HD44780

      # Start the LCD driver and get the initial display state.
      {:ok, display} = HD44780.I2C.start([])

      # Run a command and the display state will be updated.
      {:ok, display} = HD44780.I2C.execute(display, {:print, "Hello world"})
  """
end
