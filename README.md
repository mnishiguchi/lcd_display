# LcdDisplay

[![Hex.pm](https://img.shields.io/hexpm/v/lcd_display.svg)](https://hex.pm/packages/lcd_display)
[![API docs](https://img.shields.io/hexpm/v/lcd_display.svg?label=docs)](https://hexdocs.pm/lcd_display/LcdDisplay.html)
![CI](https://github.com/mnishiguchi/lcd_display/workflows/CI/badge.svg)

`LcdDisplay` allows you to control a [Hitachi HD44780](https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller)-compatible
[Liquid-crystal display (LCD)](https://en.wikipedia.org/wiki/Liquid-crystal_display) in [Elixir](https://elixir-lang.org/).

For the specification of the HD44780 LCD, please refer to the [HD44780 data sheet](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf).

![nerves_hello_lcd_20201219_152639](https://user-images.githubusercontent.com/7563926/102699565-b5646700-4213-11eb-9ca1-a11bd10c619d.gif)

## Installation

You can install `LcdDisplay` by adding `lcd_display` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lcd_display, "~> 0.1.0"}
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

Please refer to the `LcdDisplay.HD44780.Driver` documentation for supported display commands.

```elixir
LcdDisplay.execute(pid, {:print, "Hello world"})
LcdDisplay.execute(pid, :clear)
```

### Driver modules

#### Parallel I/O

When you connect an LCD standalone directly to the GPIO pins on your target device, the `LcdDisplay.HD44780.GPIO` driver module is useful.

Here are some relevant Adafruit products:

- [Standard LCD 16x2 - white on blue](https://www.adafruit.com/product/181)
- [Standard LCD 20x4 - white on blue](https://www.adafruit.com/product/198)
- [RGB backlight LCD 16x2 - black on RGB](https://www.adafruit.com/product/398)
- [RGB backlight LCD 16x2 - RGB on black](https://www.adafruit.com/product/399)

#### Serial I/O

When you connect an LCD through an I/O expander, one of the following driver modules can be used.

- `LcdDisplay.HD44780.PCF8575`
  - I2C
  - [PCF8575 data sheet](https://www.nxp.com/docs/en/data-sheet/PCF8575.pdf)
- `LcdDisplay.HD44780.MCP23008`
   - I2C
  - [MCP23008 data sheet](https://ww1.microchip.com/downloads/en/DeviceDoc/MCP23008-MCP23S08-Data-Sheet-20001919F.pdf)
- `LcdDisplay.HD44780.MCP23017`
   - I2C
  - [MCP23017 data sheet](https://ww1.microchip.com/downloads/en/devicedoc/20001952c.pdf)
- `LcdDisplay.HD44780.SN74HC595`
  - SPI
  - [SN74HC595 data sheet](https://www.ti.com/lit/ds/scls041i/scls041i.pdf)

Different products out there use different I/O expanders, so please be aware of which I/O expander you are using if you use something like an I2C backpack.
Also the pin assignment between the LCD and the I/O expander is important.

It is easy to make your own driver modules in case you want a custom pin assignment, a different I/O expander or some custom features.

Here are some relevant Adafruit products:

- [i2c / SPI character LCD backpack](https://www.adafruit.com/product/292)
- [LCD Shield Kit w/ 16x2 Character Display](https://www.adafruit.com/product/772)

## Thanks

- [`ExLCD`](https://github.com/cthree/ex_lcd) for inspiration
