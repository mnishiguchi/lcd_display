# LcdDisplay

[![Hex.pm](https://img.shields.io/hexpm/v/lcd_display.svg)](https://hex.pm/packages/lcd_display)
[![API docs](https://img.shields.io/hexpm/v/lcd_display.svg?label=docs)](https://hexdocs.pm/lcd_display/LcdDisplay.html)
![CI](https://github.com/mnishiguchi/lcd_display/workflows/CI/badge.svg)

`LcdDisplay` allows you to control a [Liquid-crystal display (LCD)](https://en.wikipedia.org/wiki/Liquid-crystal_display) like [Hitachi HD44780](https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller) from [Elixir](https://elixir-lang.org/).

Here is the [documentation](https://hexdocs.pm/lcd_display/LcdDisplay.html) and [example apps](https://github.com/mnishiguchi/lcd_display/tree/main/examples) for this library.

For more info on the display, please refer to [Hitachi HD44780 data sheet](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf).

## Installation

You can install `LcdDisplay` by adding `lcd_display` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lcd_display, "0.0.17"}
  ]
end
```

## Usage

As an example, if you want to control a [Hitachi HD44780](https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller) type display through
the 16-bit I/O expander [PCF8575](https://www.nxp.com/docs/en/data-sheet/PCF8575.pdf),
you can use `LcdDisplay.HD44780.PCF8575` module as a display driver.

### Start an LCD driver and get a PID

```elixir
driver_module = LcdDisplay.HD44780.PCF8575
driver_config = %{
  display_name: "display 1", # the identifier
  i2c_bus: "i2c-1",          # I2C bus name
  i2c_address: 0x27,         # 7-bit address
  rows: 2,                   # the number of display rows
  cols: 16,                  # the number of display columns
  font_size: "5x8"           # "5x10" or "5x8"
}
pid = LcdDisplay.start_display(driver_module, driver_config)
```

### Run commands

Please refer to the `LcdDisplay.Driver` documentation for supported display commands.

```elixir
LcdDisplay.execute(pid, {:print, "Hello world"})
LcdDisplay.execute(pid, :clear)
```

## Thanks

- [`ExLCD`](https://github.com/cthree/ex_lcd) for inspiration

## Links

- [HD44780 data sheet](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf)
- [PCF8575 data sheet](https://www.nxp.com/docs/en/data-sheet/PCF8575.pdf)
- [MCP23008 data sheet](https://ww1.microchip.com/downloads/en/DeviceDoc/MCP23008-MCP23S08-Data-Sheet-20001919F.pdf)
- [MCP23017 data sheet](https://ww1.microchip.com/downloads/en/devicedoc/20001952c.pdf)
