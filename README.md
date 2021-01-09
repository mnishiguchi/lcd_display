# LcdDisplay

[![Hex.pm](https://img.shields.io/hexpm/v/lcd_display.svg)](https://hex.pm/packages/lcd_display)
[![API docs](https://img.shields.io/hexpm/v/lcd_display.svg?label=docs)](https://hexdocs.pm/lcd_display/LcdDisplay.html)
![CI](https://github.com/mnishiguchi/lcd_display/workflows/CI/badge.svg)

`LcdDisplay` is a simple [Elixir](https://elixir-lang.org/) library that allows you to control a [Liquid-crystal display (LCD)](https://en.wikipedia.org/wiki/Liquid-crystal_display) like [Hitachi HD44780](https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller).

See [documentation](https://hexdocs.pm/lcd_display/LcdDisplay.html) and [example apps](https://github.com/mnishiguchi/lcd_display/tree/main/examples) for more information.

## Installation

You can install `LcdDisplay` by adding `lcd_display` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lcd_display, "0.0.13"}
  ]
end
```

## Examples

As an example, if you want to control a Hitachi HD44780 type display through
[I²C](https://en.wikipedia.org/wiki/I%C2%B2C), you can use `LcdDisplay.HD44780.I2C` module as a
display driver. See the `LcdDisplay.Driver` documentation for supported display commands.

```elixir
# Detect connected devices.
Circuits.I2C.detect_devices()

# Start the LCD driver and get a PID.
pid =
  LcdDisplay.start_display(
    LcdDisplay.HD44780.I2C,      # A display driver module
    %{
        display_name: "display 1", # the identifier
        i2c_bus: "i2c-1",          # I2C bus name
        i2c_address: 0x27,         # 7-bit address
        rows: 2,                   # the number of display rows
        cols: 16,                  # the number of display columns
        font_size: "5x8"           # "5x10" or "5x8"
    }
  )

# Run commands.
LcdDisplay.execute(pid, {:print, "Hello world"})
LcdDisplay.execute(pid, :clear)
```

## Thanks

- [`ExLCD`](https://github.com/cthree/ex_lcd) for inspiration

## Links

- [Hitachi HD44780 datasheet](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf)
