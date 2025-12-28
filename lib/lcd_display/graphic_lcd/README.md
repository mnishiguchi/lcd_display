# Graphic LCD

Graphic LCD provides drivers for pixel-addressable LCD panels driven over SPI.

## Supported panels

- `LcdDisplay.ILI9486`
- `LcdDisplay.ST7796`

## Basic usage

### ILI9486

```elixir
{:ok, lcd} =
  LcdDisplay.ILI9486.start_link(
    spi_bus: "spidev0.0",
    spi_speed_hz: 16_000_000,
    data_command_pin: 25,
    reset_pin: 24,
    width: 480,
    height: 320,
    rotation: 90,
    data_bus: :parallel_8bit
  )

LcdDisplay.ILI9486.size(lcd)
LcdDisplay.ILI9486.pixel_format(lcd)
```

### ST7796

```elixir
{:ok, lcd} =
  LcdDisplay.ST7796.start_link(
    spi_bus: "spidev0.0",
    spi_speed_hz: 16_000_000,
    data_command_pin: 25,
    reset_pin: 24,
    width: 480,
    height: 320,
    rotation: 90,
    data_bus: :parallel_8bit
  )
```

## Writing frames

Set the pixel format, then write a full frame.

```elixir
LcdDisplay.ILI9486.set_pixel_format(lcd, :rgb565)

# Frame data already in RGB565
LcdDisplay.ILI9486.write_frame_565(lcd, rgb565_data)

# Convert from RGB888
LcdDisplay.ILI9486.write_frame(lcd, rgb888_frame, :rgb888)
```

Notes:

* Frame data should be a binary
* Full-frame updates are expected; partial updates are left to the application
